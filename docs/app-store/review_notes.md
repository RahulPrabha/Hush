# App Review notes

Paste the text under "Notes for review" into App Store Connect > App Review
Information > Notes. No sign-in is needed, so leave the sign-in fields empty.

## Notes for review

Hush is a menu bar app that plays generated brown noise or speech-masking noise. It has no Dock icon and no window, so after launch look for the waveform icon at the right of the menu bar.

- Left-click the icon: opens the controls (noise type, volume, low-pass cutoff, Launch at login, light/dark appearance, Quit).
- Right-click the icon: turns sound on or off.
- Press Play (or Space with the controls open) to hear it. Sound is generated in real time on the Mac; the app ships no audio files.

Launch at login: the toggle in the controls is off by default and is the only thing that starts Hush at login. It uses SMAppService.mainApp (no helper app, LaunchAgent, or daemon), and it can also be changed in System Settings > General > Login Items. If macOS asks for approval, the row shows a link to Login Items settings.

Privacy and permissions: the app collects no data and makes no network connections. It has only the App Sandbox entitlement: no network, microphone, camera, file access, or other entitlements, and it asks for no permissions. The only stored data is three local preferences (noise type, volume, appearance) in UserDefaults inside the sandbox container (PrivacyInfo.xcprivacy declares the UserDefaults reason CA92.1).

The app is not a trial, has no in-app purchases, accounts, ads, or subscriptions.

## Guideline check (Hush 1.4.0)

Rows are grouped by topic under 2.4.5 (Mac App Store apps) and 5.1.1 (data
collection and storage), not by sub-item number. Re-read Apple's current
wording when submitting.

| Guideline topic | Status | Evidence |
| --- | --- | --- |
| 2.4.5 App Sandbox, Mac App Store distribution | Pass | Archive exports as an App Store package signed with the team's Apple Distribution certificate; embedded entitlements are `app-sandbox` plus the application and team identifiers |
| 2.4.5 Self-contained bundle, no code or resources downloaded | Pass | Single app bundle, no helpers or extra frameworks, no network entitlement, no download code |
| 2.4.5 No auto-launch at login without consent, nothing left running after quit | Pass | Launch at login is off by default and registers only when the user switches it on; switching it off unregisters it. Quit (power button or Cmd-Q) ends the process |
| 2.4.5 No privilege escalation | Pass | No privileged helper, authorization request, or setuid |
| 2.4.5 No Dock icon or desktop shortcut added | Pass | Menu bar only (`LSUIElement`) |
| 2.4.5 Current technologies only | Pass | AppKit, SwiftUI, AVFoundation, ServiceManagement (`SMAppService`) |
| 5.1.1 Data collection, privacy policy | Pass | No collected data types, no tracking, no network, no accounts. Privacy Policy: https://rahulprabha.github.io/Hush/privacy.html (confirm this is the URL set in App Store Connect) |
| 5.1.1 Permissions limited to what the feature needs | Pass | The app requests no permissions |
| Privacy manifest | Pass | `PrivacyInfo.xcprivacy` is in the bundle: no tracking, no collected data, UserDefaults reason CA92.1. The code uses no other required-reason API |
