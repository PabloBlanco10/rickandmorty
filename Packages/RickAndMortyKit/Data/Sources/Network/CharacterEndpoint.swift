import Foundation

enum CharacterEndpoint {
    static func search(baseURL: URL, query: String, page: Int) throws -> URL {
        guard page > 0,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              ["http", "https"].contains(components.scheme),
              let host = components.host, !host.isEmpty,
              components.query == nil, components.fragment == nil,
              components.user == nil, components.password == nil
        else {
            throw HTTPClientError.invalidURL
        }
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + (components.path.isEmpty ? "" : components.path + "/") + "character"
        components.queryItems = [URLQueryItem(name: "page", value: String(page))]
        if !query.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "name", value: query))
        }
        // Query parsers commonly interpret a literal + as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else {
            throw HTTPClientError.invalidURL
        }
        return url
    }
}
