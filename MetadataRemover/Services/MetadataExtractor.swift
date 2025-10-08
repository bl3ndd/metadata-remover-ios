import Foundation
import ImageIO

struct MetadataExtractor {
    func extractMetadata(from data: Data) -> [MetadataEntry] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return []
        }

        var entries: [MetadataEntry] = []

        if let gps = metadata[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            let latitude = gps[kCGImagePropertyGPSLatitude] as? Double
            let longitude = gps[kCGImagePropertyGPSLongitude] as? Double
            if let latitude, let longitude {
                entries.append(MetadataEntry(title: "GPS", value: "\(latitude), \(longitude)"))
            }
        }

        if let tiff = metadata[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            if let make = tiff[kCGImagePropertyTIFFMake] as? String,
               let model = tiff[kCGImagePropertyTIFFModel] as? String {
                entries.append(MetadataEntry(title: "Устройство", value: "\(make) \(model)"))
            }
        }

        if let exif = metadata[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let exposureTime = exif[kCGImagePropertyExifExposureTime] as? Double,
               exposureTime > 0,
               let iso = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int] {
                let isoString = iso.map(String.init).joined(separator: ", ")
                let denominator = max(1.0, round(1.0 / exposureTime))
                entries.append(
                    MetadataEntry(
                        title: "Экспозиция",
                        value: String(format: "1/%.0f, ISO %@", denominator, isoString)
                    )
                )
            }
            if let date = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                entries.append(MetadataEntry(title: "Дата", value: date))
            }
        }

        return entries
    }
}
