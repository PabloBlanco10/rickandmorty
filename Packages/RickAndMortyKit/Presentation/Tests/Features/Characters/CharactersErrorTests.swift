@testable import Presentation
import Testing

struct CharactersErrorTests {
    @Test(arguments: [CharactersError.connection, .service])
    func preservesExistingCharactersError(error: CharactersError) {
        let underlying: any Error = error
        #expect(CharactersError(underlying) == error)
    }
}
