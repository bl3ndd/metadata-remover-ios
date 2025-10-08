//
//  ContentView.swift
//  Metadata-remover
//
//  Created by Evgeny Varzin on 08.10.2025.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import ImageIO

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var cleanedImage: UIImage?
    @State private var cleanedData: Data?
    @State private var statusMessage: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Выбрать изображение", systemImage: "photo.on.rectangle")
                            .font(.headline)
                    }
                    .disabled(isProcessing)
                    .onChange(of: selectedItem) { newValue in
                        guard let newValue else { return }
                        Task { await processSelection(newValue) }
                    }

                    if isProcessing {
                        ProgressView("Обработка изображения…")
                    }

                    if let originalImage {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Исходное изображение")
                                .font(.headline)
                            Image(uiImage: originalImage)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .shadow(radius: 4)
                        }
                    }

                    if let cleanedImage {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Изображение без метаданных")
                                .font(.headline)
                            Image(uiImage: cleanedImage)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .shadow(radius: 4)
                        }
                    }

                    if let cleanedData {
                        ShareLink(item: SanitizedImageTransferable(data: cleanedData)) {
                            Label("Поделиться очищенным файлом", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Очистка метаданных")
        }
    }

    @MainActor
    private func processSelection(_ item: PhotosPickerItem) async {
        isProcessing = true
        defer { isProcessing = false }
        statusMessage = nil
        errorMessage = nil

        do {
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                throw MetadataCleaningError.failedToLoadData
            }

            originalImage = UIImage(data: imageData)

            let cleanedImageData = try removeMetadata(from: imageData)
            cleanedData = cleanedImageData
            cleanedImage = UIImage(data: cleanedImageData)

            statusMessage = "Метаданные успешно удалены."
        } catch {
            errorMessage = error.localizedDescription
            cleanedData = nil
            cleanedImage = nil
        }
    }

    private func removeMetadata(from imageData: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            throw MetadataCleaningError.failedToCreateImageSource
        }

        guard let typeIdentifier = CGImageSourceGetType(source) else {
            throw MetadataCleaningError.unsupportedImageType
        }

        let cleanedData = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(cleanedData, typeIdentifier, 1, nil) else {
            throw MetadataCleaningError.failedToCreateDestination
        }

        CGImageDestinationAddImageFromSource(destination, source, 0, [:] as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw MetadataCleaningError.failedToFinalize
        }

        return cleanedData as Data
    }
}

private struct SanitizedImageTransferable: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .image) { transferable in
            transferable.data
        }
    }
}

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
