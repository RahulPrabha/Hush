# Mac App Store screenshots

Screenshots for the Hush 1.4.0 Mac App Store listing, 2880x1800 each:

- `1-brown.png`: "Brown noise, one click away."
- `2-speech.png`: "Tune out the voices."
- `3-light.png`: "Offline. Private." (light theme)
- `4-languages.png`: "Speaks your language." Lists the 9 languages the app is
  available in, with the panel shown in Japanese. The captions stay English.

Each one is the Hush controls panel on a brown gradient with a headline, built by
`make_screenshots.py`. Every panel includes the Launch at login row with its
themed switch.

## Regenerating

The panel images are drawn offscreen from the app's own SwiftUI view, so nothing
is ever captured from the screen and no raw captures need to be kept.

1. `docs/app-store/render_panels.sh <dir>` compiles `ContentView.swift` and its
   model files with `render_panel.swift`, then writes `brown.png`, `speech.png`,
   `light.png` and `ja.png` (the panel only) into `<dir>`. Use a directory
   outside the repo, or `captures/`, which is git-ignored. It needs Xcode's
   command line tools and takes the strings from `Localizable.xcstrings`, so
   the panel always matches the current app. The state to show (noise type,
   theme, login switch, language) is set at the bottom of the script.
2. `pip install pillow`
3. `python3 docs/app-store/make_screenshots.py <dir>` (macOS; it uses system
   fonts, including CJK ones for the language list).

The PNGs are written next to the script. Per-locale screenshot sets (each
listing language with its own captions) are not made yet.

## Listing text

`metadata/<locale>/` holds the App Store Connect listing text for each
localization, one file per field: `name`, `subtitle`, `promotional_text`,
`description`, `keywords`, and `release_notes` (What's New). The folder names
are App Store Connect locale codes (`en-US`, `de-DE`, `es-ES`, `fr-FR`, `it`,
`ja`, `ko`, `pt-BR`, `zh-Hans`) and follow fastlane's `deliver` layout. Paste
each file into the matching field, or upload the folder with `fastlane deliver`.
The non-English text is machine-translated.

`python3 scripts/check_localizations.py` checks that every locale has every
field within App Store Connect's length limits.

## App Review notes

`review_notes.md` has the text for App Store Connect's "Notes for review" field and a
guideline 2.4.5 / 5.1.1 check for the current release.
