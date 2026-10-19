# Verified backend contract map

Paths below are relative to the configured /api base URL. These mappings come from the supplied TypeScript source, not observations of a deployed UAT server.

## Authentication and scope

- POST /auth/login: {email, password, client: "mobile"}. The email input also accepts the username value supported by the server.
- Response: token, expiresAt (epoch seconds), user containing id, username, full_name, role, is_super_admin and organization_id.
- Header: Authorization: Bearer <token>. No refresh endpoint exists.
- GET /mobile/bootstrap uses Bearer only; response includes organization, branches and default_branch_id.
- POST /auth/logout revokes the current session; local credentials are cleared even if the network fails.
- Scoped requests send x-organization-id and, if selected, x-branch-id. This does not imply every server module filters by branch.
- Super-admin bootstrap is incompatible with the mobile endpoint in the supplied code. The verified /organizations and /branches reads are used to select scope instead.
- Profile: GET /profile/me, PUT /profile/me with full_name, email, mobile_no, profile_picture, and PUT /profile/password with old_password/new_password.

HTTP 401 on an authenticated request clears the session. HTTP 403 retains the exact server message; a permission message disables that module action for the current session. The API layer handles wrapped {success,data}, bare arrays/objects and ad-hoc auth/bootstrap responses. Global, local and 404 errors retain their message. No guessed server pagination parameters are sent.

## Transactions

| Module | Read/create/update | Approval | Delete |
| --- | --- | --- | --- |
| Purchase Order | GET/POST /purchase-orders; PUT /purchase-orders/:id | PUT same resource with full verified payload and status=Approved | DELETE /purchase-orders/:id |
| Purchase Invoice | GET/POST /purchase-invoices; PUT /purchase-invoices/:id | PUT same resource with status=Approved | DELETE /purchase-invoices/:id |
| Sales | GET/POST /direct-sales; **no edit route** | POST /direct-sales/:id/approve | DELETE /direct-sales/:id |
| Loading & Dispatch | GET/POST /loading-dispatch; update is POST with body id | PATCH /loading-dispatch/:id/status {status} | DELETE /loading-dispatch/:id |
| Customer Receipt | GET/POST /customer-receipts; PUT /customer-receipts/:id | POST /customer-receipts/:id/approve | DELETE /customer-receipts/:id |
| Supplier Payment | GET/POST /supplier-payments; PUT /supplier-payments/:id | POST /supplier-payments/:id/approve | DELETE /supplier-payments/:id |
| Labour Payment | GET /labour-attendance; POST {records:[...]}; PUT /labour-attendance/:id | PATCH /labour-attendance/group/:groupId/status {status} | DELETE /labour-attendance/group/:groupId |
| Cash & Bank Expenses | GET/POST /cash-bank-expenses; PUT /cash-bank-expenses/:id | POST /cash-bank-expenses/:id/approve | DELETE /cash-bank-expenses/:id |
| Bag Purchase | GET/POST /bag-purchases; GET/PUT /bag-purchases/:id | Not verified | DELETE /bag-purchases/:id |

There is no verified Purchase Order → Sales Order conversion endpoint in the
supplied backend contract. `POST /sales-orders` is a generic Sales Order create
route; accepting `sourcePoId` and `poNumber` does not establish safe conversion,
link persistence, or duplicate protection. Do not use it as a conversion
operation. Enabling conversion requires a documented authenticated operation
and payload, permitted Purchase Order status and permissions, an authoritative
response/detail representation containing the linked Sales Order ID and
persisted converted state, database-backed atomic/idempotent duplicate
protection, and confirmed stock, accounting, and audit effects.

The supplied contract only verifies `GET /sales-orders` as a read-only lookup
whose list records include line items. The mobile client contains a Sales Order
creation request, but no verified Sales Order update, delete, detail, or
approval route is documented. The Edit screen refreshes the list and resolves
the selected order by ID; it displays Draft fields and locally edits supported
basic fields and lines only for the verified `tonage` and `lessing` calculation
modes. Pieces-percentage and unknown modes preserve their existing values and
keep line editing disabled. Save Changes remains disabled because no update
request schema is verified. Approved and unrecognized statuses are read-only.
Approval and deletion remain unavailable; the list does not expose Delete until
a verified delete endpoint and Draft-deletion rule are available.
Do not infer an update/approval/delete route or reuse the create endpoint for
any of these operations. The View screen also refreshes the list and resolves
the selected order by ID because a detail endpoint is not documented.

Bag Purchase contract verified from the supplied TypeScript source: the list
accepts optional `organizationId` and `branchId` query parameters and can be
searched locally by purchase number, supplier name/code/ID, and remarks.
Create and update send `purchase_date` (`YYYY-MM-DD`), `supplier_id`,
`remarks`, `organization_id`, `branch_id`, and the complete `lines` array
(`gunny_bag_id`, `quantity`, `rate`). The server generates the purchase number
and authoritative amounts/totals. Supplier, branch, and gunny-bag selectors
use the existing GET `/suppliers`, `/branches`, and `/gunny-bags` lookups;
gunny-bag rates use `rate_per_bag`. These three selectors are organization-level
master data and are requested without a branch header, matching the working
Direct Sales lookups. Gunny bag entries are read from `id`/`_id`, `bag_type_id`,
`bag_id`, `bag_name`, `bag_code`, and `rate_per_bag`; a successful but empty list
is reported separately from a failed request. There is no verified pagination,
sorting, or status-filter contract. Quantity must be greater than zero and rate
must be nonnegative; no discount, tax, or Bharthi is submitted.

The live UAT list endpoint was re-checked against the web client: the web sends
only the organization and auth headers, while the backend additionally narrows
the list when `branchId` or `x-branch-id` is present. A branch that holds no bag
purchases (including a stale or unknown branch ID) is answered with HTTP 200 and
`{"success": true, "data": []}`, which cannot be told apart from an empty
organization. The mobile saved list therefore stays organization-scoped, like the
web client, so existing purchases are never hidden by the session branch;
create, update, and delete still send the session branch.

The supplied backend source has no route-level authentication/permission
middleware for Bag Purchase, and its single-record read/update/delete handlers
do not enforce organization/branch ownership. Client scope headers and query
parameters are sent but do not resolve that backend authorization gap. Do not
treat the client UI as a security boundary; the backend must be secured before
these operations are exposed to users who should not have unrestricted access.

The client conservatively disables edits/deletes on approved/completed entries. Source=mobile labour rows are view-only in the payment screen because their IDs do not identify editable web payment records. Group-less legacy records cannot be group-approved without server correction.

## Payload highlights

- PO: poNumber, organizationId, supplierId, branchId, warehouseId, date, remarks, status, purchaseOrderInvoiceStatus, mode, lines. Each line retains quantity, discount, piecesPercentage, pieces, baseCost, actualQuantity, purchaseCost, purchaseAmount, amount and rate.
- PI: invoiceNo, supplierId, branchId, purchaseOrderId, invoiceDate, mode, loadingCost, marketCess, bagsAndSticks, freight, grandTotal, outstandingAmount, status, supplierPaymentReceiptStatus and lines. PI line quantity is quantityTons.
- Sales: directSaleNo, salesOrderNo, customerId, branchId, invoiceDate, mode, invoiceTotal, charges, lines and gunnyBags. Sales line price/amount are salesPrice/salesAmount. Bag lines include bagTypeId, bharthiTypeId, bagBharthi, quantity, rate and amount. Blank directSaleNo lets the server allocate its number. Linked-order conversion is disabled until its stock behavior is confirmed.
- Dispatch: dispatchNumber, customerId, lorryNumber, driverName, driverMobile, dispatchStatus, dispatchDate, invoiceGenerated and lines. Each line has branchId, date, itemId, bharthi, quantity, loadedQuantity and pendingQuantity. Only Dispatched counts as completed.
- Receipt: **snake_case** receipt_no, customer_id, receipt_date, invoice_mode, invoice_no, amount, payment_mode, remarks, attachment_names, attachment_files, organization_id. GET /customer-receipts/next-no allocates the displayed number. Invoice mode selects an approved sale's actual invoice_no, not its ID. Cumulative mode sends null invoice_no. Supplied payment_mode contract is Cash or UPI. Customer receipt attachments are JSON-encoded strings containing parallel filename and data-URL arrays; the local backend schema stores them in text columns and has a 15 MiB JSON body limit. Mobile limits combined raw files to 10 MiB. The collection query omits attachment fields, and PUT overwrites those columns with null if omitted. The staging detail endpoint GET /customer-receipts/:id returns the full receipt, including both attachment fields; this route is not confirmed in every deployed environment. Edit falls back to the refreshed collection record if detail returns 404 but the requested ID is still listed, and requires an explicit attachment replacement before saving when attachment data is unavailable. New attachments append to existing metadata by default when the detail response supplies it; replacing is an explicit client choice. Confirm the same detail response contract in other deployed environments.
- Supplier payment: **camelCase** paymentNumber, supplierId, supplierName, date, invoiceMode, paymentMode, amount, purchaseInvoiceId, remarks, attachmentNames, attachmentFiles, organizationId. GET /supplier-payments/next-no supplies its number. Cumulative mode sends null purchaseInvoiceId. Partial payments are allowed.
- Labour: records contain labour_id, labour_name, type, attendance_date, shift, in_time, out_time, hours, morning_ot, evening_ot, ot_rate, loading_10_tons_amount, loading_20_tons_amount, payment_group_id. Do not submit computed ot_hours/total_ot_amount. Bulk and per-row updates may partially succeed; automatic retries are unsafe.
- Expense/income: branchId, date, paymentMode (Cash/Bank/UPI), transactionType (Expenses/Income), amount, description and attachments. Each attachment is {name,mimeType,data}, with a data: URL. App limits: five files, 5 MiB per file, 14 MiB total encoded request (server JSON limit is 15 MiB). Receipt/payment attachments are a different, unverified text-column encoding and are not uploaded here.

Loading & Dispatch reads the full nested-line collection from
`GET /loading-dispatch`; there is no verified detail endpoint, so View and Edit
refresh the list and resolve the selected database ID. Create and update both
use `POST /loading-dispatch`; updates include the existing dispatch ID and
loading-line IDs in the request body. The mobile form does not collect a
dispatch number; it omits the number on create and preserves the number
returned for an existing dispatch on update. The backend uses its generated
dispatch ID as the dispatch number when create omits it. Delete uses
`DELETE /loading-dispatch/:id`. Customer, branch, and item selectors reuse the
existing `GET /customers`, `GET /branches`, and `GET /items` lookups. The
`GET /gunny-bags` master lookup also populates the line's Bharthi selector,
using the existing Gunny Bag master fields (`id`/`bag_type_id`, `bag_name`,
and optional `bag_code`). The selected bag name is sent in the existing scalar
`bharthi` line field. This is an in-app mapping; the standalone Loading &
Dispatch API document was not present in the repository to verify any further
payload semantics. The lookup is organization-scoped and does not depend on the
selected branch. The separate status route is not used to infer or perform
approval transitions.

Cash & Bank Expenses are read from the organization-scoped
`GET /cash-bank-expenses` envelope (`{success, data}`). There is no detail
route; View and Edit refresh that list and resolve the record by its database
`id`. `GET /branches` returns a raw array and the selected `branchId` is part
of each create/update payload. `PUT /cash-bank-expenses/:id` overwrites the
stored attachments array. Edit therefore submits the currently selected
attachment objects, preserving files by default while allowing individual
existing files to be removed, new files to be added, or all files to be
removed. If the attachment array is missing or malformed, the client blocks
update rather than risking file loss. Draft records can be edited, approved,
or deleted; approved records are read-only in the client. No server pagination
or detail endpoint is verified, so list reads remain complete and detail views
resolve the selected database ID from that list.

Mode values are deliberately spelled exactly as the server expects: tonage, lessing, tonagePercentage. Tonnage actual quantity = quantity × 1000 / (discount + 1000); lessing = quantity − discount. Pieces % creation/editing is blocked pending the missing calculation contract.

## Read-only lookups

GET /suppliers, /customers, /items, /branches, /warehouses, /gunny-bags, /labour-staff, /sales-orders. Super-admin scope selection also reads /organizations. No write methods or master screens are exposed for these.

## Reports and dashboard

There are no guessed /reports or /dashboard endpoints.

| Screen | Sources |
| --- | --- |
| Dashboard | suppliers, customers, purchase invoices, direct sales, loading dispatches, customer receipts (six parallel reads) |
| Purchase Register | purchase invoices + suppliers + current scope branches |
| Sales Register | direct sales + customers + branches |
| Supplier Statement | purchase invoices + supplier payments + suppliers |
| Customer Statement | approved direct sales + customer receipts + customers |
| Pending Dispatch | loading dispatches + customers + branches |
| Labour Attendance Details | GET /labour-attendance/details |
| P&L | invoices + sales + expenses + GET /profit-loss/stock-snapshot?fromDate=YYYY-MM-DD&toDate=YYYY-MM-DD |

Only the stock snapshot accepts fromDate/toDate query parameters. Date filtering, search and pagination for other lists are local.

Statements merge invoices and settlements in date/createdAt/ID order and begin the filtered running balance at zero. P&L: COGS = opening stock + purchases − closing stock; gross = sales − COGS; net = gross + approved other income − approved expenses. Stock rates divide valuation by units, with zero-unit protection. Purchase/sales movement units use actualQuantity when supplied and their source quantity otherwise.
