import Foundation

struct MetadataEntry: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: String

    static var previewData: [MetadataEntry] {
        [
            MetadataEntry(title: "GPS", value: "55.751244, 37.618423"),
            MetadataEntry(title: "Камера", value: "iPhone 15 Pro"),
            MetadataEntry(title: "Экспозиция", value: "1/120, ISO 160")
        ]
    }
}
