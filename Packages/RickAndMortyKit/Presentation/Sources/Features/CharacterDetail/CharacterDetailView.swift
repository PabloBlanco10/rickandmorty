import Domain
import SwiftUI

struct CharacterDetailView: View {
    @State private var viewModel: CharacterDetailViewModel
    @State private var attempt = 0
    private let imageLoader: (any ImageLoader)?

    init(id: Int, useCase: GetCharacterDetailUseCase, imageLoader: (any ImageLoader)?) {
        _viewModel = State(initialValue: CharacterDetailViewModel(id: id, useCase: useCase))
        self.imageLoader = imageLoader
    }

    var body: some View {
        CharacterDetailContent(state: viewModel.state, imageLoader: imageLoader) {
            attempt += 1
        }
        .task(id: attempt) {
            await viewModel.load()
        }
    }
}

/// Stateless content lets previews show every state without starting requests.
private struct CharacterDetailContent: View {
    let state: ViewState<Character>
    let imageLoader: (any ImageLoader)?
    let retry: () -> Void

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Loading character details")
            case let .failed(error):
                ContentUnavailableView {
                    Label("Unable to load character", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(CharactersError(error) == .connection
                        ? CharactersError.connection.message
                        : "Please try loading this character again.")
                } actions: {
                    Button(action: retry) {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Retry loading character details")
                }
            case let .loaded(character):
                Form {
                    Section {
                        CachedImage(url: character.imageURL, loader: imageLoader)
                            .frame(width: 180, height: 180)
                            .background(.quaternary)
                            .clipShape(.rect(cornerRadius: 16))
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                        Text(character.name)
                            .font(.title.bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Section("Details") {
                        LabeledContent("Status") {
                            StatusBagde(status: character.status)
                        }
                        LabeledContent("Species", value: character.species)
                        LabeledContent("Gender", value: gender(character.gender))
                        LabeledContent("Origin", value: character.origin)
                        LabeledContent("Location", value: character.location)
                    }
                }
            }
        }
        .navigationTitle("Character")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func gender(_ gender: Character.Gender) -> String {
        switch gender {
        case .female: "Female"
        case .male: "Male"
        case .genderless: "Genderless"
        case .unknown: "Unknown"
        }
    }
}

#Preview("Detail — Loading") {
    NavigationStack {
        CharacterDetailContent(state: .loading, imageLoader: nil, retry: {})
    }
}

#Preview("Detail — Light") {
    NavigationStack {
        CharacterDetailContent(state: .loaded(CharactersPreviewFixtures.character), imageLoader: nil, retry: {})
    }
    .preferredColorScheme(.light)
}

#Preview("Detail — Dark, large text") {
    NavigationStack {
        CharacterDetailContent(state: .loaded(CharactersPreviewFixtures.character), imageLoader: nil, retry: {})
    }
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}

#Preview("Detail — Error") {
    NavigationStack {
        CharacterDetailContent(state: .failed(CharactersError.connection), imageLoader: nil, retry: {})
    }
}
