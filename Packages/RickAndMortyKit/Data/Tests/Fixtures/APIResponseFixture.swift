import Foundation
import Testing

enum APIResponseFixture {
    static var noMatches: Foundation.Data {
        Foundation.Data(#"{"error":"There is nothing here"}"#.utf8)
    }

    static func url(_ string: String = "https://example.com/api/character") throws -> URL {
        try #require(URL(string: string))
    }

    static func response(status: Int = 200) throws -> HTTPURLResponse {
        try #require(HTTPURLResponse(url: url(), statusCode: status, httpVersion: nil, headerFields: nil))
    }

    static func pageData(
        next: String? = "https://example.com/api/character?page=2",
        image: String = "https://example.com/1.jpeg",
        status: String = "Alive",
        gender: String = "Male",
        id: Int = 1,
        empty: Bool = false
    ) throws -> Foundation.Data {
        let character: [String: Any] = [
            "id": id, "name": "Rick Sanchez", "image": image, "status": status,
            "species": "Human", "gender": gender,
            "origin": ["name": "Earth", "url": "https://example.com/location/1"],
            "location": ["name": "Citadel", "url": "https://example.com/location/2"],
            "episode": ["https://example.com/episode/1"]
        ]
        var info: [String: Any] = ["next": NSNull()]
        if let next {
            info["next"] = next
        }
        return try JSONSerialization.data(withJSONObject: [
            "info": info, "results": empty ? [] : [character]
        ])
    }
}
