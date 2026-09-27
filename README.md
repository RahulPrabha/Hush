![Hush Banner](docs/Hush%20Banner.jpg)

# Hush

A macOS menu bar app for ambient noise. Brown noise and a speech blocker — one right-click away, no browser tab required.

## Features

- **Menu bar native** — lives in your menu bar, out of the way until you need it
- **Right-click to toggle** — start/stop sound without opening anything
- **Left-click for controls** — noise type picker, volume slider, and more
- **Two noise types:**
  - **Brown** — deep, rumbling, low-frequency rumble
  - **Speech Blocker** — shaped specifically to mask human voices
- **Brown noise low-pass cutoff** — adjustable filter from 20–500 Hz
- **Smooth start and stop** — audio fades in and out instead of cutting abruptly
- **Light and dark mode** — toggle from the popover footer
- **Remembers your settings** — last used noise type, volume, and appearance persist across launches

## Why I built this

I've used white noise for focus and concentration for over ten years. Over that time I've bounced between various apps and browser tabs — playing brown noise here, switching to a speech blocker there. It always meant interrupting whatever I was doing to find the right tab or open the right app.

Now that I can build my own tools, I made exactly what I wanted: a small menu bar app that's always there. Right-click the icon to toggle sound. Left-click to open controls. No switching contexts, no hunting for a browser tab.

## Privacy

**Hush is fully offline.** It requires no network connection and makes none. There are no analytics, no telemetry, no servers, and no audio files — all sounds are generated algorithmically in real time using signal processing (brown noise via leaky integration and a low-pass filter, speech blocker via pink noise from Paul Kellet's method shaped by a 10-band EQ). Nothing leaves your Mac.

You can verify this yourself: the full source is in this repo, and you can build it directly from Xcode.

See the [Privacy Policy](https://rahulprabha.github.io/Hush/privacy.html). For help, see the [Support page](https://rahulprabha.github.io/Hush/support.html).

## Usage

| Action | Result |
|---|---|
| Right-click menu bar icon | Toggle noise on/off |
| Left-click menu bar icon | Open controls popover |
| Space | Play/pause (when popover is open) |
| ⌘Q | Quit |

## Installation

**[Download Hush](https://rahulp6.gumroad.com/l/hush)** — pay what you want, $0 is fine. Unzip and move `Hush.app` to your `/Applications` folder.

Prefer GitHub? The same build is on the [Releases](../../releases) page, or build it yourself (see below).

Requires macOS 13+. Apple notarized, so it just opens.

## Building from source

Open `Hush/Hush.xcodeproj` in Xcode and run the `Hush` scheme, or build a
universal release binary from the command line:

```sh
./build.sh
```

The result is written to `dist/Hush.app`.

### Mac App Store archive

The app is sandboxed (`Hush/Hush/Hush.entitlements`) and ships a privacy
manifest (`Hush/Hush/PrivacyInfo.xcprivacy`). To produce an App Store package
locally (this exports only; it does not upload), you need a Mac App Store
distribution certificate, a Mac Installer Distribution certificate, and an App
Store provisioning profile for `com.rahulprabhakar.hush`:

```sh
xcodebuild -project Hush/Hush.xcodeproj -scheme Hush -configuration Release \
  -destination 'generic/platform=macOS' -archivePath build/Hush.xcarchive archive
xcodebuild -exportArchive -archivePath build/Hush.xcarchive \
  -exportOptionsPlist Hush/ExportOptions-AppStore.plist -exportPath build/export
```

Bump `CURRENT_PROJECT_VERSION` for every upload and `MARKETING_VERSION` for
every release.

## Changelog

### v1.3.0 (unreleased)

- Enabled the App Sandbox and added a privacy manifest in preparation for the Mac App Store
- The app now reports its real version (1.3.0) instead of 1.0

### v1.2.0

- Removed White and Pink noise; Brown is now the default
- Fixed the spectrum bars continuing to animate after playback stops
- Bars no longer redraw while the popover is closed, saving CPU during long sessions
- Fixed popover resize glitches when switching noise types
- Fixed an audio-thread crash when changing noise type mid-playback

### v1.1.0

- Redesigned popover with light and dark mode, large parameter readouts, and a mini spectrum per noise type
- Popover height animates when switching noise types

### v1.0.1

- Fixed code signing and notarization in the release workflow

### v1.0.0

- Initial release

## License

[MIT](LICENSE)

