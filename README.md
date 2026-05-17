# Clips

A lightweight macOS clipboard manager that lives in your menu bar.

## Features

- Clipboard history with rich content support
- Global hotkey (Cmd+Shift+V) to show history
- Number keys (1-9) for quick selection, with folder navigation

## Requirements

- macOS 15 (Sequoia) or later
- Accessibility permission (for paste simulation)

## Setup

Uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project:

```
brew install xcodegen
xcodegen generate
open Clips.xcodeproj
```

## Preferences

- **General** — launch at login, max history, sort order, paste shortcut
- **Appearance** — icon style, inline/folder item counts, character limits, inline images
- **History** — search, copy, and delete entries
- **Ignored Apps** — exclude apps from clipboard monitoring

# Acknowledgements

App inspired by [Clipy](https://github.com/Clipy/Clipy).
