# Built-in Card Library

This fork bundles an optional Card Library for Apple Wallet skins.

## How to use it

1. Connect and scan or manually add Wallet cards as usual.
2. Open the **Apple Wallet** tab.
3. Click **Card Library** in the toolbar.
4. Choose the target Wallet card from **Apply to**.
5. Filter by category or region, or search by name.
6. Click a skin to assign it to that card.
7. Back in the main window, flash the selected cards normally.

The library does not alter payment credentials. It only provides artwork that AirCard feeds into its existing Wallet skin pipeline.

## Bundled artwork

The initial collection contains 12 original 1536×969 PNG skins:

- Transit-inspired: Singapore, London, Hong Kong, Tokyo, Seoul, Paris, New York, Sydney.
- Payment-card-inspired: two Singapore concepts and two United Kingdom concepts.

`CardLibrary/manifest.json` is the source of truth for metadata and file locations.

## Design and trademark policy

The bundled skins are original artwork influenced by regional transit and payment-card visual languages. They are not one-to-one copies of issuer artwork and are not official products of the referenced transport operators, banks, or card networks.

See `CardLibrary/SOURCES.md` and `CardLibrary/ASSET-NOTICE.md` for research notes and asset policy.

## Adding another skin

Add a 1536×969 PNG below `CardLibrary/`, then add a matching item to `CardLibrary/manifest.json` containing:

- a unique `id`;
- display `name`;
- `category` and `region`;
- relative `file` path;
- `size` and `format`;
- a short `inspired_by` note;
- `original_artwork` flag;
- SHA-256 digest.

The `Card Library UI Check` GitHub Actions workflow verifies that every manifest image exists and that its SHA-256 matches before type-checking the Swift integration.

## Upstream compatibility

AirCard currently keeps the main macOS app in a large single `AirCardApp.swift` file. To avoid permanently forking that file, `scripts/integrate_card_library.py` creates `build/AirCardApp.generated.swift` during builds and injects four small integration hooks. If upstream changes any anchor, the build fails with an explicit message instead of silently generating a broken app.
