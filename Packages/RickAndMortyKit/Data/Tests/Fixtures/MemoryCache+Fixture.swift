@testable import Data
import Testing

extension MemoryCache {
    /// Prepare cached values through the same token lifecycle used by the repository.
    func seed(_ value: Value, for key: Key) throws {
        let token = try beginWrite(for: key)
        do {
            #expect(try commit(value, using: token))
        } catch {
            finishWrite(token)
            throw error
        }
    }
}
