/// Full-screen content state. Refresh and pagination must retain loaded content
/// and track their progress and errors separately in the owning ViewModel.
enum ViewState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(any Error)
}
