# i18n Localization Guide

## Goal

Keep all user-facing text in one bilingual path so the app can switch between Chinese and English without regressions.

## Current Approach

- The app uses `flutter_localizations` in `lib/main.dart`.
- Text and year formatting currently go through `lib/l10n/app_l10n.dart`.
- UI widgets call:
  - `AppL10n.of(context).text(zh, en)` for labels/copy
  - `AppL10n.of(context).formatYear(year)` for historical year display

## Rules for New UI

- Do not add new hardcoded Chinese-only or English-only strings in widgets.
- For any new visible label:
  - Add bilingual text via `AppL10n.text(...)` at callsite, or
  - Add a dedicated getter to `AppL10n` if the term is reused often.
- For years, always use `formatYear(...)`.
- Keep model/data values language-agnostic when possible; localize at render time.

## Suggested Next Upgrade

- Migrate from ad-hoc `text(zh, en)` calls to generated ARB localization files.
- Move repeated keys (e.g. event/sources/territory labels) into typed localization getters.
- Add a widget test that runs under both `zh` and `en` locales and verifies key labels.
