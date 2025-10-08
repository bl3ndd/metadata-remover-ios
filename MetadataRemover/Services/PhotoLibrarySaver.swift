import PhotosUI
import UIKit

actor PhotoLibrarySaver {
    func save(image: UIImage) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                request.creationDate = Date()
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: SaverError.unknown)
                }
            }
        }
    }
}

enum SaverError: Error {
    case unknown
}
