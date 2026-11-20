import Domain
import SwiftUI

struct StatusBagde: View {
    let status: Character.Status

    var body: some View {
        Text(statusText)
            .font(.caption.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var statusText: String {
        switch status {
        case .alive: "Alive"
        case .dead: "Dead"
        case .unknown: "Unknown status"
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .alive:
            .green
        case .dead:
            .red
        case .unknown:
            .gray
        }
    }
}

#Preview("Status badges — Light") {
    HStack {
        StatusBagde(status: .alive)
        StatusBagde(status: .dead)
        StatusBagde(status: .unknown)
    }
    .padding()
}

#Preview("Status badges — Dark") {
    HStack {
        StatusBagde(status: .alive)
        StatusBagde(status: .dead)
        StatusBagde(status: .unknown)
    }
    .padding()
    .preferredColorScheme(.dark)
}
