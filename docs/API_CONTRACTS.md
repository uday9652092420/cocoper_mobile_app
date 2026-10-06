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

The client conservatively disables edits/deletes on approved/completed entries. Source=mobile labour rows are view-only in the payment screen because their IDs do not identify editable web payment records. Group-less legacy records cannot be group-approved without server correction.

## Payload highlights

- PO: poNumber, organizationId, supplierId, branchId, warehouseId, date, remarks, status, purchaseOrderInvoiceStatus, mode, lines. Each line retains quantity, discount, piecesPercentage, pieces, baseCost, actualQuantity, purchaseCost, purchaseAmount, amount and rate.
- PI: invoiceNo, supplierId, branchId, purchaseOrderId, invoiceDate, mode, loadingCost, marketCess, bagsAndSticks, freight, grandTotal, outstandingAmount, status, supplierPaymentReceiptStatus and lines. PI line quantity is quantityTons.
- Sales: directSaleNo, salesOrderNo, customerId, branchId, invoiceDate, mode, invoiceTotal, charges, lines and gunnyBags. Sales line price/amount are salesPrice/salesAmount. Bag lines include bagTypeId, bharthiTypeId, bagBharthi, quantity, rate and amount. Blank directSaleNo lets the server allocate its number. Linked-order conversion is disabled until its stock behavior is confirmed.
- Dispatch: dispatchNumber, customerId, lorryNumber, driverName, driverMobile, dispatchStatus, dispatchDate, invoiceGenerated and lines. Each line has branchId, date, itemId, bharthi, quantity, loadedQuantity and pendingQuantity. Only Dispatched counts as completed.
- Receipt: **snake_case** receipt_no, customer_id, receipt_date, invoice_mode, invoice_no, amount, payment_mode, remarks, attachment_names, attachment_files, organization_id. GET /customer-receipts/next-no allocates the displayed number. Invoice mode selects an approved sale's actual invoice_no, not its ID. Cumulative mode sends null invoice_no. Supplied payment_mode contract is Cash or UPI.
- Supplier payment: **camelCase** paymentNumber, supplierId, supplierName, date, invoiceMode, paymentMode, amount, purchaseInvoiceId, remarks, attachmentNames, attachmentFiles, organizationId. GET /supplier-payments/next-no supplies its number. Cumulative mode sends null purchaseInvoiceId. Partial payments are allowed.
- Labour: records contain labour_id, labour_name, type, attendance_date, shift, in_time, out_time, hours, morning_ot, evening_ot, ot_rate, loading_10_tons_amount, loading_20_tons_amount, payment_group_id. Do not submit computed ot_hours/total_ot_amount. Bulk and per-row updates may partially succeed; automatic retries are unsafe.
- Expense/income: branchId, date, paymentMode (Cash/Bank/UPI), transactionType (Expenses/Income), amount, description and attachments. Each attachment is {name,mimeType,data}, with a data: URL. App limits: five files, 5 MiB per file, 14 MiB total encoded request (server JSON limit is 15 MiB). Receipt/payment attachments are a different, unverified text-column encoding and are not uploaded here.

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
