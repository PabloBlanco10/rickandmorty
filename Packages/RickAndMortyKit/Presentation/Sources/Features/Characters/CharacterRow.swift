import Domain
import SwiftUI

struct CharacterRow: View {
    let character: Character
    var loadsImages = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: loadsImages ? character.imageURL : nil) { phase in
                switch phase {
                case let .success(image): image.resizable().scaledToFill()
                case .failure: Image(systemName: "person.crop.square").font(.title).foregroundStyle(.secondary)
                case .empty:
                    if loadsImages {
                        ProgressView()
                    } else {
                        Image(systemName: "person.crop.square")
                    }
                @unknown default: Image(systemName: "person.crop.square")
                }
            }
            .frame(width: 64, height: 64)
            .background(.quaternary)
            .clipShape(.rect(cornerRadius: 10))
            .id(character.imageURL)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(character.name).font(.headline)
                Text("\(status) · \(character.species)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var status: String {
        switch character.status {
        case .alive: "Alive"
        case .dead: "Dead"
        case .unknown: "Unknown status"
        }
    }
}

#Preview("Row — Light") {
    CharacterRow(character: CharactersPreviewFixtures.character, loadsImages: false).padding()
}

#Preview("Row — Dark, large text") {
    CharacterRow(character: CharactersPreviewFixtures.character, loadsImages: false)
        .padding().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
