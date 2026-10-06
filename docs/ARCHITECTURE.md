# Architecture and extension guide

## Decisions and boundaries

The latest Word brief's Provider/MVVM direction supersedes the older GetX file. This delivery is Android-only and English. Each business resource has its own immutable typed model and endpoint service; shared list/form infrastructure handles repeated interactions. Widgets do not construct JSON or call Dio. View models own draft validation, screen states and local filtering; domain classes own calculations.

`Json = Map<String, Object?>` is confined to serialization boundaries. Widgets consume typed models, `OperationRow`, `ReportRow`, and string-based form drafts. An injectable HTTP adapter and `SessionStore` allow tests without native plugins or real accounts.

No role matrix is invented from names like Finance Manager. `SessionProvider.allows(module, action)` reads a permissions claim when present, follows the server's OWNER/super-admin bypass and records exact permission failures from HTTP 403. When claims are absent, controls are tentative until the server authorizes/denies them. Accurate menus before first access require an explicit permissions response from the backend.

## Request lifecycle

1. A view observes a Provider view model.
2. The view model validates, calculates and invokes repositories/services.
3. Repositories reuse valid scoped reads. Services serialize explicit field allowlists.
4. The API client adds Bearer and organization/branch headers, timeouts and size limits, then normalizes responses/failures.
5. A write invalidates read caches. The list refetches rather than inventing a server record.
6. Session/scope changes reject old in-flight responses. Slower refreshes cannot replace newer cached/report results.

## Navigation and responsiveness

The session gate owns a navigator keyed by scope revision. Expiry, logout and confirmed scope switches remove nested routes; an old form cannot remain above login. Expiry is checked on app resume and with a foreground timer.

The shell has Home, Transactions, Reports and Profile. Wide screens use a rail, smaller screens bottom navigation. Forms are full-screen below 900 logical pixels and bounded dialogs above it. Fields wrap to available width rather than relying on device names. Save/cancel sit in the scaffold bottom area outside the scrollable body and inside a SafeArea. Unsaved forms ask before discarding.

The screen matrix tests 360, 800 and 1280 logical pixels. Login also has a 320-pixel, 1.6x text check. This is not a claim of exhaustive accessibility or device certification.

## Caching and synchronization

The shared cache keys by token + organization + branch + resource. It holds at most 30 entries for two minutes; lookups and financial reads share it. Forced refresh bypasses cached/in-flight reuse. The newest request owns cache replacement. Writes, logout and scope changes clear it. Stale data is not substituted as a successful response after a failed financial refresh.

The backend has no incremental cursor, ETag/version field, tombstone feed, optimistic concurrency or idempotency-key contract. There is therefore no speculative background push/pull queue or offline financial replay. Safe offline writes require these server guarantees plus an encrypted outbox and conflict rules. Do not add automatic Dio retries to POST/PUT/PATCH/DELETE.

List endpoints return complete arrays. Local pagination is 10 transactions, 20 purchase/sales register rows, and 15 statement/dispatch/attendance report rows. A UI pager does not reduce network/memory usage. Large datasets require a coordinated server-pagination change. Large PDF/CSV exports also run in-process and need profiling with the client's maximum data volume.

## Data rules

Date-only values are calendar dates. Timestamp values use India's +05:30 offset so attendance dates do not change with the device timezone. Invalid dates are rejected; a time suffix is never appended to an existing ISO timestamp. Money uses Indian grouping/two decimals; registers use whole rupees with /-. Negative statement/P&L values use parentheses.

Tonnage/lessing follow the supplied brief; Pieces % is not guessed. Partially typed invalid numbers cannot crash previews. Invalid, non-finite or unsafe totals are rejected before posting. Amounts use doubles to match the provided JavaScript/JSON contract, not a newly invented fixed-point wire format. The backend must independently validate financial calculations and store decimal values correctly.

P&L uses invoices, sales, approved cash/bank entries and the stock snapshot. The brief includes purchases/sales regardless of approval status. Statements start the running balance at zero after date filtering; they do not carry a brought-forward balance. Obtain accountant/client approval and reconcile with the missing React report code.

## Security

- Secure storage holds session metadata/token only; no saved password or client secret.
- No bearer logging, no automatic redirects, HTTPS required, Android backup and cleartext disabled.
- Flutter permissions are usability controls, not authoritative authorization.
- Referenced customer/supplier/item/invoice/branch ownership must be checked server-side.
- Receipt/payment serializers deliberately retain their different snake/camel-case wire contracts.
- CSV protects against formula injection. PDFs use licensed local fonts; add script fonts before supporting regional-language PDF text.
- Financial caches are in memory. Do not add unscoped persistent caches or sensitive analytics.

## Extension workflow

Start with a verified backend request/response example. Update the typed model and service allowlist, add a contract test, then extend the view model and UI. A formerly blocked API-gap control should be enabled only with a verified contract and tests. Shared trade/settlement/dispatch/labour sections can later move into feature folders without changing repository interfaces.
