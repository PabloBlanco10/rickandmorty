/// Full-screen state; pagination retains loaded content and tracks progress separately.
enum ViewState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(CharactersError)
}

extension ViewState: Equatable where Value: Equatable {}
