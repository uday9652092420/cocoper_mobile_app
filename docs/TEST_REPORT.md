# Verification report — 4 October 2026

## Verified locally

- Flutter **3.47.6**, framework revision **5fc346839b5d0eef006ed8404392afb4dfae428d**.
- Dart **3.13.5**; macOS host.
- Dependency resolution completed; the resolved pubspec.lock is included.
- Formatting: **79 Dart files checked; no changes required**.
- Static analysis: **No issues found**.
- Automated suite: **47 tests passed**, zero failing tests across six test files.
- Instrumented Dart line coverage: **3,021 / 3,786 = 79.79%**.
- Five rendered golden images pass comparison after visual inspection.
- Clean ZIP extraction independently resolved dependencies, passed static analysis and passed all 47 tests again. The archive contains 124 files and excludes build caches, local SDK paths and signing secrets.
- Android debug APK command was attempted and stopped with **No Android SDK found**. No successful native build, signed artifact, emulator run or device certification is claimed.

Coverage refers to instrumented Dart application lines in Flutter's LCOV output, not branch coverage, server coverage, Android plugin coverage or proof that every business scenario is correct.

## Commands actually run

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --coverage --reporter expanded
flutter build apk --debug
```

The build command's environmental failure is separate from the passing Dart analysis/widget tests.

## Test inventory

| File | Coverage focus |
| --- | --- |
| api_contract_test.dart | Three response envelopes; error shapes; mobile login payload; Bearer and scope headers; 401 clearing without refresh; exact 403 action denial; every approval method; labour payload exclusions; dispatch POST update; settlement casing; stock query; scoped cache/deduplication; unsupported query rejection |
| calculations_test.dart | Indian money/dates, timestamp boundary handling, typed decoding, tonnage/lessing, ledger running balance, P&L, dashboard and expired sessions |
| form_provider_test.dart | Calculated purchase write; invalid/required numbers; invoice/cumulative receipt selection; changing supplier clears invoice; partial bulk failure retry lock; Pieces % guard |
| robustness_test.dart | All eight new-entry payloads; invalid/overflow numeric previews; ambiguous approval guard; scope-change response rejection; out-of-order cache/report refresh; local pagination/reset; safe CSV; PDF generation with embedded fonts |
| model_serialization_test.dart | Missing/null/default round trips for 30 models plus bootstrap; nested numeric-string decoding |
| layout_and_navigation_test.dart | Eight lists, eight forms and seven reports at three widths; fixed Save bar while scrolling; login/navigation/session removal; large text; successful save; discard confirmation; profile editor cancel |

The screen matrix exercises **69 screen/width combinations**: 24 transaction lists + 24 transaction forms + 21 reports. It uses synthetic fixtures, not production financial data. The navigation test triggers session removal directly, while the separate HTTP contract test verifies that authenticated 401 causes that session removal.

## Visual captures

- test/goldens/purchase_invoice_mobile.png
- test/goldens/purchase_invoice_tablet.png
- test/goldens/sales_form_mobile.png
- test/goldens/sales_form_mobile_scrolled.png
- test/goldens/labour_form_tablet.png

Golden dates are fixed to avoid failures on the next calendar day. Fonts/icons are loaded explicitly in tests so the captures show actual text, not Flutter's test-placeholder glyphs. These are widget-rendering checks, not screenshots taken on Android hardware.

## Defects corrected during verification

- Initial syntax/lint issues and nullable/dual-case field mappings.
- Footer/pop behavior for saved and discarded forms.
- Incorrect reuse of old report/cache results when refreshes complete out of order.
- Numeric preview crashes and non-finite/unsafe calculated amounts.
- Search reset state not resetting the visible search field.
- Stale linked invoice/bag selections after the parent selection changes.
- Requests from a previous organization being accepted after switching scope.
- Ambiguous approval/save retries that could replay a financial write.
- Unverified API paths/calculations being exposed as if supported.
- Model fallbacks for report units and India timestamp/calendar handling.

## Not verified

Live-backend contract behavior, backend deployment/database migrations, real role provisioning, actual stock/balance posting, Android Gradle/native-plugin compilation, secure-storage behavior on hardware, file picker/sharing/printing integrations, low-memory/device performance, signed release distribution and the missing-frontend/API-gap workflows remain unverified. See GAPS_AND_HANDOFF.md for the required acceptance checklist.

No real account login, production transaction creation, deletion, approval, payment or deployment was performed in these tests.
