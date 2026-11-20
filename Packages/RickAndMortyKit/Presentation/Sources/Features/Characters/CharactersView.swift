import Domain
import SwiftUI

public struct CharactersView: View {
    @State private var path: [Int] = []
    private let detailUseCase: GetCharacterDetailUseCase
    private let viewModel: CharactersViewModel
    private let imageLoader: (any ImageLoader)?

    public init(
        viewModel: CharactersViewModel, imageLoader: any ImageLoader, detailUseCase: GetCharacterDetailUseCase
    ) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        self.detailUseCase = detailUseCase
    }

    init(viewModel: CharactersViewModel, detailUseCase: GetCharacterDetailUseCase) {
        self.viewModel = viewModel
        imageLoader = nil
        self.detailUseCase = detailUseCase
    }

    public var body: some View {
        NavigationStack(path: $path) {
            searchContent
                .navigationDestination(for: Int.self) { id in
                    CharacterDetailView(id: id, useCase: detailUseCase, imageLoader: imageLoader)
                        .id(id)
                }
                .navigationTitle("Characters")
                .navigationBarTitleDisplayMode(.inline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .task {
                    await viewModel.loadInitial()
                }
                .onDisappear {
                    viewModel.cancel()
                }
        }
    }

    private var searchBinding: Binding<String> {
        Binding(get: { viewModel.searchText }, set: { viewModel.updateSearchText($0) })
    }

    private var searchContent: some View {
        resultList
            .searchable(
                text: searchBinding, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search characters"
            )
    }

    private var resultList: some View {
        List {
            content
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.isInitialLoading {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel("Loading characters")
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
                Button("Retry loading characters") {
                    Task {
                        await viewModel.retrySearch()
                    }
                }
            }
            .listRowSeparator(.hidden)
        case let .loaded(characters):
            if characters.isEmpty {
                ContentUnavailableView {
                    Label("No characters found", systemImage: "magnifyingglass")
                } description: {
                    Text("Try a different character name.")
                }
                .listRowSeparator(.hidden)
            } else {
                ForEach(characters) { character in
                    Button {
                        path.append(character.id)
                    } label: {
                        CharacterRow(character: character, imageLoader: imageLoader)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        Task {
                            await viewModel.loadNextPage(approaching: character.id)
                        }
                    }
                }
            }
            paginationFooter
        }
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if viewModel.paginationError != nil {
            PaginationErrorView {
                Task {
                    await viewModel.retryPagination()
                }
            }
            .listRowSeparator(.hidden)
        } else if viewModel.isLoadingNextPage {
            HStack {
                Spacer()
                ProgressView()
                    .accessibilityLabel("Loading more characters")
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
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}

#Preview("Empty") {
    CharactersPreviewFixtures.view(state: .loaded([]))
}

#Preview("Error") {
    CharactersPreviewFixtures.view(state: .failed(CharactersError.connection))
}
