# Gaps, acceptance gates and team handoff

## Inputs actually supplied

Reviewed: the latest Word prompt; 26 screenshots; backend routes, permission middleware, auth/mobile/profile source, all eight relevant transaction/report module folders, and read-only lookup types/routes. The screenshots ZIP and backend ZIP were extracted separately. Older generated Flutter projects were not overwritten.

**Missing:** the React frontend src/services, src/pages/reports, DashboardPage, src/utils/format.ts, apiHeaders.ts and src/config/api.ts. Despite the archive name, web_src.zip contains backend src files, not those frontend files. Screenshot/Word rules can be implemented, but they cannot establish unknown wire encoding or omitted calculation/conversion behavior.

## Explicit API gaps

| Gap | Current behavior | Needed to enable/finish |
| --- | --- | --- |
| Pieces % formula | Existing data viewable; creation/edit submission blocked | Web line-calculation code, units, rounding and worked examples |
| Receipt/payment attachments | Existing text values preserved; no new upload encoding invented | Actual frontend serialization plus example saved values and attachment retrieval rules |
| Sales edit | Disabled | A supported server update route, or agreed business replacement/reversal workflow |
| Dispatch → invoice | Disabled | Exact frontend conversion payload and verified association/idempotency/stock behavior |
| Sales-order → sale link | New direct sales only; order field disabled | Conversion contract, since salesOrderNo changes stock deduction on the server |
| Number generation | Receipt/payment next-number endpoints used; Sales can allocate server-side; PO/PI/Dispatch number is entered | Confirm prefix/counter allocation for the remaining modules |
| Super-admin bootstrap | Uses organization/branch lookup instead of incompatible mobile bootstrap | Server bootstrap support for super-admin users |
| Normal-user organization code | Organization name displayed; no code invented | Add code to bootstrap if mandatory |
| Per-role menus before first access | Claims if available, otherwise server 403 feedback | Explicit current-user permissions list and refresh/revocation behavior |
| Branch-isolated settlements/labour | No fabricated branch filter for records without branch attribution | Server persistence/filtering rules for these records; ownership checks throughout |
| Atomic/replay-safe writes | No automatic financial retries; uncertain writes require reconciliation | Idempotency keys and transactions, particularly bulk labour and stock posting |
| Exact frontend parity | Screens adapted from supplied images and brief | Missing React services/reports and client UAT comparisons |

Search source for TODO(API-GAP) before enabling these controls. Do not remove a guard merely to make a button clickable.

## Backend checks before production

The mobile client cannot repair backend authorization/accounting solely in Flutter. The supplied server must be reviewed for:
- Organization ownership in every get/update/delete/upsert and referenced foreign ID.
- Branch access enforcement, not just accepting x-branch-id.
- Dispatch upsert conflict ownership and stock mutation scoping.
- Server-calculated/validated quantities, discounts, totals, balances, approval transitions and attachment validation.
- Atomic labour bulk writes; sequential insert/update failures may leave partial data.
- Idempotent approval/posting and duplicate-number protection during concurrent entry.
- Non-negative inventory/payment limits, reversals and invoice reconciliation as agreed with the client.
- Token/session revocation, role changes, audit trails, backups, TLS and deployment configuration.

These are release review items, not claims that the supplied backend has been comprehensively penetration-tested. No backend source was modified in this delivery.

## Required verification on your environment

1. Install the documented Flutter, JDK and Android SDK versions. Run tool/verify.sh and build a debug UAT APK. The delivery machine did not have an Android SDK; no successful APK/AAB compilation is claimed.
2. Test a real Android phone at the minimum supported API and a modern low-memory phone; test an 8–10 inch tablet in portrait/landscape and with larger text. Check keyboard behavior, long names, large lists, scrolling and Save/cancel placement.
3. Use synthetic UAT accounts for OWNER, regular restricted users and super-admin. Check login, wrong password, mobile access, expiry while a form is open, background/resume, 401, 403, organization/branch change, logout offline and restored sessions.
4. Create/view/edit/approve/delete representative records for each supported route. Verify stock, balances, totals, dates, party IDs, branch IDs, rounding and duplicate behavior directly against UAT/admin records. Use throwaway UAT data; do not run mutation tests against production.
5. For receipts/payments, test invoice-by-invoice and cumulative modes, partial amounts, party changes, Cash/UPI/Bank only where the respective endpoint supports them, and approval/reconciliation.
6. For labour, test regular/temporary staff, all shifts, morning/evening OT, both loading amounts, grouped approval, legacy rows, mobile-origin read-only rows and intentionally interrupted multi-row submissions.
7. For expenses, pick actual PNG/JPEG/PDF files, cancel picking, test five-file/size limits, repeated selection/removal, slow upload and server rejection. Verify Android sharing/printing and encrypted session storage across kill/restart/reinstall. Native plugins are not exercised by widget tests.
8. Compare every report and dashboard with the backend/web data. Confirm statement zero-opening behavior and the P&L approval rules with the client's accountant. Check date boundaries in India, zero/negative values, empty data, CSV/PDF exports and large report sizes.
9. Resolve the missing-frontend/API gaps. Confirm application ID, final app/launcher branding, support/privacy copy, signing key custody and release distribution. Release signing is never supplied by the generated source.
10. Run security/dependency review and device performance profiling. Re-run all tests after customization, then obtain signed UAT approval before switching to the production API.

## Scope not silently carried forward

The latest prompt is Android + English + transaction/report operations with dashboard/profile. Personal employee attendance/geofencing, multilingual localization, bag-purchase master/setup workflows, notifications, subscription billing and web deployment are not added from historical chat requests. Add them only under a separately confirmed updated scope.

The source is intended for a development team to continue and validate. Automated checks are evidence for the covered behaviors, not a guarantee that no defects remain or that unspecified server behavior is correct.
