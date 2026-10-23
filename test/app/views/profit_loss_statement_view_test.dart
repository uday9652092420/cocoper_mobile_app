import 'package:cocoper_mobile/app/controllers/profit_loss_controller.dart';
import 'package:cocoper_mobile/app/models/profit_loss_statement.dart';
import 'package:cocoper_mobile/app/services/profit_loss_service.dart';
import 'package:cocoper_mobile/app/views/reportsstatements/profit_loss_statement_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedProfitLossService extends ProfitLossService {
  _FixedProfitLossService(this.statement);

  final ProfitLossStatement? statement;
  Object? failure;

  @override
  Future<ProfitLossStatement> load({
    required DateTime fromDate,
    required DateTime toDate,
    String? organizationId,
  }) async {
    if (failure != null) throw failure!;
    return statement!;
  }
}

const _statement = ProfitLossStatement(
  openingUnits: 3,
  openingAmount: 300,
  purchaseUnits: 4,
  purchaseAmount: 100,
  salesUnits: 10,
  salesAmount: 500,
  closingUnits: 2,
  closingAmount: 250,
  expenses: 50,
  otherIncome: 20,
  costOfGoodsSold: 150,
  grossProfit: 350,
  netProfit: 320,
  hasData: true,
);

Future<void> _pumpView(
  WidgetTester tester,
  ProfitLossController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ProfitLossStatementView(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows loading while the statement is being fetched', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    final controller = ProfitLossController(
      service: _FixedProfitLossService(_statement),
      now: DateTime(2025, 5, 31),
    );
    final load = controller.load();

    await tester.pumpWidget(
      MaterialApp(home: ProfitLossStatementView(controller: controller)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await load;
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('renders the statement sections and all nine calculation rows',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    final controller = ProfitLossController(
      service: _FixedProfitLossService(_statement),
      now: DateTime(2025, 5, 31),
    );
    await controller.load();
    await _pumpView(tester, controller);

    expect(find.text('Opening Stock'), findsWidgets);
    expect(find.text('Purchases (In Range)'), findsOneWidget);
    expect(find.text('Sales (In Range)'), findsOneWidget);
    expect(find.text('Closing Stock'), findsWidgets);
    expect(find.text('Total Expenses (In Range)'), findsOneWidget);
    expect(find.text('Total Other Income (In Range)'), findsOneWidget);

    final rows = [
      'Total Sales',
      'Opening Stock',
      'Add: Purchases',
      'Less: Closing Stock',
      'Cost of Goods Sold (COGS)',
      'Gross Profit',
      'Less: Expenses',
      'Add: Other Income',
      'Net Profit',
    ];
    for (final row in rows) {
      final finder = find.text(row);
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(finder, findsOneWidget);
    }

    expect(find.text('₹500.00'), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('shows a clear no-data state', (tester) async {
    final controller = ProfitLossController(
      service: _FixedProfitLossService(
        const ProfitLossStatement(
          openingUnits: 0,
          openingAmount: 0,
          purchaseUnits: 0,
          purchaseAmount: 0,
          salesUnits: 0,
          salesAmount: 0,
          closingUnits: 0,
          closingAmount: 0,
          expenses: 0,
          otherIncome: 0,
          costOfGoodsSold: 0,
          grossProfit: 0,
          netProfit: 0,
          hasData: false,
        ),
      ),
      now: DateTime(2025, 5, 31),
    );
    await controller.load();
    await _pumpView(tester, controller);

    expect(find.text('No financial records'), findsOneWidget);
    expect(
      find.text('No financial records are available for the selected period.'),
      findsOneWidget,
    );
  });

  testWidgets('shows an error and Retry action', (tester) async {
    final service = _FixedProfitLossService(_statement)
      ..failure = Exception('Report permission is required.');
    final controller = ProfitLossController(
      service: service,
      now: DateTime(2025, 5, 31),
    );
    await controller.load();
    await _pumpView(tester, controller);

    expect(find.text('Unable to load statement'), findsOneWidget);
    expect(find.text('Report permission is required.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
