# GridSnap

[![Build](https://github.com/Kurry/gridsnap/actions/workflows/build.yml/badge.svg)](https://github.com/Kurry/gridsnap/actions/workflows/build.yml)

GridSnap is a macOS window manager that lets you cascade and tile windows from the menu bar.

## Features

- **Cascade** — stack all windows of an app in an offset cascade
- **Tile** — arrange all windows of an app in a pixel-perfect grid
- Lives in the menu bar, no dock icon
- Targets the screen your cursor is on

## Requirements

macOS 10.15 Catalina or later

## Building from source

```bash
bash build-install.sh
```

Requires Xcode 15+. The script builds with ad-hoc signing and copies the app to `/Applications/GridSnap.app`.

## Usage

Click the menu bar icon and choose **Cascade** or **Tile**, then select the app whose windows you want to arrange.

## License

MIT
