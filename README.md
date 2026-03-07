# Hush

A macOS menu bar app for ambient noise. White noise, brown noise, pink noise, and a speech blocker — one right-click away, no browser tab required.

![Hush App Icon](Hush%20App.png)

## Features

- **Menu bar native** — lives in your menu bar, out of the way until you need it
- **Right-click to toggle** — start/stop sound without opening anything
- **Left-click for controls** — noise type picker, volume slider, and more
- **Four noise types:**
  - **White** — flat, crisp, full spectrum
  - **Pink** — balanced, natural, 1/f spectrum
  - **Brown** — deep, rumbling, low-frequency rumble
  - **Speech Blocker** — shaped specifically to mask human voices
- **Brown noise low-pass cutoff** — adjustable filter from 20–500 Hz
- **Remembers your settings** — last used noise type and volume persist across launches

## Why I built this

I've used white noise for focus and concentration for over ten years. Over that time I've bounced between various apps and browser tabs — playing brown noise here, switching to a speech blocker there. It always meant interrupting whatever I was doing to find the right tab or open the right app.

Now that I can build my own tools, I made exactly what I wanted: a small menu bar app that's always there. Right-click the icon to toggle sound. Left-click to open controls. No switching contexts, no hunting for a browser tab.

## Privacy

**Hush is fully offline.** It requires no network connection and makes none. There are no analytics, no telemetry, no servers, and no audio files — all sounds are generated algorithmically in real time using signal processing (white noise, pink noise via Paul Kellet's method, brown noise via leaky integration, speech blocker via a 10-band EQ). Nothing leaves your Mac.

You can verify this yourself: the full source is in this repo, and you can build it directly from Xcode.

## Usage

| Action | Result |
|---|---|
| Right-click menu bar icon | Toggle noise on/off |
| Left-click menu bar icon | Open controls popover |
| Space | Play/pause (when popover is open) |
| ⌘Q | Quit |

## Installation

Download the latest `Hush.zip` from the [Releases](../../releases) page, unzip it, and move `Hush.app` to your `/Applications` folder.

Requires macOS 13+.

## Gatekeeper warning

Hush is not signed with an Apple Developer certificate, so macOS will block it on first launch with a "cannot be opened" warning.

To open it anyway:

1. Try to open the app (it will be blocked)
2. Go to **System Settings → Privacy & Security**
3. Scroll down to the **Security** section
4. You'll see a message saying "Hush was blocked" — click **Open Anyway**

![Open Anyway Instructions](Open%20Anyway%20Instructions.png)

You only need to do this once. After that it opens normally.
