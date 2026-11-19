import SwiftUI

public struct CharactersView: View {
    private let viewModel: CharactersViewModel
    private let loadsImages: Bool

    public init(viewModel: CharactersViewModel) {
        self.init(viewModel: viewModel, loadsImages: true)
    }

    init(viewModel: CharactersViewModel, loadsImages: Bool) {
        self.viewModel = viewModel
        self.loadsImages = loadsImages
    }

    public var body: some View {
        NavigationStack {
            List {
                content
            }
            .listStyle(.plain)
            .navigationTitle("Characters")
            .searchable(text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.updateSearchText($0) }
            ), prompt: "Search characters")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.loadInitial() }
            .onDisappear { viewModel.cancel() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            HStack {
                Spacer()
                ProgressView("Loading characters…")
                Spacer()
            }
            .listRowSeparator(.hidden)
        case let .failed(error):
            ContentUnavailableView {
                Label("Unable to load characters", systemImage: "exclamationmark.triangle")
            } description: {
                Text(CharactersError(error).message)
            } actions: {
                Button("Retry") { Task { await viewModel.retrySearch() } }
            }
            .listRowSeparator(.hidden)
        case let .loaded(characters):
            if viewModel.isRefreshing {
                ProgressView("Refreshing…")
            }
            if let error = viewModel.refreshError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error.message)
                    Button("Retry refresh") { Task { await viewModel.refresh() } }
                }
            }
            if characters.isEmpty {
                ContentUnavailableView {
                    Label("No characters found", systemImage: "magnifyingglass")
                } description: {
                    Text("Try a different character name.")
                }
                .listRowSeparator(.hidden)
            } else {
                ForEach(characters) { character in
                    CharacterRow(character: character, loadsImages: loadsImages)
                }
            }
            paginationFooter
        }
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if let error = viewModel.paginationError {
            VStack(alignment: .leading, spacing: 8) {
                Text(error.message)
                Button("Retry loading more") { Task { await viewModel.retryPagination() } }
            }
        } else if viewModel.nextPage != nil, !viewModel.isRefreshing {
            HStack {
                Spacer()
                ProgressView("Loading more…")
                Spacer()
            }
            .task(id: viewModel.nextPage) { await viewModel.loadNextPage() }
        }
    }
}

#Preview("Loading") {
    CharactersPreviewFixtures.view(state: .loading)
}

#Preview("Populated — Light") {
    CharactersPreviewFixtures.view(state: .loaded([CharactersPreviewFixtures.character]))
        .preferredColorScheme(.light)
}

#Preview("Populated — Dark, large text") {
    CharactersPreviewFixtures.view(state: .loaded([CharactersPreviewFixtures.character]))
        .preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}

#Preview("Empty") {
    CharactersPreviewFixtures.view(state: .loaded([]))
}

#Preview("Error") {
    CharactersPreviewFixtures.view(state: .failed(CharactersError.connection))
}
