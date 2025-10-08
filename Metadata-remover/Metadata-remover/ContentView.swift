import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import ImageIO

// MARK: - ContentView (single-file, compiles)

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var cleanedImage: UIImage?
    @State private var cleanedURL: URL?
    @State private var statusMessage: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    @State private var showCompare = true
    @State private var comparePosition: CGFloat = 0.5 // 0...1

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Drop zone + Picker
                        DropZone(
                            isProcessing: isProcessing,
                            onPick: { },
                            onDropURL: { url in Task { await handleDroppedURL(url) } },
                            onDropImage: { image in Task { await handleDroppedUIImage(image) } }
                        )
                        .overlay(alignment: .topTrailing) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Label("Выбрать", systemImage: "photo.on.rectangle")
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            }
                            .padding(12)
                            .disabled(isProcessing)
                        }
                        .onChange(of: selectedItem) { newValue in
                            guard let newValue else { return }
                            Task { await processSelection(newValue) }
                        }

                        // Status / Error
                        if let errorMessage {
                            Banner(text: errorMessage, style: .error)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else if let statusMessage {
                            Banner(text: statusMessage, style: .info)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Previews
                        if let originalImage {
                            CardSection(title: "Исходное изображение", icon: "photo") {
                                Image(uiImage: originalImage)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                                    .shadow(radius: 4, y: 2)
                            }
                            .transition(.opacity.combined(with: .scale))
                        }

                        if let cleanedImage {
                            CardSection(title: "Изображение без метаданных", icon: "checkmark.shield") {
                                Image(uiImage: cleanedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                                    .shadow(radius: 4, y: 2)
                            }
                            .transition(.opacity.combined(with: .scale))
                        }

                        // Compare slider (if both exist)
                        if let originalImage, let cleanedImage {
                            CardSection(title: "Сравнить до/после", icon: "slider.horizontal.3") {
                                Toggle(isOn: $showCompare.animation()) {
                                    Text(showCompare ? "Слайдер активен" : "Скрыть слайдер")
                                }
                                .toggleStyle(.switch)

                                if showCompare {
                                    CompareSlider(
                                        before: originalImage,
                                        after: cleanedImage,
                                        position: $comparePosition
                                    )
                                    .frame(height: 280)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                                    .shadow(radius: 4, y: 2)
                                    .padding(.top, 8)
                                }
                            }
                            .transition(.opacity.combined(with: .scale))
                        }

                        // Actions
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                ActionButton(label: "Выбрать другое", systemImage: "photo.on.rectangle")
                            }
                            .disabled(isProcessing)

                            if let cleanedURL {
                                ShareLink(item: cleanedURL) {
                                    ActionButton(label: "Поделиться", systemImage: "square.and.arrow.up", style: .prominent)
                                }
                            }
                        }
                        .padding(.top, 4)

                        Spacer(minLength: 24)
                    }
                    .padding()
                }

                if isProcessing {
                    ProcessingOverlay()
                        .transition(.opacity)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("Очистка метаданных")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if (originalImage != nil || cleanedImage != nil), !isProcessing {
                        Button {
                            withAnimation(.spring()) {
                                selectedItem = nil
                                originalImage = nil
                                cleanedImage = nil
                                cleanedURL = nil
                                statusMessage = nil
                                errorMessage = nil
                                comparePosition = 0.5
                            }
                        } label: {
                            Label("Сбросить", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Processing

    @MainActor
    private func processSelection(_ item: PhotosPickerItem) async {
        startProcessing()
        defer { stopProcessing() }

        do {
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                throw MetadataCleaningError.failedToLoadData
            }
            try await processImageData(imageData)
        } catch {
            handle(error)
        }
    }

    @MainActor
    private func handleDroppedURL(_ url: URL) async {
        startProcessing()
        defer { stopProcessing() }
        do {
            let data = try Data(contentsOf: url)
            try await processImageData(data)
        } catch {
            handle(error)
        }
    }

    @MainActor
    private func handleDroppedUIImage(_ image: UIImage) async {
        startProcessing()
        defer { stopProcessing() }
        do {
            guard let data = image.pngData() ?? image.jpegData(compressionQuality: 1.0) else {
                throw MetadataCleaningError.failedToLoadData
            }
            try await processImageData(data)
        } catch {
            handle(error)
        }
    }

    @MainActor
    private func processImageData(_ imageData: Data) async throws {
        self.originalImage = UIImage(data: imageData)

        let result = try removeMetadata(from: imageData)
        self.cleanedImage = UIImage(data: result.cleanedData)

        let tmp = try writeTempFile(data: result.cleanedData, utType: result.utType)
        self.cleanedURL = tmp

        self.statusMessage = "Метаданные успешно удалены."
        Haptics.success()
    }

    @MainActor private func startProcessing() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isProcessing = true
            errorMessage = nil
            statusMessage = nil
            cleanedURL = nil
        }
    }

    @MainActor private func stopProcessing() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isProcessing = false
        }
    }

    @MainActor private func handle(_ error: Error) {
        self.errorMessage = error.localizedDescription
        Haptics.error()
    }

    // MARK: - Core cleaning

    private func removeMetadata(from imageData: Data) throws -> (cleanedData: Data, utType: UTType) {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            throw MetadataCleaningError.failedToCreateImageSource
        }
        guard let typeIdentifier = CGImageSourceGetType(source) else {
            throw MetadataCleaningError.unsupportedImageType
        }

        let srcUTType = UTType((typeIdentifier as String)) ?? .jpeg

        guard let uiImage = UIImage(data: imageData),
              let normalizedCGImage = uiImage.normalizedCGImage() else {
            throw MetadataCleaningError.failedToCreateImageSource
        }

        let outData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(outData, srcUTType.identifier as CFString, 1, nil) else {
            throw MetadataCleaningError.failedToCreateDestination
        }

        var props: [CFString: Any] = [
            kCGImageDestinationMetadata: CGImageMetadataCreateMutable(),
            kCGImageDestinationMergeMetadata: kCFBooleanFalse
        ]
        if srcUTType.conforms(to: .jpeg) || srcUTType.conforms(to: .heic) || srcUTType.conforms(to: .heif) {
            props[kCGImageDestinationLossyCompressionQuality] = 1.0 as NSNumber
        }

        CGImageDestinationAddImage(destination, normalizedCGImage, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw MetadataCleaningError.failedToFinalize
        }
        return (outData as Data, srcUTType)
    }

    private func writeTempFile(data: Data, utType: UTType) throws -> URL {
        let ext = utType.preferredFilenameExtension ?? "img"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cleaned-\(UUID().uuidString).\(ext)")
        try data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - UI Blocks

private struct DropZone: View {
    let isProcessing: Bool
    let onPick: () -> Void
    let onDropURL: (URL) -> Void
    let onDropImage: (UIImage) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36, weight: .semibold))
            Text("Перетащите изображение сюда\nили выберите из Фотопленки")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if isProcessing {
                ProgressView().padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius)
                .strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1.2, dash: [6, 6]))
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.radius))
        .dropDestination(for: URL.self) { items, _ in
            if let url = items.first { onDropURL(url) }
            return true
        }
        .dropDestination(for: UIImage.self) { items, _ in
            if let img = items.first { onDropImage(img) }
            return true
        }
        .animation(.easeInOut, value: isProcessing)
    }
}

private struct CardSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title).font(.headline)
                Spacer()
            }
            content
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}

private struct Banner: View {
    enum Style { case info, error }
    let text: String
    let style: Style

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: style == .error ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
            Text(text).font(.subheadline)
            Spacer()
        }
        .foregroundStyle(style == .error ? Color.red : Color.secondary)
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(style == .error ? Color.red.opacity(0.25) : Theme.stroke, lineWidth: 1)
        )
    }
}

private struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
            VStack(spacing: 10) {
                ProgressView()
                Text("Обработка изображения…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1)
            )
        }
    }
}

private struct ActionButton: View {
    enum Kind { case regular, prominent }
    let label: String
    let systemImage: String
    var style: Kind = .regular

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.headline)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .fill(Theme.accentGradient)
                    .opacity(style == .prominent ? 1 : 0)
            )
            .clipShape(Capsule())
            .foregroundStyle(style == .prominent ? .white : .primary)
            .shadow(radius: style == .prominent ? 4 : 0, y: style == .prominent ? 2 : 0)
    }
}

private struct CompareSlider: View {
    let before: UIImage
    let after: UIImage
    @Binding var position: CGFloat // 0...1

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let x = max(0, min(w, position * w))

            ZStack(alignment: .leading) {
                Image(uiImage: before)
                    .resizable().scaledToFill()
                    .frame(width: w, height: h).clipped()

                Image(uiImage: after)
                    .resizable().scaledToFill()
                    .frame(width: x, height: h, alignment: .leading)
                    .clipped()

                Rectangle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 2, height: h)
                    .position(x: x, y: h/2)

                Circle()
                    .fill(.white)
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
                    .position(x: x, y: h/2)
                    .shadow(radius: 2, y: 1)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        isDragging = true
                        position = max(0, min(1, g.location.x / w))
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isDragging = false
                        }
                    }
            )
            .animation(.easeInOut(duration: 0.15), value: position)
            .clipped()
            .background(.black.opacity(0.03))
        }
    }
}

// MARK: - Theme & Helpers

private enum Theme {
    static let radius: CGFloat = 16
    static let background = LinearGradient(
        colors: [
            Color(.systemBackground),
            Color(.secondarySystemBackground)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let accentGradient = LinearGradient(
        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let stroke = Color.primary.opacity(0.08)
}

private enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

private extension UIImage {
    /// Нормализуем ориентацию в .up, чтобы после удаления EXIF-ориентации картинка не переворачивалась.
    func normalizedCGImage() -> CGImage? {
        if imageOrientation == .up, let cg = self.cgImage { return cg }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }
}

// MARK: - Transferable for UIImage (for dropDestination)

extension UIImage: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let img = UIImage(data: data) else {
                struct BadImageData: Error {}
                throw BadImageData()
            }
            return img
        }
    }
}

// MARK: - Errors

private enum MetadataCleaningError: LocalizedError {
    case failedToLoadData
    case failedToCreateImageSource
    case unsupportedImageType
    case failedToCreateDestination
    case failedToFinalize

    var errorDescription: String? {
        switch self {
        case .failedToLoadData:
            return "Не удалось загрузить данные изображения."
        case .failedToCreateImageSource:
            return "Не удалось создать источник изображения."
        case .unsupportedImageType:
            return "Неподдерживаемый формат изображения."
        case .failedToCreateDestination:
            return "Не удалось создать контейнер для сохранения изображения."
        case .failedToFinalize:
            return "Не удалось завершить сохранение изображения без метаданных."
        }
    }
}
