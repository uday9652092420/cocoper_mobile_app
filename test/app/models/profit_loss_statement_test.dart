import 'package:cocoper_mobile/app/models/profit_loss_statement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches the COPPER Web P&L calculation for the selected period', () {
    final statement = ProfitLossStatement.fromRecords(
      sales: [
        {
          'organizationId': 'org-1',
          'invoiceDate': '2025-05-01',
          'invoiceTotal': '500',
          'lines': [
            {'actualQuantity': 10, 'quantity': 12},
          ],
        },
        {
          'organizationId': 'org-1',
          'invoiceDate': '2025-06-01',
          'invoiceTotal': 999,
        },
        {
          'organizationId': 'org-2',
          'invoiceDate': '2025-05-10',
          'invoiceTotal': 888,
        },
      ],
      purchases: [
        {
          'organizationId': 'org-1',
          'invoiceDate': '15/05/2025',
          'grandTotal': '100',
          'lines': [
            {'quantityTons': 4},
          ],
        },
        {
          'organizationId': 'org-1',
          'invoiceDate': '2025-04-30',
          'grandTotal': 500,
        },
      ],
      cashBankEntries: [
        {
          'organizationId': 'org-1',
          'date': '2025-05-10',
          'transactionType': 'Expenses',
          'approved': true,
          'amount': '50',
        },
        {
          'organizationId': 'org-1',
          'date': '2025-05-11',
          'transactionType': 'Expenses',
          'approved': false,
          'amount': 500,
        },
        {
          'organizationId': 'org-1',
          'date': '2025-05-12',
          'transactionType': 'Income',
          'approved': true,
          'amount': 20,
        },
      ],
      stockSnapshot: {
        'openingUnits': 3,
        'openingAmount': 300,
        'closingUnits': 2,
        'closingAmount': 250,
      },
      fromDate: DateTime(2025, 5, 1),
      toDate: DateTime(2025, 5, 31),
      organizationId: 'org-1',
    );

    expect(statement.salesAmount, 500);
    expect(statement.salesUnits, 10);
    expect(statement.purchaseAmount, 100);
    expect(statement.purchaseUnits, 4);
    expect(statement.openingRate, 100);
    expect(statement.closingRate, 125);
    expect(statement.expenses, 50);
    expect(statement.otherIncome, 20);
    expect(statement.costOfGoodsSold, 150);
    expect(statement.grossProfit, 350);
    expect(statement.netProfit, 320);
    expect(statement.hasData, isTrue);
    expect(statement.lines, hasLength(9));
  });

  test('treats null financial values as zero and protects zero-unit rates', () {
    final statement = ProfitLossStatement.fromRecords(
      sales: [
        {
          'invoiceDate': '2025-05-01',
          'invoiceTotal': null,
          'lines': null,
        },
      ],
      purchases: [
        {'invoiceDate': '2025-05-01', 'grandTotal': null},
      ],
      cashBankEntries: [
        {
          'date': '2025-05-01',
          'transactionType': 'Expenses',
          'approved': true,
          'amount': null,
        },
      ],
      stockSnapshot: {
        'openingUnits': null,
        'openingAmount': null,
        'closingUnits': null,
        'closingAmount': null,
      },
      fromDate: DateTime(2025, 5, 1),
      toDate: DateTime(2025, 5, 1),
    );

    expect(statement.openingUnits, 0);
    expect(statement.openingRate, 0);
    expect(statement.closingRate, 0);
    expect(statement.salesAmount, 0);
    expect(statement.purchaseAmount, 0);
    expect(statement.expenses, 0);
    expect(statement.hasData, isTrue);
  });

  test('shows negative statement values and formats INR amounts', () {
    final statement = ProfitLossStatement.fromRecords(
      sales: [
        {'invoiceDate': '2025-05-01', 'invoiceTotal': 10},
      ],
      purchases: const [],
      cashBankEntries: [
        {
          'date': '2025-05-01',
          'transactionType': 'Expenses',
          'approved': true,
          'amount': 30,
        },
      ],
      stockSnapshot: {
        'openingUnits': 0,
        'openingAmount': 0,
        'closingUnits': 0,
        'closingAmount': 0,
      },
      fromDate: DateTime(2025, 5, 1),
      toDate: DateTime(2025, 5, 31),
    );

    expect(statement.netProfit, -20);
    expect(statement.lines.last.label, 'Net Loss');
    expect(statement.lines.last.amount, -20);
    expect(formatProfitLossCurrency(1234.5), '₹1,234.50');
    expect(formatProfitLossStatementAmount(-1234.5), '(₹1,234.50)');
  });

  test('reports no data when all sources and stock snapshot are empty', () {
    final statement = ProfitLossStatement.fromRecords(
      sales: const [],
      purchases: const [],
      cashBankEntries: const [],
      stockSnapshot: const {},
      fromDate: DateTime(2025, 5, 1),
      toDate: DateTime(2025, 5, 31),
    );

    expect(statement.hasData, isFalse);
  });
}
