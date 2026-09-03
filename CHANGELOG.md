# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `carrySlot`, off by default. With it on, switching banks lands on the slot you
  were already using, so slot 2 of one bank goes to slot 2 of the next. Applies
  to Super+Ctrl+Left, Super+Ctrl+Right, and clicking a bank name on the bar.
  Turn it on when you keep the same kind of window in the same slot of every
  bank.

## [1.0.0] - 2026-09-02

First public release.

### Fixed

- On a gap workspace the bar and Super+1 through Super+9 stay on the last bank
  you used, not the first bank.
- Clicking a bank name on the bar restores that bank's last slot, matching
  Super+Ctrl+Left and Super+Ctrl+Right.
- Invalid `contexts.json` keeps the last good dump, written to
  `~/.local/state/omarchy/io.github.johanthoren.workspace-contexts/last-good.json`,
  and writes the reason to stderr instead of silently switching to the shipped
  banks.
- Bank colors reload when Omarchy applies a theme. The widget no longer watches
  a `colors.toml` path that `omarchy-theme-set` deletes.

### Added

- Bar widget showing bank-local slot numbers for the active bank, plus a button
  per bank, colored from the current Omarchy theme.
- Hyprland module binding Super+1 to Super+9 to slots in the current bank,
  Super+Shift+1 to Super+Shift+9 and Super+Shift+Alt+1 to Super+Shift+Alt+9 to
  move a window, and Super+Ctrl+Left and Super+Ctrl+Right to cycle banks.
- Per-bank slot memory, so returning to a bank returns to the last slot used.
- `contexts.json` configuration, seeded from `contexts.example.json` on first run
  and never overwritten afterwards.
- `parse_contexts.py --dump` as the single source of bank math for both the
  widget and the Hyprland module.

[1.0.0]: https://github.com/johanthoren/workspace-contexts/releases/tag/1.0.0
