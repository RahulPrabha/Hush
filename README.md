![Hush Banner](docs/Hush%20Banner.jpg)

# Hush

A macOS menu bar app for ambient noise, plus an iPhone app that shares the same sound engine. Brown noise and a speech blocker — on the Mac, one right-click away, no browser tab required.

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
- **Launch at login** — optional, off by default; switch it on in the popover
- **Command line** — control Hush from the terminal with `hush play`, `hush stop`, `hush volume 40`, and more (see [Command line](#command-line-mac))
- **Remembers your settings** — last used noise type, volume, and appearance persist across launches

## Why I built this

I've used white noise for focus and concentration for over ten years. Over that time I've bounced between various apps and browser tabs — playing brown noise here, switching to a speech blocker there. It always meant interrupting whatever I was doing to find the right tab or open the right app.

Now that I can build my own tools, I made exactly what I wanted: a small menu bar app that's always there. Right-click the icon to toggle sound. Left-click to open controls. No switching contexts, no hunting for a browser tab.

## Privacy

**Hush is fully offline.** It requires no network connection and makes none. There are no analytics, no telemetry, no servers, and no audio files — all sounds are generated algorithmically in real time using signal processing (brown noise via leaky integration and a low-pass filter, speech blocker via pink noise from Paul Kellet's method shaped by a 10-band EQ). Nothing leaves your device.

You can verify this yourself: the full source is in this repo, and you can build it directly from Xcode.

See the [Privacy Policy](https://rahulprabha.github.io/Hush/privacy.html). For help, see the [Support page](https://rahulprabha.github.io/Hush/support.html).

## Usage (Mac)

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

## Command line (Mac)

Hush ships a `hush` command that controls the running app, so the menu bar
icon and your saved settings stay in sync. It starts Hush if it isn't running.

```sh
hush play                  # start playing (the last sound, or pass one)
hush play speech-blocker   # switch sound and play
hush stop
hush toggle
hush volume 40             # 0-100; `hush volume` alone prints the current volume
hush status                # "Hush is playing Brown at 40% volume."
hush status --json         # {"playing":true,"sound":"brown","volume":40}
hush sounds                # list the available sounds
hush --help
```

Exit codes: `0` success, `1` Hush couldn't carry out the command (for example,
no audio output), `2` usage error, `3` Hush couldn't be launched or didn't
answer within 10 seconds.

### Putting `hush` on your PATH

The command is the app's own executable, so there is nothing extra to install:
link it from a folder on your `PATH`. The app has to stay where you link it
from (`/Applications` is the usual place).

```sh
# Intel Mac, or any Mac where /usr/local/bin is on your PATH
sudo mkdir -p /usr/local/bin
sudo ln -s /Applications/Hush.app/Contents/MacOS/Hush /usr/local/bin/hush

# Apple Silicon with Homebrew
ln -s /Applications/Hush.app/Contents/MacOS/Hush /opt/homebrew/bin/hush

# No admin rights: link into ~/.local/bin and add it to your PATH
mkdir -p ~/.local/bin
ln -s /Applications/Hush.app/Contents/MacOS/Hush ~/.local/bin/hush
```

Or skip the link and use an alias in your shell profile:

```sh
alias hush='/Applications/Hush.app/Contents/MacOS/Hush --cli'
```

The link must be named `hush` (lowercase); that name is how the executable
knows to behave as the command. Launching Hush from Finder or `open` is
unaffected.

### How it works

The command sends your request to the app as a `hush://` URL, which the app
handles, then prints the answer the app leaves for it. It never plays audio
itself. This needs no extra entitlement, so it works in the sandboxed Mac App
Store build. The same URLs work from anywhere that can open a URL (Shortcuts'
"Open URLs", Raycast, Alfred, `open`):

| URL | Action |
|---|---|
| `hush://play` · `hush://play?sound=speech-blocker` | Play, optionally switching sound |
| `hush://stop` · `hush://toggle` | Stop · toggle |
| `hush://volume?level=40` | Set the volume (0-100) |
| `hush://status` | Report state (only useful to the `hush` command) |

Any app or web page can open a `hush://` URL, so they can start, stop, or
change the volume of Hush. They can't read anything or do anything else.

## Building from source

Open `Hush/Hush.xcodeproj` in Xcode and run the `Hush` scheme (Mac) or the
`Hush iOS` scheme (iPhone simulator or device). Or build a universal Mac
release binary from the command line:

```sh
./build.sh
```

The result is written to `dist/Hush.app`.

Run the unit tests with:

```sh
xcodebuild test -project Hush/Hush.xcodeproj -scheme Hush
```

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

The App Store screenshots, the script that builds them, and the localized
listing text live in [`docs/app-store/`](docs/app-store/).

### Localization

Hush is localized into Spanish, French, German, Japanese, Simplified Chinese,
Portuguese (Brazil), Korean, and Italian (machine-translated). UI strings live
in the String Catalog `Hush/Hush/Localizable.xcstrings`. When you add a
user-facing string, add its translations too, then run:

```sh
python3 scripts/check_localizations.py
```

It fails if any catalog key or App Store listing field is missing a language.
CI runs the same check on every pull request.

## Changelog

### v1.4.1 (unreleased)

- Fixed the menu bar icon showing "playing" while no audio was playing after right-clicking it several times quickly

### v1.4.0

- Enabled the App Sandbox and added a privacy manifest in preparation for the Mac App Store
- The app now reports its real version (1.4.0) instead of 1.0
- Localized into Spanish, French, German, Japanese, Simplified Chinese, Portuguese (Brazil), Korean, and Italian
- Added a Launch at login setting to the popover

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

