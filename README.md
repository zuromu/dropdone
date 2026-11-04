# Dropdone

[![CI](https://github.com/zuromu/dropdone/actions/workflows/ci.yml/badge.svg)](https://github.com/zuromu/dropdone/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black)

A tiny checklist that lives in your Mac menu bar, right next to Wi-Fi and Control Center. Click the icon, check things off, done. It uses Apple's Liquid Glass look so it fits in with the rest of macOS.

## How to use it

| You do | What happens |
|---|---|
| Click the menu bar icon | The panel opens |
| Click the circle on the left | Check or uncheck an item. A checked item fades, then moves to History after 5 seconds. Click the circle again before that to undo |
| Double click an item | Edit its name, press Return to save |
| Click **Add** | A new item appears, ready to type in |
| Drag an item | Move it up or down |
| Right click an item | Delete it |
| Click **History** | See your finished items, newest first |
| Click the arrow next to a finished item | Put it back on the list |
| Click **Clear** in History | Delete all finished items for good |
| Click **Back** | Return to your list |

Saving an item with an empty name removes it. Your list is saved automatically in `~/Library/Application Support/Dropdone/items.json`.

## Install

1. Download the latest zip from the [Releases](https://github.com/zuromu/dropdone/releases) page.
2. Unzip it and drag `Dropdone.app` into your Applications folder.
3. The app is not signed with an Apple Developer certificate yet, so the first time you open it, right click the app and choose **Open**.

Requires macOS 26 (Tahoe) or newer.

## Build it yourself

You need Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/zuromu/dropdone.git
cd dropdone
xcodegen
open Dropdone.xcodeproj
```

Press Run in Xcode. To run the tests from the terminal:

```bash
xcodebuild test -scheme Dropdone -destination 'platform=macOS'
```

## How the code is organized

```
Sources/Dropdone/
  DropdoneApp.swift   the menu bar entry point
  ContentView.swift   the panel with the list
  HistoryView.swift   the list of finished items
  ItemRow.swift       one row: checkbox, title, editing
  Store.swift         the list itself, plus saving and loading
  Item.swift          a single checklist item
Tests/DropdoneTests/  unit tests for the store
project.yml           XcodeGen settings (the .xcodeproj is generated)
```

## Contributing

Bug reports and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## License

[MIT](LICENSE)
