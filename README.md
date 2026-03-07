# Hush

A macOS menu bar app for ambient noise. White noise, brown noise, pink noise, and a speech blocker — one right-click away, no browser tab required.

![Hush App Icon](Hush%20App.png)

## Why I built this

I've used white noise for focus and concentration for over ten years. Over that time I've bounced between various apps and browser tabs — playing brown noise here, switching to a speech blocker there. It always meant interrupting whatever I was doing to find the right tab or open the right app.

Now that I can build my own tools, I made exactly what I wanted: a small menu bar app that's always there. Right-click the icon to toggle sound. Left-click to open controls. No switching contexts, no hunting for a browser tab.

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

## Installation

1. Clone or download this repo
2. Open `Hush/Hush.xcodeproj` in Xcode
3. Build and run (⌘R), or archive to export a standalone app

Requires macOS 13+.

## Usage

| Action | Result |
|---|---|
| Right-click menu bar icon | Toggle noise on/off |
| Left-click menu bar icon | Open controls popover |
| Space | Play/pause (when popover is open) |
| ⌘Q | Quit |

## Building a release

In Xcode: **Product → Archive**, then **Distribute App → Copy App** to get a standalone `.app` you can move to `/Applications`.
