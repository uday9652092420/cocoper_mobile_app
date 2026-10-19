import '../models/statements_report.dart';
import '../services/endpoints.dart';
import '../services/statements_report_service.dart';

class StatementsReportData {
  const StatementsReportData({
    required this.records,
    this.parties = const [],
    this.branches = const [],
  });

  final List<StatementsReportRecord> records;
  final List<({String id, String name})> parties;
  final List<({String id, String name})> branches;
}

class StatementsReportRepository {
  StatementsReportRepository({StatementsReportService? service})
      : _service = service ?? StatementsReportService();

  final StatementsReportService _service;

  Future<StatementsReportData> load(StatementsReportType type) async {
    final sources = switch (type) {
      StatementsReportType.purchaseRegister => await _fetch([
          EndPoints.purchaseInvoices,
          EndPoints.suppliers,
          EndPoints.branches,
        ]),
      StatementsReportType.salesRegister => await _fetch([
          EndPoints.directSales,
          EndPoints.customers,
          EndPoints.branches,
        ]),
      StatementsReportType.supplierStatement => await _fetch([
          EndPoints.purchaseInvoices,
          EndPoints.supplierPayments,
          EndPoints.suppliers,
        ]),
      StatementsReportType.customerStatement => await _fetch([
          EndPoints.directSales,
          EndPoints.customerReceipts,
          EndPoints.customers,
        ]),
      StatementsReportType.pendingDispatch => await _fetch([
          EndPoints.loadingDispatches,
          EndPoints.customers,
          EndPoints.branches,
        ]),
    };

    final lookupIndex = switch (type) {
      StatementsReportType.purchaseRegister ||
      StatementsReportType.salesRegister ||
      StatementsReportType.pendingDispatch =>
        1,
      StatementsReportType.supplierStatement ||
      StatementsReportType.customerStatement =>
        2,
    };
    final partyRows = _rows(sources[lookupIndex]);
    final partyOptions = partyRows
        .map((row) => (
              id: _text(_first(row, ['id', 'customerId', 'customer_id'])) ?? '',
              name: _text(_first(row, [
                    'name',
                    'supplier_name',
                    'supplierName',
                    'customer_name',
                    'customerName',
                  ])) ??
                  '',
            ))
        .where((option) => option.id.isNotEmpty && option.name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final branchIndex = switch (type) {
      StatementsReportType.purchaseRegister ||
      StatementsReportType.salesRegister ||
      StatementsReportType.pendingDispatch =>
        2,
      _ => -1,
    };
    final branchOptions = branchIndex < 0
        ? <({String id, String name})>[]
        : _rows(sources[branchIndex])
            .map((row) => (
                  id: _text(_first(row, ['id', 'branchId', 'branch_id'])) ?? '',
                  name: _text(_first(row, [
                        'name',
                        'branch_name',
                        'branchName',
                        'label',
                      ])) ??
                      '',
                ))
            .where((option) => option.id.isNotEmpty && option.name.isNotEmpty)
            .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return StatementsReportData(
      records: _buildRecords(type, sources, partyOptions, branchOptions),
      parties: partyOptions,
      branches: branchOptions,
    );
  }

  Future<List<dynamic>> _fetch(List<String> endpoints) async {
    return Future.wait(endpoints.map(_getList));
  }

  Future<List<dynamic>> _getList(String endpoint) async {
    return _service.fetchList(endpoint);
  }

  List<StatementsReportRecord> _buildRecords(
    StatementsReportType type,
    List<dynamic> sources,
    List<({String id, String name})> parties,
    List<({String id, String name})> branches,
  ) {
    final partyNames = {for (final party in parties) party.id: party.name};
    final branchNames = {for (final branch in branches) branch.id: branch.name};

    switch (type) {
      case StatementsReportType.purchaseRegister:
      case StatementsReportType.supplierStatement:
        final purchases = _rows(sources[0]);
        final purchaseRecords = purchases.map((row) {
          final supplierId =
              _text(_first(row, ['supplierId', 'supplier_id'])) ?? '';
          final total = _number(_first(row, ['grandTotal', 'grand_total']));
          return _record(
            row,
            reference: _text(_first(row, ['invoiceNo', 'invoice_no'])),
            date: _date(_first(row, ['invoiceDate', 'invoice_date'])),
            partyId: supplierId,
            partyName: partyNames[supplierId] ?? 'Supplier',
            branchId: _text(_first(row, ['branchId', 'branch_id'])),
            branchNames: branchNames,
            description: 'Purchase invoice',
            amount: total,
            debit: total,
            status: _text(row['status']),
            transactionType: 'Purchase',
          );
        });
        if (type == StatementsReportType.purchaseRegister) {
          return purchaseRecords.toList();
        }
        final payments = _rows(sources[1]).map((row) {
          final supplierId =
              _text(_first(row, ['supplierId', 'supplier_id'])) ?? '';
          final amount = _number(row['amount']);
          return _record(
            row,
            reference: _text(_first(row, ['paymentNumber', 'payment_number'])),
            date: _date(_first(row, ['date', 'paymentDate', 'payment_date'])),
            partyId: supplierId,
            partyName: _text(_first(row, [
                  'supplierName',
                  'supplier_name',
                ])) ??
                partyNames[supplierId] ??
                'Supplier',
            description: _text(_first(row, ['remarks', 'invoiceMode'])) ??
                'Supplier payment',
            amount: amount,
            credit: amount,
            status: _status(row['approved']),
            transactionType: 'Payment',
          );
        });
        return [...purchaseRecords, ...payments];

      case StatementsReportType.salesRegister:
      case StatementsReportType.customerStatement:
        final sales = _rows(sources[0]).map((row) {
          final customerId =
              _text(_first(row, ['customerId', 'customer_id'])) ?? '';
          final total = _number(_first(row, ['invoiceTotal', 'total_amount']));
          return _record(
            row,
            reference: _text(_first(row, ['directSaleNo', 'invoice_no'])),
            date: _date(_first(row, ['invoiceDate', 'saleDate', 'sale_date'])),
            partyId: customerId,
            partyName: partyNames[customerId] ?? 'Customer',
            branchId: _text(_first(row, ['branchId', 'branch_id'])),
            branchNames: branchNames,
            description: _text(row['mode']) ?? 'Direct sale',
            amount: total,
            debit: total,
            status: _status(row['approved']),
            partyType: _text(row['customerType']) ?? '',
            transactionType: 'Sale',
          );
        });
        if (type == StatementsReportType.salesRegister) {
          return sales.toList();
        }
        final receipts = _rows(sources[1]).map((row) {
          final customerId =
              _text(_first(row, ['customer_id', 'customerId'])) ?? '';
          final amount = _number(row['amount']);
          final invoiceNo = _text(_first(row, ['invoice_no', 'invoiceNo']));
          return _record(
            row,
            reference: _text(_first(row, ['receipt_no', 'receiptNo'])),
            date: _date(_first(row, ['receipt_date', 'receiptDate'])),
            partyId: customerId,
            partyName: _text(_first(row, [
                  'customer_name',
                  'customerName',
                ])) ??
                partyNames[customerId] ??
                'Customer',
            description: invoiceNo == null
                ? 'Customer receipt'
                : 'Receipt for $invoiceNo',
            amount: amount,
            credit: amount,
            status: _status(row['approved']),
            transactionType: 'Receipt',
          );
        });
        return [...sales, ...receipts];

      case StatementsReportType.pendingDispatch:
        return _rows(sources[0]).map((row) {
          final customerId =
              _text(_first(row, ['customerId', 'customer_id'])) ?? '';
          final lines = _rows(row['lines']);
          final quantity = lines.fold<double>(
            0,
            (sum, line) => sum + _number(line['quantity']),
          );
          final loadedQuantity = lines.fold<double>(
            0,
            (sum, line) => sum + _number(line['loadedQuantity']),
          );
          final pendingQuantity = lines.fold<double>(
            0,
            (sum, line) => sum + _number(line['pendingQuantity']),
          );
          final branchIds = lines
              .map((line) => _text(_first(line, ['branchId', 'branch_id'])))
              .whereType<String>()
              .toSet();
          final branch = branchIds
              .map((id) => branchNames[id])
              .whereType<String>()
              .join(', ');
          final branchId = branchIds.isEmpty ? '' : branchIds.first;
          final date = _date(_first(row, ['dispatchDate', 'dispatch_date']));
          return StatementsReportRecord(
            id: _text(row['id']) ?? '',
            date: date,
            reference:
                _text(_first(row, ['dispatchNumber', 'dispatch_number'])) ??
                    _text(row['id']) ??
                    '',
            partyId: customerId,
            partyName: partyNames[customerId] ?? 'Customer',
            branchId: branchId,
            branchName: branch,
            branchIds: branchIds.toList(),
            description: '${lines.length} line(s)',
            amount: 0,
            debit: 0,
            credit: 0,
            status: _text(row['dispatchStatus']) ?? 'Unknown',
            totalQuantity: quantity,
            loadedQuantity: loadedQuantity,
            pendingQuantity: pendingQuantity,
            driverMobile: _text(row['driverMobile']) ?? '',
            lorryNumber: _text(row['lorryNumber']) ?? '',
            driverName: _text(row['driverName']) ?? '',
            transactionType: 'Dispatch',
          );
        }).toList();
    }
  }

  StatementsReportRecord _record(
    Map<String, dynamic> row, {
    required String? reference,
    required DateTime? date,
    required String? partyId,
    required String? partyName,
    String? branchId,
    Map<String, String>? branchNames,
    List<String> branchIds = const [],
    required String description,
    required double amount,
    double debit = 0,
    double credit = 0,
    required String? status,
    String partyType = '',
    String transactionType = '',
  }) {
    return StatementsReportRecord(
      id: _text(row['id']) ?? reference ?? '',
      date: date,
      reference: reference ?? '',
      partyId: partyId ?? '',
      partyName: partyName ?? '',
      branchId: branchId ?? '',
      branchName: branchNames?[branchId ?? ''] ?? '',
      branchIds:
          branchIds.isEmpty ? [if (branchId != null) branchId] : branchIds,
      description: description,
      amount: amount,
      debit: debit,
      credit: credit,
      status: status ?? '',
      balance: 0,
      partyType: partyType,
      transactionType: transactionType,
    );
  }

  static List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<dynamic, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  static dynamic _first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return null;
  }

  static String? _text(dynamic value) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? null : result;
  }

  static double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value;
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;
    final parts = text.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime.tryParse(
          '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}-'
          '${day.toString().padLeft(2, '0')}',
        );
      }
    }
    return null;
  }

  static String? _status(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Approved' : 'Pending';
    return value.toString();
  }
}
