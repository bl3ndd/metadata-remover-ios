import SwiftUI
import PhotosUI
import UIKit

@MainActor
final class MetadataRemoverViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var sanitizedImage: UIImage?
    @Published var metadata: [MetadataEntry] = []
    @Published var activeAlert: MetadataAlert?

    @Published private(set) var sanitizedImageURL: URL?

    private let extractor: MetadataExtractor
    private let sanitizer: MetadataSanitizer
    private let photoLibrarySaver: PhotoLibrarySaver

    init(
        extractor: MetadataExtractor = MetadataExtractor(),
        sanitizer: MetadataSanitizer = MetadataSanitizer(),
        photoLibrarySaver: PhotoLibrarySaver = PhotoLibrarySaver(),
        preview: Bool = false
    ) {
        self.extractor = extractor
        self.sanitizer = sanitizer
        self.photoLibrarySaver = photoLibrarySaver

        if preview {
            selectedImage = UIImage(named: "PreviewImage") ?? UIImage(systemName: "photo")
            metadata = MetadataEntry.previewData
        }
    }

    var canSanitize: Bool {
        selectedImage != nil
    }

    var canSave: Bool {
        sanitizedImage != nil
    }

    var canShare: Bool {
        sanitizedImage != nil || sanitizedImageURL != nil
    }

    func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
                sanitizedImage = nil
                sanitizedImageURL = nil
                metadata = extractor.extractMetadata(from: data)
                if metadata.isEmpty {
                    activeAlert = MetadataAlert(
                        title: "Метаданные не найдены",
                        message: "В этой фотографии не обнаружено информации о местоположении или устройстве."
                    )
                }
            }
        } catch {
            activeAlert = MetadataAlert(
                title: "Не удалось загрузить",
                message: "Произошла ошибка при чтении выбранного файла. Попробуйте выбрать другую фотографию."
            )
        }
    }

    func removeMetadata() async {
        guard let image = selectedImage else { return }
        do {
            let result = try await sanitizer.sanitize(image: image)
            sanitizedImage = result.image
            sanitizedImageURL = nil
            metadata = result.remainingMetadata
            if metadata.isEmpty {
                activeAlert = MetadataAlert(
                    title: "Успех",
                    message: "Метаданные были очищены. Теперь вы можете сохранить или отправить фотографию."
                )
            }
        } catch {
            activeAlert = MetadataAlert(
                title: "Ошибка",
                message: "Не удалось удалить метаданные. Попробуйте ещё раз."
            )
        }
    }

    func saveSanitizedImage() async {
        guard let sanitizedImage else {
            activeAlert = MetadataAlert(
                title: "Нет очищенной версии",
                message: "Сначала удалите метаданные, затем повторите попытку."
            )
            return
        }

        do {
            try await photoLibrarySaver.save(image: sanitizedImage)
            activeAlert = MetadataAlert(
                title: "Сохранено",
                message: "Фотография без метаданных добавлена в вашу медиатеку."
            )
        } catch {
            activeAlert = MetadataAlert(
                title: "Не удалось сохранить",
                message: "Приложению не удалось сохранить файл. Проверьте доступ к Фото."
            )
        }
    }

    func prepareShareSheet() async -> Bool {
        if sanitizedImageURL == nil {
            await createTemporaryFile()
        }
        return sanitizedImageURL != nil
    }

    func clearTemporaryFile() {
        guard let url = sanitizedImageURL else { return }
        try? FileManager.default.removeItem(at: url)
        sanitizedImageURL = nil
    }

    private func createTemporaryFile() async {
        guard let sanitizedImage else {
            activeAlert = MetadataAlert(
                title: "Нет очищенной версии",
                message: "Чтобы поделиться, сначала удалите метаданные."
            )
            return
        }

        do {
            sanitizedImageURL = try await sanitizer.exportToTemporaryURL(image: sanitizedImage)
        } catch {
            activeAlert = MetadataAlert(
                title: "Ошибка экспорта",
                message: "Не удалось подготовить файл для отправки."
            )
        }
    }
}

struct MetadataAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
