import 'purchase_invoice_line.dart';

/// A Purchase Invoice as returned by the backend.
///
/// Field names follow the verified backend contract. The list endpoint
/// (GET /purchase-invoices) returns a raw array of these objects, including
/// their lines.
class PurchaseInvoice {
  final String id;
  final String createdAt;
  final String invoiceNumber;
  final String organizationId;
  final String supplierId;
  final String supplierName;
  final String branchId;
  final String branchName;
  final String purchaseOrderId;
  final String date; // invoiceDate (DD/MM/YYYY as returned by the backend)
  final String mode;
  final double loadingCost;
  final double marketCess;
  final double bagsAndSticks;
  final double freight;
  final double grandTotal;
  final double outstandingAmount;
  final String status;
  final bool supplierPaymentReceiptStatus;
  final List<PurchaseInvoiceLine> lines;

  const PurchaseInvoice({
    this.id = '',
    this.createdAt = '',
    this.invoiceNumber = '',
    this.organizationId = '',
    this.supplierId = '',
    this.supplierName = '',
    this.branchId = '',
    this.branchName = '',
    this.purchaseOrderId = '',
    this.date = '',
    this.mode = '',
    this.loadingCost = 0,
    this.marketCess = 0,
    this.bagsAndSticks = 0,
    this.freight = 0,
    this.grandTotal = 0,
    this.outstandingAmount = 0,
    this.status = '',
    this.supplierPaymentReceiptStatus = false,
    this.lines = const [],
  });

  factory PurchaseInvoice.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final parsedLines = rawLines is List
        ? rawLines
              .whereType<Map<String, dynamic>>()
              .map(PurchaseInvoiceLine.fromJson)
              .toList()
        : <PurchaseInvoiceLine>[];

    final rawSupplier = json['supplier'];
    final supplier = rawSupplier is Map
        ? Map<String, dynamic>.from(rawSupplier)
        : const <String, dynamic>{};

    final rawBranch = json['branch'];
    final branch = rawBranch is Map
        ? Map<String, dynamic>.from(rawBranch)
        : const <String, dynamic>{};

    return PurchaseInvoice(
      id: _string(json['id'] ?? json['_id']),
      createdAt: _string(json['createdAt'] ?? json['created_at']),
      invoiceNumber: _string(
        json['invoiceNo'] ??
            json['invoice_no'] ??
            json['invoiceNumber'] ??
            json['invoice_number'],
      ),
      organizationId: _string(
        json['organizationId'] ?? json['organization_id'],
      ),
      supplierId: _string(
        json['supplierId'] ?? json['supplier_id'] ?? supplier['id'],
      ),
      supplierName: _string(
        json['supplierName'] ??
            json['supplier_name'] ??
            supplier['name'] ??
            supplier['supplier_name'],
      ),
      branchId: _string(json['branchId'] ?? json['branch_id'] ?? branch['id']),
      branchName: _string(
        json['branchName'] ?? json['branch_name'] ?? branch['name'],
      ),
      purchaseOrderId: _string(
        json['purchaseOrderId'] ?? json['purchase_order_id'],
      ),
      date: _string(
        json['invoiceDate'] ?? json['invoice_date'] ?? json['date'],
      ),
      mode: _string(json['mode']),
      loadingCost: _double(json['loadingCost'] ?? json['loading_cost']),
      marketCess: _double(json['marketCess'] ?? json['market_cess']),
      bagsAndSticks: _double(
        json['bagsAndSticks'] ?? json['bags_and_sticks'],
      ),
      freight: _double(json['freight']),
      grandTotal: _double(
        json['grandTotal'] ??
            json['grand_total'] ??
            json['total'] ??
            json['totalAmount'] ??
            json['total_amount'],
      ),
      outstandingAmount: _double(
        json['outstandingAmount'] ?? json['outstanding_amount'],
      ),
      status: _string(json['status']),
      supplierPaymentReceiptStatus: _bool(
        json['supplierPaymentReceiptStatus'] ??
            json['supplier_payment_receipt_status'],
      ),
      lines: parsedLines,
    );
  }

  double get linesTotal => lines.fold(
        0,
        (sum, line) => sum + line.purchaseAmount,
      );

  double get additionalTotal =>
      loadingCost + marketCess + bagsAndSticks + freight;

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static double _double(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().toLowerCase() == 'true';
  }
}
