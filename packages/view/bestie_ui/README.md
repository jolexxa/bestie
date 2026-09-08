# 🎨 Bestie UI

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

Generic [Nocterm] terminal UI kit shared across bestie's features: theme, layout primitives, controls, input/keybinding plumbing, the banner notification system, and ambient visual effects. Nothing in here knows about bestie's domain — anything that reads model, chat, or config state lives with its feature instead.

## Structure 📂

- `theme/` — `AppTheme`, syntax highlighting theme derivation, color helpers
- `layout/` — split panes, scrollable shells, gutters, cards, headers
- `controls/` — buttons, scrollbars, progress bars, spinners, block font
- `input/` — `KeyAction`/`InputActions`, hover affordances, selection hosts
- `banner/` — the banner notification engine (cubit, logic, overlay)
- `effects/` — matrix/snow/wind ambient overlays

## Installation 💻

**❗ In order to start using Bestie UI you must have the [Dart SDK][dart_install_link] installed on your machine.**

[dart_install_link]: https://dart.dev/get-dart
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[Nocterm]: https://pub.dev/packages/nocterm
