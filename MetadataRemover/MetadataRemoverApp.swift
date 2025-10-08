import SwiftUI
import PhotosUI

@main
struct MetadataRemoverApp: App {
    @StateObject private var viewModel = MetadataRemoverViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
