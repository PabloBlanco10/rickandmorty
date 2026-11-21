import Domain
import SwiftUI

struct CharacterRow: View {
    let character: Character
    var imageLoader: (any ImageLoader)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var imageSize = 64

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            CachedImage(url: character.imageURL, loader: imageLoader)
                .frame(width: min(imageSize, 160), height: min(imageSize, 160))
                .background(.quaternary)
                .clipShape(.rect(cornerRadius: 10))
                .accessibilityHidden(true)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(character.name)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(character.species)")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    StatusBadge(status: character.status)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Row — Light") {
    CharacterRow(character: CharactersPreviewFixtures.character)
        .padding()
}

#Preview("Row — Dark, large text") {
    CharacterRow(character: CharactersPreviewFixtures.character)
        .padding()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
