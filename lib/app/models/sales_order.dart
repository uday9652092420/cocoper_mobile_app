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
              .whereType<Map<String, dynamic>>()
              .map(SalesOrderLine.fromJson)
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
      customerId: _string(json['customerId'] ?? json['customer_id']),
      customerName: _string(
        json['customerName'] ??
            json['customer_name'] ??
            customer['name'] ??
            customer['customer_name'],
      ),
      remarks: _string(json['remarks']),
      status: _string(json['status']),
      mode: _string(json['mode']),
      sourcePoId: _string(json['sourcePoId'] ?? json['source_po_id']),
      poNumber: _string(json['poNumber'] ?? json['po_number']),
      lines: parsedLines,
    );
  }

  double get totalAmount =>
      lines.fold(0, (sum, line) => sum + (line.saleAmount != 0 ? line.saleAmount : line.amount));

  static String _string(dynamic value) => value?.toString().trim() ?? '';
}
