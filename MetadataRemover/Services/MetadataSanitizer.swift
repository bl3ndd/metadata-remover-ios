import UIKit
import ImageIO
import UniformTypeIdentifiers

struct SanitizationResult {
    let image: UIImage
    let remainingMetadata: [MetadataEntry]
}

struct MetadataSanitizer {
    func sanitize(image: UIImage) async throws -> SanitizationResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try sanitize(image: image)
                    let sanitizedImage = UIImage(data: data) ?? image
                    let extractor = MetadataExtractor()
                    let remaining = extractor.extractMetadata(from: data)
                    continuation.resume(returning: SanitizationResult(image: sanitizedImage, remainingMetadata: remaining))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func exportToTemporaryURL(image: UIImage) async throws -> URL {
        let data = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try sanitize(image: image))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        let filename = UUID().uuidString + ".jpg"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }

    private func sanitize(image: UIImage) throws -> Data {
        guard let cgImage = image.cgImage else {
            throw SanitizerError.unableToCreateCGImage
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw SanitizerError.unableToCreateDestination
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw SanitizerError.unableToFinalize
        }
        return data as Data
    }
}

enum SanitizerError: Error {
    case unableToCreateCGImage
    case unableToCreateDestination
    case unableToFinalize
}
