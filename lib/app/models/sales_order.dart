import 'sales_order_line.dart';

/// A Sales Order as returned by the backend.
///
/// The list endpoint (GET /sales-orders) returns a raw array of these
/// objects, including their lines.
class SalesOrder {
  final String id;
  final String soNumber;
  final String date;
  final String customerId;
  final String customerName;
  final String branchId;
  final String remarks;
  final String status;
  final String mode;
  final String sourcePoId;
  final String poNumber;
  final List<SalesOrderLine> lines;

  const SalesOrder({
    this.id = '',
    this.soNumber = '',
    this.date = '',
    this.customerId = '',
    this.customerName = '',
    this.branchId = '',
    this.remarks = '',
    this.status = '',
    this.mode = '',
    this.sourcePoId = '',
    this.poNumber = '',
    this.lines = const [],
  });

  factory SalesOrder.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final parsedLines = rawLines is List
        ? rawLines
            .whereType<Map<dynamic, dynamic>>()
            .map((line) => SalesOrderLine.fromJson(
                  Map<String, dynamic>.from(line),
                ))
            .toList()
        : <SalesOrderLine>[];

    final rawCustomer = json['customer'];
    final customer = rawCustomer is Map
        ? Map<String, dynamic>.from(rawCustomer)
        : const <String, dynamic>{};

    return SalesOrder(
      id: _string(json['id'] ?? json['_id']),
      soNumber: _string(json['soNumber'] ?? json['so_number']),
      date: _string(json['date'] ?? json['invoiceDate']),
      customerId: _string(
        json['customerId'] ?? json['customer_id'] ?? customer['id'],
      ),
      customerName: _string(
        json['customerName'] ??
            json['customer_name'] ??
            customer['name'] ??
            customer['customer_name'],
      ),
      branchId: _string(json['branchId'] ?? json['branch_id']),
      remarks: _string(json['remarks']),
      status: _string(json['status']),
      mode: _string(json['mode']),
      sourcePoId: _string(
        json['sourcePOId'] ?? json['sourcePoId'] ?? json['source_po_id'],
      ),
      poNumber: _string(json['poNumber'] ?? json['po_number']),
      lines: parsedLines,
    );
  }

  static SalesOrder? fromCreateResponse(dynamic response) {
    if (response is! Map) return null;

    var payload = Map<String, dynamic>.from(response);
    for (var depth = 0; depth < 3; depth++) {
      final nested =
          payload['data'] ?? payload['salesOrder'] ?? payload['order'];
      if (nested is! Map) break;
      payload = Map<String, dynamic>.from(nested);
    }

    final order = SalesOrder.fromJson(payload);
    if (order.id.isEmpty &&
        order.soNumber.isEmpty &&
        order.sourcePoId.isEmpty) {
      return null;
    }
    return order;
  }

  double get totalAmount => lines.fold(
      0,
      (sum, line) =>
          sum + (line.saleAmount != 0 ? line.saleAmount : line.amount));

  Map<String, dynamic> toCreateRequestJson() => <String, dynamic>{
        'soNumber': soNumber,
        'date': date,
        if (customerId.isNotEmpty) 'customerId': customerId,
        if (branchId.isNotEmpty) 'branchId': branchId,
        if (remarks.isNotEmpty) 'remarks': remarks,
        'status': status,
        'mode': mode,
        if (sourcePoId.isNotEmpty) 'sourcePoId': sourcePoId,
        if (poNumber.isNotEmpty) 'poNumber': poNumber,
        'lines': lines.map((line) => line.toJson()).toList(),
      };

  static String _string(dynamic value) => value?.toString().trim() ?? '';
}
