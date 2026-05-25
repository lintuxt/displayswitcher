*Control external monitor brightness, contrast, and input over DDC/CI from the macOS terminal.*

[![release](https://img.shields.io/github/v/release/lintuxt/displayswitcher?label=release&color=blue)](https://github.com/lintuxt/displayswitcher/releases)
[![CI](https://github.com/lintuxt/displayswitcher/actions/workflows/ci.yml/badge.svg)](https://github.com/lintuxt/displayswitcher/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-blue)](https://github.com/lintuxt/displayswitcher/blob/trunk/LICENSE)

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/lintuxt/displayswitcher/trunk/install.sh | sh
```

Downloads the latest release for Apple Silicon, verifies its SHA-256 checksum, and installs to `~/.local/bin` (or `/usr/local/bin`).

## Quickstart

```sh
displayswitcher --list                                # show every display
displayswitcher --set-brightness 60 --on-display 2    # set a value
displayswitcher --set-input hdmi1 --on-display 3      # switch input
displayswitcher --help                                # full help
```

## Why it exists

DDC/CI is one of those protocols every modern external monitor ships with and almost no software actually exposes. Your monitor will happily accept brightness, contrast, and input-source commands over its data channel — the same channel that already carries EDID at boot. The catch is that every OS either hides this behind a vendor utility, a third-party app, or nothing at all.

This CLI is the foundation. A GUI **Pro** version is in development at [displayswitcher.com](https://displayswitcher.com) (coming soon) — same DDC/CI engine underneath, with a wider feature set focused on a polished day-to-day experience. The CLI stays open source and self-contained; Pro builds on top of it.

## Requirements

macOS 13 or later on Apple Silicon. No other dependencies.

## Build from source

Requires Xcode 16+ (Swift 6).

```sh
git clone https://github.com/lintuxt/displayswitcher.git
cd displayswitcher
swift build -c release
./.build/release/displayswitcher --help
```

## License

MIT — see [LICENSE](https://github.com/lintuxt/displayswitcher/blob/trunk/LICENSE).

## Sponsor

If displayswitcher saves you a trip to the on-screen menu, [consider supporting future work](https://github.com/sponsors/lintuxt).
