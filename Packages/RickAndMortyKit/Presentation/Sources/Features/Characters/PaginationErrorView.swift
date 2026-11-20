import SwiftUI

struct PaginationErrorView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Label("Couldn't load more characters", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: retry) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Retry loading more characters")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

#Preview("Pagination error — Light") {
    PaginationErrorView(retry: {})
        .padding()
        .preferredColorScheme(.light)
}

#Preview("Pagination error — Dark, large text") {
    PaginationErrorView(retry: {})
        .padding()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
