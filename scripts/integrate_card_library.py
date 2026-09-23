#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "AirCardApp.swift"
OUTPUT = ROOT / "build" / "AirCardApp.generated.swift"

text = SOURCE.read_text(encoding="utf-8")

replacements = []

state_anchor = """    @State private var isTargetedPoster = false\n    @State private var isTargetedTheme = false\n    \n    private var readyToFlashCount: Int {\n"""
state_replacement = """    @State private var isTargetedPoster = false\n    @State private var isTargetedTheme = false\n    @State private var showCardLibrary = false\n    @State private var cardLibraryTargetID = \"\"\n    \n    private var readyToFlashCount: Int {\n"""
replacements.append(("ContentView state", state_anchor, state_replacement))

toolbar_anchor = """                .help(\"Assign one skin to all selected cards\")\n            }\n            \n            Spacer()\n"""
toolbar_replacement = """                .help(\"Assign one skin to all selected cards\")\n            }\n\n            if !vm.cards.isEmpty {\n                Button(action: {\n                    cardLibraryTargetID = vm.cards.first(where: { $0.isSelected })?.id ?? vm.cards[0].id\n                    showCardLibrary = true\n                }) {\n                    Label(\"Card Library\", systemImage: \"rectangle.stack.fill\")\n                }\n                .buttonStyle(.bordered)\n                .controlSize(.regular)\n                .help(\"Browse the built-in AirCard skin library\")\n            }\n            \n            Spacer()\n"""
replacements.append(("wallet toolbar", toolbar_anchor, toolbar_replacement))

sheet_anchor = """        .sheet(isPresented: $vm.showAddCardSheet) {\n            addCardSheet\n        }\n"""
sheet_replacement = """        .sheet(isPresented: $vm.showAddCardSheet) {\n            addCardSheet\n        }\n        .sheet(isPresented: $showCardLibrary) {\n            CardLibrarySheet(\n                cards: vm.cards,\n                targetCardID: $cardLibraryTargetID,\n                onApply: applyLibrarySkin\n            )\n        }\n"""
replacements.append(("card library sheet", sheet_anchor, sheet_replacement))

method_anchor = """    // MARK: - Subviews\n"""
method_replacement = """    private func applyLibrarySkin(_ skin: CardLibrarySkin) {\n        guard let index = vm.cards.firstIndex(where: { $0.id == cardLibraryTargetID }) else {\n            vm.statusText = \"Choose a Wallet card before applying a library skin.\"\n            return\n        }\n        guard let url = CardLibraryStore.shared.imageURL(for: skin),\n              let image = NSImage(contentsOf: url) else {\n            vm.statusText = \"Could not load skin '\\(skin.name)' from the app bundle.\"\n            return\n        }\n\n        vm.cards[index].customImageURL = url\n        vm.cards[index].customImage = image\n        vm.cards[index].isSelected = true\n        vm.statusText = \"Applied library skin '\\(skin.name)' to Card #\\(index + 1).\"\n        showCardLibrary = false\n    }\n\n    // MARK: - Subviews\n"""
replacements.append(("apply helper", method_anchor, method_replacement))

for label, old, new in replacements:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one {label} anchor, found {count}. Upstream AirCardApp.swift changed; update scripts/integrate_card_library.py before building.")
    text = text.replace(old, new, 1)

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(text, encoding="utf-8")
print(f"Generated {OUTPUT.relative_to(ROOT)} with Card Library integration")
