import SwiftUI

@MainActor
public struct CharactersView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("Rick and Morty")
                .font(.largeTitle)
                .accessibilityAddTraits(.isHeader)
            Text("Character browsing is coming soon.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}

#Preview("Light") {
    CharactersView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    CharactersView()
        .preferredColorScheme(.dark)
}
