import Domain
import SwiftUI
import UIKit

struct CachedImage: View {
    let url: URL
    let loader: (any ImageLoader)?
    @State private var image: UIImage?
    @State private var loadedURL: URL?
    @State private var failed = false

    var body: some View {
        Group {
            if loadedURL == url, let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if failed || loader == nil {
                Image(systemName: "person.crop.square").font(.title).foregroundStyle(.secondary)
            } else {
                ProgressView().accessibilityLabel("Loading character image")
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let loader, loadedURL != url || image == nil else { return }
        failed = false
        do {
            let data = try await loader.loadImage(from: url)
            try Task.checkCancellation()
            guard let decoded = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
            image = decoded
            loadedURL = url
        } catch {
            // SwiftUI cancels the task on disappearance or URL replacement.
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            failed = true
        }
    }
}

#Preview("Image placeholder — Light") {
    CachedImage(url: CharactersPreviewFixtures.character.imageURL, loader: nil)
        .frame(width: 64, height: 64).padding()
}

#Preview("Image placeholder — Dark") {
    CachedImage(url: CharactersPreviewFixtures.character.imageURL, loader: nil)
        .frame(width: 64, height: 64).padding().preferredColorScheme(.dark)
}
