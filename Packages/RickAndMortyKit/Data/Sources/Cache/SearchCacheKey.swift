import Foundation

struct SearchCacheKey: Hashable, Sendable {
    let query: String
    let page: Int

    init(query: String, page: Int) {
        // Preserve case and internal whitespace, matching the existing request semantics.
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.page = page
    }
}
