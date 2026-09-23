import SwiftUI
import AppKit

struct CardLibraryManifest: Codable {
    let schemaVersion: Int
    let library: String
    let cards: [CardLibrarySkin]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case library
        case cards
    }
}

struct CardLibrarySkin: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let region: String
    let file: String
    let inspiredBy: String
    let originalArtwork: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, category, region, file
        case inspiredBy = "inspired_by"
        case originalArtwork = "original_artwork"
    }
}

@MainActor
final class CardLibraryStore: ObservableObject {
    static let shared = CardLibraryStore()

    @Published private(set) var skins: [CardLibrarySkin] = []
    @Published private(set) var loadError: String?

    private init() {
        reload()
    }

    func reload() {
        loadError = nil
        skins = []

        guard let resourceRoot = Bundle.main.resourceURL else {
            loadError = "AirCard bundle resources could not be located."
            return
        }

        let manifestURL = resourceRoot
            .appendingPathComponent("CardLibrary", isDirectory: true)
            .appendingPathComponent("manifest.json")

        do {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(CardLibraryManifest.self, from: data)
            skins = manifest.cards
        } catch {
            loadError = "Could not load CardLibrary/manifest.json: \(error.localizedDescription)"
        }
    }

    func imageURL(for skin: CardLibrarySkin) -> URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent("CardLibrary", isDirectory: true)
            .appendingPathComponent(skin.file)
    }

    func image(for skin: CardLibrarySkin) -> NSImage? {
        guard let url = imageURL(for: skin) else { return nil }
        return NSImage(contentsOf: url)
    }
}

struct CardLibrarySheet: View {
    let cards: [CardItem]
    @Binding var targetCardID: String
    let onApply: (CardLibrarySkin) -> Void

    @ObservedObject private var store = CardLibraryStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory = "all"
    @State private var selectedRegion = "all"

    private var categories: [String] {
        Array(Set(store.skins.map(\.category))).sorted()
    }

    private var regions: [String] {
        Array(Set(store.skins.map(\.region))).sorted()
    }

    private var filteredSkins: [CardLibrarySkin] {
        store.skins.filter { skin in
            let categoryMatches = selectedCategory == "all" || skin.category == selectedCategory
            let regionMatches = selectedRegion == "all" || skin.region == selectedRegion
            let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let searchMatches = needle.isEmpty ||
                skin.name.lowercased().contains(needle) ||
                skin.region.lowercased().contains(needle) ||
                skin.category.lowercased().contains(needle) ||
                skin.inspiredBy.lowercased().contains(needle)
            return categoryMatches && regionMatches && searchMatches
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            filters
            Divider()

            if let error = store.loadError {
                ContentUnavailableView(
                    "Card Library unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredSkins.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 250, maximum: 310), spacing: 18)],
                        spacing: 18
                    ) {
                        ForEach(filteredSkins) { skin in
                            skinCell(skin)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .onAppear {
            if targetCardID.isEmpty {
                targetCardID = cards.first?.id ?? ""
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Card Library")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Built-in original skins inspired by classic transit and regional payment-card design languages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var filters: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("Apply to:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Target card", selection: $targetCardID) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        Text("Card #\(index + 1) · \(shortHash(card.id))")
                            .tag(card.id)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
            }

            Picker("Category", selection: $selectedCategory) {
                Text("All categories").tag("all")
                ForEach(categories, id: \.self) { category in
                    Text(category.capitalized).tag(category)
                }
            }
            .frame(width: 160)

            Picker("Region", selection: $selectedRegion) {
                Text("All regions").tag("all")
                ForEach(regions, id: \.self) { region in
                    Text(region).tag(region)
                }
            }
            .frame(width: 190)

            Spacer()

            TextField("Search skins", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func skinCell(_ skin: CardLibrarySkin) -> some View {
        Button {
            onApply(skin)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))

                    if let image = store.image(for: skin) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(1536.0 / 969.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 28))
                            Text("Image missing")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .aspectRatio(1536.0 / 969.0, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(NSColor.separatorColor).opacity(0.45), lineWidth: 1)
                )

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(skin.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text("\(skin.region) · \(skin.category.capitalized)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.down.to.line.compact")
                        .foregroundColor(.accentColor)
                }

                Text(skin.inspiredBy)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.55))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Apply \(skin.name) to the selected Wallet card")
    }

    private func shortHash(_ value: String) -> String {
        guard value.count > 14 else { return value }
        return "\(value.prefix(7))…\(value.suffix(5))"
    }
}
