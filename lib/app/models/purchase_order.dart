import 'purchase_order_line.dart';

/// A Purchase Order as returned by the backend.
///
/// The list endpoint (GET /purchase-orders) returns a raw array of these
/// objects, including their lines.
class PurchaseOrder {
  final String id;
  final String poNumber;
  final String organizationId;
  final String supplierId;
  final String supplierName;
  final String branchId;
  final String branchName;
  final String warehouseId;
  final String date;
  final String remarks;
  final String status;
  final String purchaseOrderInvoiceStatus;
  final String mode;
  final List<PurchaseOrderLine> lines;

  const PurchaseOrder({
    this.id = '',
    this.poNumber = '',
    this.organizationId = '',
    this.supplierId = '',
    this.supplierName = '',
    this.branchId = '',
    this.branchName = '',
    this.warehouseId = '',
    this.date = '',
    this.remarks = '',
    this.status = '',
    this.purchaseOrderInvoiceStatus = '',
    this.mode = '',
    this.lines = const [],
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final parsedLines = rawLines is List
        ? rawLines
            .whereType<Map<String, dynamic>>()
            .map(PurchaseOrderLine.fromJson)
            .toList()
        : <PurchaseOrderLine>[];

    final rawSupplier = json['supplier'];
    final supplier = rawSupplier is Map
        ? Map<String, dynamic>.from(rawSupplier)
        : const <String, dynamic>{};

    final rawBranch = json['branch'];
    final branch = rawBranch is Map
        ? Map<String, dynamic>.from(rawBranch)
        : const <String, dynamic>{};

    return PurchaseOrder(
      id: _string(json['id'] ?? json['_id']),
      poNumber: _string(json['poNumber'] ?? json['po_number']),
      organizationId: _string(
        json['organizationId'] ?? json['organization_id'],
      ),
      supplierId: _string(json['supplierId'] ?? json['supplier_id']),
      supplierName: _string(
        json['supplierName'] ??
            json['supplier_name'] ??
            supplier['name'] ??
            supplier['supplier_name'],
      ),
      branchId: _string(json['branchId'] ?? json['branch_id']),
      branchName: _string(
        json['branchName'] ?? json['branch_name'] ?? branch['name'],
      ),
      warehouseId: _string(json['warehouseId'] ?? json['warehouse_id']),
      date: _string(json['date'] ?? json['po_date']),
      remarks: _string(json['remarks']),
      status: _string(json['status']),
      purchaseOrderInvoiceStatus: _string(
        json['purchaseOrderInvoiceStatus'] ??
            json['purchase_order_invoice_status'],
      ),
      mode: _string(json['mode']),
      lines: parsedLines,
    );
  }

  double get totalAmount => lines.fold(
        0,
        (sum, line) =>
            sum + (line.amount != 0 ? line.amount : line.purchaseAmount),
      );

  static String _string(dynamic value) => value?.toString().trim() ?? '';
}
