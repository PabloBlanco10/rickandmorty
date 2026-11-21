import Domain

struct SearchCacheKey: Hashable, Sendable {
    let query: String
    let page: Int

    init(query: String, page: Int) {
        self.query = SearchCharactersUseCase.normalizedQuery(query)
        self.page = page
    }
}
