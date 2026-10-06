# COCOPER — Android mobile & tablet application

Version **2.0.0+3** · COCOS India Pvt. Ltd. · Flutter / Material 3 / Provider MVVM

This new implementation is based on **mobile prompt flutter.docx**, **26 web screenshots**, and the backend TypeScript files in **web_src.zip**. It does not replace the older GetX project. The latest Word brief sets the scope: Android phones/tablets, English UI, transactions and reports, plus sign-in, dashboard and personal profile.

**Status:** Dart analysis and automated tests are run locally; see [test evidence](docs/TEST_REPORT.md). This is not an assertion of production readiness. Android compilation/device testing, deployed-backend UAT and the documented [API gaps](docs/GAPS_AND_HANDOFF.md) remain release gates. No live customer transactions were created during development.

## Screens

| Transactions | Reports |
| --- | --- |
| Purchase Order | Purchase Register |
| Purchase Invoice | Sales Register |
| Sales, including gunny-bag lines | Supplier Statement |
| Loading & Dispatch | Customer Statement |
| Customer Receipt | Pending Dispatch |
| Supplier Payment | Labour Attendance Details |
| Labour Payment | Profit & Loss |
| Cash & Bank Expenses / Income | |

Also included: mobile-client login, session expiry, organization/branch selection, dashboard, profile edit, password change, logout, searchable lookup selectors, filters/pagination, CSV/PDF/share/print, loading/error/empty states and confirmation before destructive actions.

There are **no master maintenance, setup, configuration, user/role administration, employee check-in/out, geofencing, iOS or web targets**. Read-only lookup selectors are not master screens. Earlier multilingual and employee-tracking requests are not silently mixed into this latest English-only brief.

## Run and build

Use **Flutter 3.47.6 / Dart 3.13.5**, the toolchain used for this delivery. Keep `pubspec.lock`. The requested Dart lower-bound is retained in the manifest, but older Flutter compatibility is not claimed: current Material 3 APIs and resolved dependencies are used.

Android builds require Android Studio/SDK, **JDK 17**, SDK platform **36**, and acceptance of the SDK licenses by your team. With this Flutter version, generated defaults are minimum API **24**, target/compile API **36**, NDK **28.2.13676358**.

```sh
flutter --version
flutter doctor -v
flutter pub get
flutter analyze
flutter test --coverage
flutter run
```

Debug/profile defaults to UAT; release defaults to production. Application host constants exist only in `lib/core/config/app_config.dart`.

```sh
flutter run --dart-define=API_BASE_URL=https://uat.cocoper.com/api
flutter build apk --debug --dart-define=API_BASE_URL=https://uat.cocoper.com/api
```

An override must be HTTPS and end in `/api`, without a trailing slash, embedded credentials, query or fragment. There is no environment-settings screen, mock login, hardcoded password or bundled token. Use an authorized backend account provisioned for mobile access.

### Signed release

Confirm the application ID `in.cocoper.cocoper_mobile` before first distribution. Copy `android/key.properties.example` to `android/key.properties` and supply your own signing values. Keep the keystore outside source control. Relative `storeFile` paths resolve from `android/app`.

```sh
flutter build appbundle --release --dart-define=API_BASE_URL=https://cocoper.com/api
```

Release builds deliberately fail without signing configuration; they never fall back to the debug key. No signing key or production credentials are shipped. Distribute the Flutter client as APK/AAB; deploy the separate backend to the server.

## Structure

```text
lib/
  main.dart                      # composition root, session/lifecycle gate
  core/
    config/                      # API host, limits, cache TTL
    errors/                      # UI-facing failures
    network/                     # Dio, envelopes, auth/scope headers
    storage/                     # secure session store abstraction
    utils/                       # JSON, Indian money/date handling
  data/
    models/                      # immutable resource-specific typed models
    services/                    # exact routes and write allowlists
  domain/
    repositories/                # sessions and shared scoped read cache
    operations.dart              # module descriptors and normalized list rows
    calculations.dart            # tested quantity/payment arithmetic
    reports.dart                 # dashboard, statements and P&L arithmetic
  presentation/
    providers/                   # view models; no HTTP/JSON in widgets
    screens/                     # responsive views
    widgets/                     # inputs, scope header, pagination, exports
    theme.dart                   # Material 3 brand tokens
test/                            # contracts, models, calculations, UI, regressions
assets/                          # local logo and licensed offline fonts
android/                         # platform app and signing template
docs/                            # contracts, caveats, UAT checklist, evidence
tool/verify.sh                   # repeatable checks
```

See [architecture](docs/ARCHITECTURE.md), [API mappings](docs/API_CONTRACTS.md) and `SOURCE_TREE.txt` for the complete delivered file list.

## Safety and performance

- Encrypted session storage; passwords are never persisted. Financial records/attachments are not cached on disk by the app.
- Session/organization/branch-scoped read cache: two-minute TTL, maximum 30 resources, concurrent-read deduplication. Writes, scope changes and logout invalidate it; refresh bypasses it.
- No invented refresh-token endpoint. Expiry, app resume and authenticated 401 return to login and remove open routes.
- No offline replay or automatic retry of money writes. Ambiguous saves/approvals require a refresh before retry. Bulk labour writes are not atomic on the supplied server.
- Full arrays are filtered/paginated locally because backend pagination is absent. Genuine large-data scalability needs a backend pagination contract.
- Mobile cards, wide tablet tables, responsive forms and a Save/cancel area outside the scrolling form body.
- CSV formula-injection protection; PDF uses local fonts and exports all filtered rows, not just the current page.

## Known integration limits

The source ZIP contains the backend, **not** the requested React services/reports/dashboard. Pieces % arithmetic, receipt/payment attachment encoding, sales editing (no route), and dispatch/order-to-sale conversions are not invented. Affected controls are visibly disabled and tagged `TODO(API-GAP)` where applicable. Verified tonnage/lessing, settlement and expense contracts are implemented.

Read [GAPS_AND_HANDOFF.md](docs/GAPS_AND_HANDOFF.md) before acceptance. A branch selector is not an authorization boundary; the server must enforce ownership, branch isolation and financial calculations.

## Verification

```sh
bash tool/verify.sh
# Only after intentionally reviewing visual changes, using the matching SDK:
flutter test --update-goldens test/layout_and_navigation_test.dart
```

Tests use synthetic fixtures and a local HTTP adapter, never a live account. Images in `test/goldens/` are rendered Flutter captures, not design mockups. Native picking, secure storage, printing/sharing, signing and device performance require the UAT checklist.

The COCOPER icon is copied from the existing supplied project. Roboto and Material Icons license notices are in `assets/fonts/`. No claim is made about ownership of the client's brand asset.
