import Domain
import SwiftUI

struct StatusBadge: View {
    let status: Character.Status
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(statusText)
            .font(.caption.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colors.background)
            .foregroundStyle(colors.foreground)
            .clipShape(Capsule())
    }

    private var statusText: String {
        switch status {
        case .alive: "Alive"
        case .dead: "Dead"
        case .unknown: "Unknown status"
        }
    }

    /// Opaque, appearance-specific pairs maintain small-text contrast on any row background.
    private var colors: (foreground: Color, background: Color) {
        switch (status, colorScheme) {
        case (.alive, .dark):
            (Color(red: 0.73, green: 0.97, blue: 0.82), Color(red: 0.08, green: 0.33, blue: 0.18))
        case (.alive, _):
            (Color(red: 0.09, green: 0.40, blue: 0.20), Color(red: 0.86, green: 0.99, blue: 0.91))
        case (.dead, .dark):
            (Color(red: 1, green: 0.79, blue: 0.79), Color(red: 0.50, green: 0.11, blue: 0.11))
        case (.dead, _):
            (Color(red: 0.60, green: 0.11, blue: 0.11), Color(red: 1, green: 0.89, blue: 0.89))
        case (.unknown, .dark):
            (Color(red: 0.90, green: 0.91, blue: 0.92), Color(red: 0.22, green: 0.25, blue: 0.32))
        case (.unknown, _):
            (Color(red: 0.22, green: 0.25, blue: 0.32), Color(red: 0.95, green: 0.96, blue: 0.96))
        }
    }
}

#Preview("Status badges — Light") {
    VStack {
        StatusBadge(status: .alive)
        StatusBadge(status: .dead)
        StatusBadge(status: .unknown)
    }
    .padding()
}

#Preview("Status badges — Dark, large text") {
    VStack {
        StatusBadge(status: .alive)
        StatusBadge(status: .dead)
        StatusBadge(status: .unknown)
    }
    .padding()
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}
