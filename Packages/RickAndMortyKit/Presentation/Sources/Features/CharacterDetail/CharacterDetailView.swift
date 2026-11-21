import Domain
import SwiftUI

struct CharacterDetailView: View {
    let character: Character
    let imageLoader: (any ImageLoader)?
    @ScaledMetric(relativeTo: .title) private var imageSize = 180

    var body: some View {
        Form {
            Section {
                CachedImage(url: character.imageURL, loader: imageLoader)
                    .frame(width: min(imageSize, 240), height: min(imageSize, 240))
                    .background(.quaternary)
                    .clipShape(.rect(cornerRadius: 16))
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                Text(character.name)
                    .font(.title.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            Section("Details") {
                LabeledContent("Status") {
                    StatusBadge(status: character.status)
                }
                LabeledContent("Species", value: character.species)
                LabeledContent("Gender", value: gender(character.gender))
                LabeledContent("Origin", value: character.origin)
                LabeledContent("Location", value: character.location)
            }
        }
        .navigationTitle("Character")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func gender(_ gender: Character.Gender) -> String {
        switch gender {
        case .female: "Female"
        case .male: "Male"
        case .genderless: "Genderless"
        case .unknown: "Unknown"
        }
    }
}

#Preview("Detail — Light") {
    NavigationStack {
        CharacterDetailView(character: CharactersPreviewFixtures.character, imageLoader: nil)
    }
    .preferredColorScheme(.light)
}

#Preview("Detail — Dark, large text") {
    NavigationStack {
        CharacterDetailView(character: CharactersPreviewFixtures.character, imageLoader: nil)
    }
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}
