/// A Purchase Invoice as returned by the backend.
///
/// Field names are a best-effort mapping based on the Purchase Order and Sales
/// Order contracts (camelCase with snake_case fallbacks). NOT CONFIRMED against
/// a supplied Purchase Invoice spec.
class PurchaseInvoice {
  final String id;
  final String invoiceNumber;
  final String date;
  final String supplierId;
  final String supplierName;
  final String branchId;
  final String branchName;
  final double grandTotal;
  final String paymentReceipt;
  final String status;

  const PurchaseInvoice({
    this.id = '',
    this.invoiceNumber = '',
    this.date = '',
    this.supplierId = '',
    this.supplierName = '',
    this.branchId = '',
    this.branchName = '',
    this.grandTotal = 0,
    this.paymentReceipt = '',
    this.status = '',
  });

  factory PurchaseInvoice.fromJson(Map<String, dynamic> json) {
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
      invoiceNumber: _string(
        json['invoiceNumber'] ??
            json['invoice_number'] ??
            json['invoiceNo'] ??
            json['invoice_no'],
      ),
      date: _string(json['date'] ?? json['invoiceDate'] ?? json['invoice_date']),
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
      grandTotal: _double(
        json['grandTotal'] ??
            json['grand_total'] ??
            json['total'] ??
            json['totalAmount'] ??
            json['total_amount'],
      ),
      paymentReceipt: _string(
        json['paymentReceipt'] ??
            json['payment_receipt'] ??
            json['paymentStatus'] ??
            json['payment_status'],
      ),
      status: _string(json['status']),
    );
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static double _double(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
