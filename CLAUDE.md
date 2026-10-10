# Zappie

macOS menu bar app (Swift 6, SwiftUI, XcodeGen) that shows live power flow:
charger / battery → system → each USB-C port (device name and its battery %).

**Source of truth: [docs/SPEC.md](docs/SPEC.md)** — verified IOKit/SMC keys, port mapping,
state rules, design tokens, screens, backlog (§8). Read it before re-deriving anything, and
update it with every newly verified finding.

## Commands

- `scripts/test.sh` — regenerate the project (`xcodegen`) and run all Swift Testing tests.
- `TEST_RUNNER_ZAPPIE_RENDER_DIR=<dir> scripts/test.sh` — also write dropdown / main-window
  PNG renders (`ZappieTests/RenderSnapshots.swift`) to `<dir>`.
- `scripts/install.sh` — Release build, sign with this Mac's Apple Development cert (ad-hoc
  fallback), replace `/Applications/Zappie.app`, relaunch. Use it for every update.
- `swift scripts/gen_icon.swift` — regenerates the `Zappie/Zappie.icon` layers.

Builds go to `build.noindex/` (never `build/`: a second app copy there hides Zappie from
Spotlight's Apps view). `Zappie.xcodeproj` is generated from `project.yml`; edit the YAML.

## Rules

- **Read-only direction:** monitoring only. No SMC writes, no charge control (limit,
  discharge, auto cut-off). Heat is a warning only; macOS throttles charging itself.
- Targets macOS 14+, Apple Silicon only (`PowerTelemetryData` does not exist on Intel).
  Only verified on Mac17,9 (M5 Pro MacBook Pro).
- Verify on the real Mac (ioreg / SMC sampling) before claiming behavior. Don't fake
  unverified events; say what is still unverified.
- TDD: failing test first, then code. Fixtures live in `ZappieTests/Fixtures.swift`.
- Commit after each change. Push only when the user asks; before pushing, `git grep` to make
  sure no real battery / adapter serial numbers are in the tree.
- After UI changes: install, render PNGs, and send them to the user.

## Design

Dark-only UI, Liquid Glass. Brand colors (`Zappie/UI/Theme.swift`):
adapter lavender `#967CEC`, battery emerald `#0FAA7B`, USB cobalt `#2563C9`.

## Layout

- `Zappie/Power/` — data: `PowerReader` (IOKit), `SMC` + `SMCValidator` (cross-check with the
  battery driver, auto-fallback), `PowerState`, `PortLayout`, `PowerHistory`, `ChargeReason`,
  `TemperatureWatch`, `PowerMonitor` (polling).
- `Zappie/UI/` — `MenuBarLabel`, `DropdownView`, `MainWindow` + `OverviewView` /
  `DetailTabs`, `*Presentation` (pure, tested view models), `Theme`.

## Communication

Reply to the user in Korean, always 존댓말, even when they write 반말.
