# Mac App Store screenshots

Screenshots for the Hush 1.3.0 Mac App Store listing, 2880x1800 each:

- `1-brown.png`: "Brown noise, one click away."
- `2-speech.png`: "Tune out the voices."
- `3-light.png`: "Offline. Private."

Each one is the Hush controls panel cut out of a full-screen capture and placed
on a brown gradient with a headline, built by `make_screenshots.py`.

## Regenerating

1. Open the Hush panel and take a full-screen capture (Shift-Cmd-3) for each shot.
2. In `make_screenshots.py`, set each capture's path and the panel's pixel box
   `(left, top, right, bottom)` in `SHOTS`. Capture paths are relative to the
   directory you run the script from.
3. `pip install pillow`
4. `python3 docs/app-store/make_screenshots.py` (macOS; it uses the SF system font).

The PNGs are written next to the script.

The raw full-screen captures are intentionally not committed: they show
whatever was behind the panel.
