import 'package:intl/intl.dart';

class ProfitLossStatement {
  const ProfitLossStatement({
    required this.openingUnits,
    required this.openingAmount,
    required this.purchaseUnits,
    required this.purchaseAmount,
    required this.salesUnits,
    required this.salesAmount,
    required this.closingUnits,
    required this.closingAmount,
    required this.expenses,
    required this.otherIncome,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.netProfit,
    required this.hasData,
  });

  final double openingUnits;
  final double openingAmount;
  final double purchaseUnits;
  final double purchaseAmount;
  final double salesUnits;
  final double salesAmount;
  final double closingUnits;
  final double closingAmount;
  final double expenses;
  final double otherIncome;
  final double costOfGoodsSold;
  final double grossProfit;
  final double netProfit;
  final bool hasData;

  double get openingRate =>
      openingUnits == 0 ? 0 : openingAmount / openingUnits;

  double get closingRate =>
      closingUnits == 0 ? 0 : closingAmount / closingUnits;

  List<ProfitLossStatementLine> get lines => [
        ProfitLossStatementLine(label: 'Total Sales', amount: salesAmount),
        ProfitLossStatementLine(
          label: 'Opening Stock',
          amount: openingAmount,
        ),
        ProfitLossStatementLine(
          label: 'Add: Purchases',
          amount: purchaseAmount,
        ),
        ProfitLossStatementLine(
          label: 'Less: Closing Stock',
          amount: -closingAmount.abs(),
        ),
        ProfitLossStatementLine(
          label: 'Cost of Goods Sold (COGS)',
          amount: costOfGoodsSold,
          emphasized: true,
        ),
        ProfitLossStatementLine(
          label: 'Gross Profit',
          amount: grossProfit,
          emphasized: true,
        ),
        ProfitLossStatementLine(
          label: 'Less: Expenses',
          amount: -expenses.abs(),
        ),
        ProfitLossStatementLine(
          label: 'Add: Other Income',
          amount: otherIncome,
        ),
        ProfitLossStatementLine(
          label: netProfit < 0 ? 'Net Loss' : 'Net Profit',
          amount: netProfit,
          emphasized: true,
        ),
      ];

  factory ProfitLossStatement.fromRecords({
    required List<dynamic> sales,
    required List<dynamic> purchases,
    required List<dynamic> cashBankEntries,
    required Map<String, dynamic> stockSnapshot,
    required DateTime fromDate,
    required DateTime toDate,
    String? organizationId,
  }) {
    final from = _isoDay(fromDate);
    final to = _isoDay(toDate);
    final scopedSales = _inRangeForOrganization(
      sales,
      dateKeys: const ['invoiceDate', 'invoice_date'],
      from: from,
      to: to,
      organizationId: organizationId,
    );
    final scopedPurchases = _inRangeForOrganization(
      purchases,
      dateKeys: const ['invoiceDate', 'invoice_date'],
      from: from,
      to: to,
      organizationId: organizationId,
    );
    final scopedEntries = _inRangeForOrganization(
      cashBankEntries,
      dateKeys: const ['date', 'expenseDate', 'expense_date'],
      from: from,
      to: to,
      organizationId: organizationId,
    ).where((row) => row['approved'] == true).toList();

    final openingUnits = _number(stockSnapshot['openingUnits']);
    final openingAmount = _number(stockSnapshot['openingAmount']);
    final closingUnits = _number(stockSnapshot['closingUnits']);
    final closingAmount = _number(stockSnapshot['closingAmount']);
    final salesAmount = scopedSales.fold<double>(
      0,
      (sum, row) => sum + _number(row['invoiceTotal']),
    );
    final purchaseAmount = scopedPurchases.fold<double>(
      0,
      (sum, row) => sum + _number(row['grandTotal']),
    );
    final salesUnits = scopedSales.fold<double>(
      0,
      (sum, row) => sum + _lineUnits(row['lines']),
    );
    final purchaseUnits = scopedPurchases.fold<double>(
      0,
      (sum, row) => sum + _lineUnits(row['lines']),
    );
    final otherIncome = scopedEntries
        .where((row) => row['transactionType'] == 'Income')
        .fold<double>(0, (sum, row) => sum + _number(row['amount']));
    final expenses = scopedEntries
        .where((row) => row['transactionType'] == 'Expenses')
        .fold<double>(0, (sum, row) => sum + _number(row['amount']));
    final costOfGoodsSold =
        openingAmount + purchaseAmount - closingAmount;
    final grossProfit = salesAmount - costOfGoodsSold;
    final netProfit = grossProfit + otherIncome - expenses;
    final hasData = scopedSales.isNotEmpty ||
        scopedPurchases.isNotEmpty ||
        scopedEntries.isNotEmpty ||
        openingUnits != 0 ||
        openingAmount != 0 ||
        closingUnits != 0 ||
        closingAmount != 0;

    return ProfitLossStatement(
      openingUnits: openingUnits,
      openingAmount: openingAmount,
      purchaseUnits: purchaseUnits,
      purchaseAmount: purchaseAmount,
      salesUnits: salesUnits,
      salesAmount: salesAmount,
      closingUnits: closingUnits,
      closingAmount: closingAmount,
      expenses: expenses,
      otherIncome: otherIncome,
      costOfGoodsSold: costOfGoodsSold,
      grossProfit: grossProfit,
      netProfit: netProfit,
      hasData: hasData,
    );
  }
}

class ProfitLossStatementLine {
  const ProfitLossStatementLine({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final bool emphasized;
}

String formatProfitLossCurrency(num value) => NumberFormat.currency(
      locale: 'en_IN',
      name: 'INR',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);

String formatProfitLossStatementAmount(num value) {
  final amount = value.toDouble();
  return amount < 0
      ? '(${formatProfitLossCurrency(amount.abs())})'
      : formatProfitLossCurrency(amount);
}

String formatProfitLossQuantity(num value) =>
    NumberFormat('#,##0.###', 'en_IN').format(value);

List<Map<String, dynamic>> _inRangeForOrganization(
  List<dynamic> values, {
  required List<String> dateKeys,
  required String from,
  required String to,
  required String? organizationId,
}) {
  return values
      .whereType<Map<dynamic, dynamic>>()
      .map(Map<String, dynamic>.from)
      .where((row) {
        if (organizationId != null && organizationId.isNotEmpty) {
          final rowOrganizationId =
              row['organizationId'] ?? row['organization_id'];
          if (rowOrganizationId?.toString() != organizationId) return false;
        }
        final date = _isoDate(_first(row, dateKeys));
        return date != null && date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
      })
      .toList();
}

double _lineUnits(dynamic lines) {
  if (lines is! List) return 0;
  return lines.whereType<Map<dynamic, dynamic>>().fold<double>(0, (sum, line) {
    final quantity = line['actualQuantity'] ??
        line['quantityTons'] ??
        line['quantity'] ??
        0;
    return sum + _number(quantity);
  });
}

dynamic _first(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value != null) return value;
  }
  return null;
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String? _isoDate(dynamic value) {
  if (value is DateTime) return _isoDay(value);
  final text = value?.toString().trim() ?? '';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return text;
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
  if (match == null) return null;
  return '${match.group(3)}-${match.group(2)}-${match.group(1)}';
}

String _isoDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
