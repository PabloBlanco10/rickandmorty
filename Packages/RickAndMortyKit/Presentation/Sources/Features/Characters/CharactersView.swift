import Domain
import SwiftUI

public struct CharactersView: View {
    private let viewModel: CharactersViewModel
    private let imageLoader: (any ImageLoader)?

    public init(viewModel: CharactersViewModel, imageLoader: any ImageLoader) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
    }

    init(viewModel: CharactersViewModel) {
        self.viewModel = viewModel
        imageLoader = nil
    }

    public var body: some View {
        NavigationStack {
            searchContent
                .navigationTitle("Characters")
                .navigationBarTitleDisplayMode(.inline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .refreshable { await viewModel.refresh() }
                .task { await viewModel.loadInitial() }
                .onDisappear { viewModel.cancel() }
        }
    }

    private var searchBinding: Binding<String> {
        Binding(get: { viewModel.searchText }, set: { viewModel.updateSearchText($0) })
    }

    @ViewBuilder
    private var searchContent: some View {
        if #available(iOS 17.1, *) {
            resultList
                .searchable(
                    text: searchBinding,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search characters"
                )
                .searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            // iOS 17.0 has no search toolbar-preservation API.
            resultList.safeAreaInset(edge: .top) {
                TextField("Search characters", text: searchBinding)
                    .textFieldStyle(.roundedBorder).padding().background(.bar)
            }
        }
    }

    private var resultList: some View {
        List { content }
            .listStyle(.plain)
            .overlay {
                if viewModel.isInitialLoading {
                    ProgressView().controlSize(.large).accessibilityLabel("Loading characters")
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            EmptyView()
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
                    CharacterRow(character: character, imageLoader: imageLoader)
                        .onAppear { Task { await viewModel.loadNextPage(approaching: character.id) } }
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
        } else if viewModel.isLoadingNextPage {
            HStack {
                Spacer()
                ProgressView().accessibilityLabel("Loading more characters")
                Spacer()
            }
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
