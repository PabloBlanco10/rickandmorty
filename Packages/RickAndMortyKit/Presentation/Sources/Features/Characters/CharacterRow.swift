import Domain
import SwiftUI

struct CharacterRow: View {
    let character: Character
    var imageLoader: (any ImageLoader)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedImage(url: character.imageURL, loader: imageLoader)
                .frame(width: 64, height: 64)
                .background(.quaternary)
                .clipShape(.rect(cornerRadius: 10))
                .id(character.imageURL)
                .accessibilityHidden(true)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(character.name).font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(character.species)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    StatusBagde(status: character.status)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Row — Light") {
    CharacterRow(character: CharactersPreviewFixtures.character).padding()
}

#Preview("Row — Dark, large text") {
    CharacterRow(character: CharactersPreviewFixtures.character)
        .padding().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
