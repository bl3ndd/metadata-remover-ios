import SwiftUI
import PhotosUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: MetadataRemoverViewModel
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isShowingShareSheet = false
    @State private var isShowingInfoSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PhotosPicker(selection: $photosPickerItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(height: 220)

                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 48))
                                .foregroundColor(.accentColor)

                            Text(viewModel.selectedImage == nil ? "Выберите фотографию" : "Заменить фотографию")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .onChange(of: photosPickerItem) { _, newItem in
                    Task { await viewModel.loadImage(from: newItem) }
                }

                if let uiImage = viewModel.selectedImage {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))

                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(12)
                    }
                    .frame(maxHeight: 280)
                    .padding(.horizontal)

                    metadataSummary
                } else {
                    placeholder
                }

                actionButtons
            }
            .padding()
            .navigationTitle("Metadata Remover")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingInfoSheet.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Подробнее о метаданных")
                }
            }
            .sheet(isPresented: $isShowingInfoSheet) {
                NavigationStack {
                    MetadataExplanationView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Готово") { isShowingInfoSheet = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $isShowingShareSheet, onDismiss: viewModel.clearTemporaryFile) {
                if let url = viewModel.sanitizedImageURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert(item: $viewModel.activeAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("Чтобы начать, выберите фотографию. Приложение удалит из неё данные о местоположении, дате и модели камеры.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    private var metadataSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Найденные метаданные")
                    .font(.headline)
                Spacer()
                if viewModel.metadata.isEmpty {
                    Label("Не найдено", systemImage: "checkmark.seal")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                }
            }

            if viewModel.metadata.isEmpty {
                Text("В выбранной фотографии не обнаружено чувствительных метаданных.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                MetadataListView(metadata: viewModel.metadata)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await viewModel.removeMetadata() }
            } label: {
                Label("Удалить метаданные", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSanitize)

            Button {
                Task { await viewModel.saveSanitizedImage() }
            } label: {
                Label("Сохранить в Фотоплёнку", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canSave)

            Button {
                Task {
                    guard await viewModel.prepareShareSheet() else { return }
                    isShowingShareSheet = true
                }
            } label: {
                Label("Поделиться", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canShare)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MetadataRemoverViewModel(preview: true))
}
