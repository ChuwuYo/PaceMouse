<p align="center">
  <img src="docs/screenshots/icon.png" width="128" alt="PaceMouse">
</p>

# PaceMouse

<p align="center">
  <a href="README.md">English</a> · <a href="README.zh-Hans.md">中文</a>
</p>

A macOS menu bar app that throttles high-polling-rate mouse **move / drag** events to reduce stutter.

macOS does not support high mouse polling rates (>500 Hz) well. If you share one mouse across several machines (Windows / Linux / macOS), PaceMouse lowers the motion event rate before events reach system dispatch; clicks and scrolling pass through unchanged.

## Install

1. Download the DMG from [Releases](https://github.com/ChuwuYo/PaceMouse/releases)
2. Open it and drag PaceMouse into Applications
3. First launch: right-click → **Open** (dev-signed build; Gatekeeper warns once)
4. Grant **Accessibility** when asked

## Screenshots

<p align="center">
  <img src="docs/screenshots/menu-en.png" width="280" alt="Menu bar"><br>
  <img src="docs/screenshots/settings-en.png" width="420" alt="Settings">
</p>

## Usage

- Toggle throttling from the menu bar icon
- Target rate: **125 / 250 / 500 Hz** (250 is a solid default)
- Optional **Smart Mode**: only engage when the measured input rate crosses a threshold
- Live `In → Out` Hz in the menu while running

PaceMouse does **not** change USB polling rate, acceleration, buttons, or scroll. For those, use something like [LinearMouse](https://github.com/linearmouse/linearmouse) or [Mac Mouse Fix](https://github.com/noah-nuebling/mac-mouse-fix).

## How it works

macOS has no public API to lower a device’s negotiated USB report rate. PaceMouse installs a `CGEventTap` at `.cghidEventTap`, accumulates motion deltas, and releases them at your target rate (token bucket). Non-motion events never enter that path.

## References

- [Karabiner-Elements](https://github.com/pqrs-org/Karabiner-Elements) — event tap lifecycle / permissions
- [LinearMouse](https://github.com/linearmouse/linearmouse) — macOS mouse tool architecture
- [Mac Mouse Fix](https://github.com/noah-nuebling/mac-mouse-fix) — high-rate mouse event handling
- [EventTapper](https://github.com/usagimaru/EventTapper) — small CGEventTap Swift wrapper
- [pollingrate](https://github.com/84ix/pollingrate) — measuring mouse poll rate on macOS
- [razer-mouse-lite-macos](https://github.com/NZKea/razer-mouse-lite-macos) — menu bar app shape

## License

[GPL-3.0](LICENSE)
