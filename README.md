# LeetCode Toggle

<p align="center">
  <img src="docs/app-icon.png" width="96" height="96" alt="LeetCode Toggle app icon">
</p>

A tiny native **macOS menu bar app** that tells you at a glance whether you've
completed today's LeetCode challenge.

<p align="center">
  <img src="docs/menubar.png" alt="Menu bar states: red (not solved), green + check (solved), gray + ! (refresh failed)">
</p>

## The status

| Icon | Meaning |
| --- | --- |
| 🔴 red LeetCode mark | today's challenge **not** solved yet |
| 🟢 green mark + ✓ badge | today's challenge **solved** |
| ⚪ gray mark + ! badge | the last refresh failed |

- **Left-click** → opens today's challenge in your browser
- **Right-click** → today's challenge + status, 🔥 streak, total solved,
  **when you coded** (last 7 days), plus:
  - *Activity Calendar…* — 26-week heatmap, recent solved problems
  - *Open My Profile*, *Refresh*, *Settings…*, *Quit*

## Install

**From a GitHub release** (recommended): download `LeetCodeToggle.dmg`
from the [Releases](../../releases) page, open it, and drag
**LeetCodeToggle** into **Applications** — the classic macOS install.
First launch: right-click the app in Finder → **Open** (the build is
ad-hoc signed, so Gatekeeper asks once; see [Distribution](#distribution)).

**From source** (macOS 14+, Xcode command line tools):

```bash
git clone https://github.com/JairajSustained/leetcode-toggle.git
cd leetcode-toggle
./build.sh launch     # builds, installs to /Applications, and starts it
```

Then set your LeetCode username — **left-click the menu bar icon → Settings**
and type your username (the part of your `leetcode.com/…` profile URL). Or:

```bash
defaults write com.leetcodetoggle.app username "yourname"
```

Settings also include a refresh interval (default 5 min) and **launch at login**.

## Privacy

LeetCode Toggle only reads **public** LeetCode data via the public GraphQL
endpoint (`leetcode.com/graphql`):

- today's daily challenge (public to everyone)
- your **public** profile: streak, solved count, submission calendar, recent
  accepted submissions

What it does **not** do:

- ❌ no password, no session token, no cookies
- ❌ no analytics, no telemetry, no third-party services
- ❌ no data leaves your machine except the queries to leetcode.com
  (your username is the only thing sent)

"Solved today" is computed locally by matching an accepted submission of
today's challenge against LeetCode's UTC day boundary.

## CLI tools

The binary doubles as a diagnostics CLI:

After a `./build.sh`, the universal binary lives at
`.build/universal/LeetCodeToggle` and doubles as a diagnostics CLI:

```bash
.build/universal/LeetCodeToggle --check [username]   # print today's snapshot
.build/universal/LeetCodeToggle --icon-preview <dir> # render menu-bar icon states
.build/universal/LeetCodeToggle --app-icon <dir>     # render the .iconset
```

## Build from source

```bash
./build.sh            # universal .app + .dmg in dist/
./build.sh install    # build + copy app to /Applications
./build.sh launch     # build + install + start
./build.sh uninstall  # stop + remove from /Applications
```

The binary is built for **arm64 and x86_64** and combined into a universal
binary, so the app runs natively on Apple Silicon and Intel Macs.

Tag a release (`git tag v1.0.2 && git push --tags`) and the GitHub Actions
workflow builds and attaches the `.dmg` to the release.

## Distribution

Releases ship as a `.dmg` (drag-to-Applications), like most Mac apps.

### How to install

1. Download `LeetCodeToggle.dmg` from the [Releases](../../releases) page.
2. Open the `.dmg` and drag **LeetCodeToggle** into **Applications**.
3. Launch it from Applications — it lives in the menu bar (top-right corner),
   then set your LeetCode username (left-click the icon → Settings).

### About the first-launch warning

This app is **not signed or notarized by Apple yet**. Apple only trusts
apps signed with a *Developer ID*, which requires a **paid Apple Developer
account ($99/year)** — a cost this small project hasn't taken on yet, so
the release is only ad-hoc signed.

Because of that, macOS Gatekeeper will warn you on the **first** launch:

> "LeetCodeToggle" cannot be opened because the developer cannot be verified.

The app is safe to open: it's open source, and the only thing it ever sends
is your LeetCode username to leetcode.com — no password, no analytics, no
third parties (see [Privacy](#privacy)). To open it, pick one:

- **Easiest:** right-click (or Control-click) LeetCodeToggle in Finder →
  **Open** → click **Open** again in the dialog. You only ever do this once.
- **Or from Terminal:**

  ```bash
  xattr -dr com.apple.quarantine /Applications/LeetCodeToggle.app
  ```

After that first open, the app launches normally and forever.

> **For contributors:** the CI workflow already knows how to sign with a
> Developer ID and notarize the moment credentials are added as repo
> secrets — the full list is commented in
> [`.github/workflows/build.yml`](.github/workflows/build.yml).
> Once done, the next tagged release will open on any Mac with zero
> warnings.

## Project layout

```
Package.swift                  SPM manifest (macOS 14+, Swift 5 mode)
build.sh                       assembles dist/LeetCodeToggle.app (icon, plist, signing)
.github/workflows/build.yml    CI: builds the .app and attaches it to tagged releases
Sources/leetcode-toggle/
  main.swift                   entry point + CLI modes
  AppDelegate.swift            NSStatusItem, left/right click handling, the menu
  AppModel.swift               observable state, refresh scheduling, deep links
  LeetCodeAPI.swift            public GraphQL client + snapshot assembly
  Models.swift                 DailyChallenge / Snapshot / RecentSubmission
  MenuIcon.swift               renders the status-colored icon + app icon
  SettingsStore.swift          UserDefaults + launch-at-login (SMAppService)
  SettingsView.swift           SwiftUI settings window
  ActivityView.swift           SwiftUI activity window (streak, heatmap, recents)
  WindowController.swift       on-demand utility windows
  Resources/leetcode.svg       LeetCode mark (Simple Icons, CC0)
```

## Notes

- Menu-bar only (`LSUIElement`) — no Dock icon, no window until you open one.
- Day boundaries follow LeetCode's **UTC midnight**, so "today" can differ
  from your local date around midnight.
- Downloads from other Macs: see [Distribution](#distribution) — one
  right-click → **Open** (or the `xattr` command) clears the Gatekeeper
  warning until the project is Developer-ID signed + notarized.

## License

[MIT](LICENSE). The LeetCode logo mark is from [Simple Icons](https://simpleicons.org)
(CC0 1.0). Not affiliated with or endorsed by LeetCode Inc.
