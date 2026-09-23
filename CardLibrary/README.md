# AirCard Card Library

A small, curated card-art library for the `Allwayz/AirCard` fork.

## What is included

- **8 transit-inspired skins** based on visual languages associated with classic city transit cards.
- **4 payment-card skins** for Singapore and the United Kingdom.
- Every image is **1536 × 969 PNG**, matching AirCard's Wallet-card working canvas.
- `manifest.json` contains the machine-readable index and SHA-256 for every asset.

## How to use

AirCard already lets you click a detected Wallet card and choose an image manually.

1. Open AirCard and scan your Wallet cards.
2. Click the card you want to reskin.
3. Browse to this `CardLibrary` folder.
4. Pick a PNG.
5. Flash the selected skin as usual.

### Transit

| Region | Skin | Inspiration |
|---|---|---|
| Singapore | Singapore Link Classic | Classic blue/green smart-card language |
| United Kingdom | London Blue Line | London blue/white/navy transit-card language |
| Hong Kong | Hong Kong Loop | Dark field with a multicolour looping ribbon |
| Japan | Tokyo Green Rail | Silver/green rail-card language |
| South Korea | Seoul Black Stripe | Matte black + restrained stripe treatment |
| France | Paris Navigation Blue | Light blue + black modern transit layout |
| United States | New York Swipe Yellow | Yellow/blue magnetic-fare-card era |
| Australia | Sydney Opal Night | Charcoal + spectrum-ring language |

### Payment

| Region | Skin | Direction |
|---|---|---|
| Singapore | Lion City Night | Night skyline, teal accent, Visa-style layout |
| Singapore | Marina Jade | Jade/teal architectural waves, Visa-style layout |
| United Kingdom | Britannia Navy | Navy/red/white geometric treatment, Visa-style layout |
| United Kingdom | London Fog | Steel-grey urban treatment, Visa-style layout |

## Important note

These are **original reinterpretations**, not official card artwork and not exact reproductions. The library does not include downloaded bank or transit-operator card images. Names such as Oyster, Octopus, Suica, EZ-Link, Navigo, T-money, Opal, MetroCard and Visa belong to their respective owners and are referenced only in research notes to describe visual inspiration.

For personal customization, you can also add your own PNGs under the same directory structure and append them to `manifest.json`.
