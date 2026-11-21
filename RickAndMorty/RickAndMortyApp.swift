import Data
import Domain
import Foundation
import Presentation
import SwiftUI

@main
@MainActor
struct RickAndMortyApp: App {
    private let imageLoader: any ImageLoader
    @State private var viewModel: CharactersViewModel

    var body: some Scene {
        WindowGroup {
            CharactersView(viewModel: viewModel, imageLoader: imageLoader)
        }
    }

    init() {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                let repository = UITestCharacterRepository(
                    failInitialRequest: ProcessInfo.processInfo.environment["UITEST_SCENARIO"] == "initial-error"
                )
                imageLoader = UITestImageLoader()
                _viewModel =
                    State(initialValue: CharactersViewModel(useCase: SearchCharactersUseCase(repository: repository)))
                return
            }
        #endif
        imageLoader = URLSessionImageLoader()
        guard let apiRoot = URL(string: "https://rickandmortyapi.com/api") else {
            preconditionFailure("The configured API root must be a valid URL")
        }
        let repository = RickAndMortyCharacterRepository(baseURL: apiRoot)
        _viewModel = State(initialValue: CharactersViewModel(useCase: SearchCharactersUseCase(repository: repository)))
    }
}
