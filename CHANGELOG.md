# Changelog

All notable changes to this project should be documented in this file.

## Unreleased

### Changed
- Pin `sentry_flutter` to `9.13.0` and `purchases_flutter` to `9.12.0` to resolve macOS build pod conflicts and stabilize native plugin versions.

### Notes
- Upstream changelogs:
  - Sentry: https://github.com/getsentry/sentry-dart/releases/tag/9.13.0 (native traceId sync, dependency bumps)
  - RevenueCat / purchases_flutter: https://github.com/RevenueCat/purchases-flutter/releases/tag/9.12.0 (dependency updates, bugfixes)
- Verification performed: `flutter test` (unit tests passed), `flutter run -d macos` (macOS debug build succeeded and app binary produced).

### QA / Follow-ups
- Manually validate RevenueCat / purchases flows on device/emulator.
- Resolve remaining analyzer hints (UI color deprecation: `surfaceVariant`) in `lib/core/widgets/loading/shimmer_box.dart`.
- After PR review, consider replacing exact pins with caret ranges if wider semver flexibility is desired.
