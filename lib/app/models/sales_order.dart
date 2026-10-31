import 'sales_order_line.dart';

/// A Sales Order as returned by the backend.
///
/// The list endpoint (GET /sales-orders) returns a raw array of these
/// objects, including their lines.
class SalesOrder {
  final String id;
  final String soNumber;
  final String date;
  final String organizationId;
  final String customerId;
  final String customerName;
  final String branchId;
  final String remarks;
  final String status;
  final String mode;
  final String sourcePoId;
  final String poNumber;
  final double? savedTotalAmount;
  final List<SalesOrderLine> lines;

  const SalesOrder({
    this.id = '',
    this.soNumber = '',
    this.date = '',
    this.organizationId = '',
    this.customerId = '',
    this.customerName = '',
    this.branchId = '',
    this.remarks = '',
    this.status = '',
    this.mode = '',
    this.sourcePoId = '',
    this.poNumber = '',
    this.savedTotalAmount,
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
      organizationId: _string(
        json['organizationId'] ?? json['organization_id'],
      ),
      customerId: _string(
        json['customerId'] ?? json['customer_id'] ?? customer['id'],
      ),
      customerName: _string(
        json['customerName'] ??
            json['customer_name'] ??
            customer['name'] ??
            customer['customer_name'],
      ),
      branchId: _string(
        json['branchId'] ?? json['branch_id'] ?? _asMap(json['branch'])?['id'],
      ),
      remarks: _string(json['remarks']),
      status: _string(json['status']),
      mode: _string(json['mode']),
      sourcePoId: _string(
        json['sourcePOId'] ?? json['sourcePoId'] ?? json['source_po_id'],
      ),
      poNumber: _string(json['poNumber'] ?? json['po_number']),
      savedTotalAmount: _doubleOrNull(
        json['totalAmount'] ?? json['total_amount'],
      ),
      lines: parsedLines,
    );
  }

  static SalesOrder? fromApiResponse(dynamic response) {
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

  static SalesOrder? fromCreateResponse(dynamic response) =>
      fromApiResponse(response);

  double get lineTotalAmount =>
      lines.fold(0, (sum, line) => sum + line.effectiveSaleAmount);

  double get totalAmount => savedTotalAmount ?? lineTotalAmount;

  Map<String, dynamic> toCreateRequestJson() => <String, dynamic>{
        'soNumber': soNumber,
        'date': date,
        if (customerId.isNotEmpty) 'customerId': customerId,
        if (branchId.isNotEmpty) 'branchId': branchId,
        if (remarks.isNotEmpty) 'remarks': remarks,
        'status': status,
        'mode': mode,
        if (sourcePoId.isNotEmpty) 'sourcePOId': sourcePoId,
        if (poNumber.isNotEmpty) 'poNumber': poNumber,
        'totalAmount': lineTotalAmount,
        'lines': lines.map((line) => line.toJson()).toList(),
      };

  Map<String, dynamic> toUpdateRequestJson() => <String, dynamic>{
        'soNumber': soNumber,
        if (organizationId.isNotEmpty) 'organizationId': organizationId,
        'date': date,
        'customerId': customerId,
        'remarks': remarks,
        'mode': mode,
        if (sourcePoId.isNotEmpty) 'sourcePOId': sourcePoId,
        if (poNumber.isNotEmpty) 'poNumber': poNumber,
        'totalAmount': lineTotalAmount,
        'lines': lines.map((line) => line.toJson()).toList(),
      };

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static double? _doubleOrNull(dynamic value) {
    if (value is num) {
      final parsed = value.toDouble();
      return parsed.isFinite ? parsed : null;
    }
    if (value == null) return null;
    final parsed = double.tryParse(value.toString());
    return parsed != null && parsed.isFinite ? parsed : null;
  }
}
