import 'package:cocoper_mobile/app/controllers/statements_report_controller.dart';
import 'package:cocoper_mobile/app/models/statements_report.dart';
import 'package:cocoper_mobile/app/repositories/statements_report_repository.dart';
import 'package:cocoper_mobile/app/views/reportsstatements/statements_report_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _CustomerStatementRepository extends StatementsReportRepository {
  @override
  Future<StatementsReportData> load(StatementsReportType type) async {
    return StatementsReportData(
      records: [
        _record(
          id: 'sale-1',
          reference: 'GSO-01',
          date: DateTime(2026, 10, 26),
          debit: 735155.34,
          credit: 0,
          transactionType: 'Sale',
        ),
      ],
      parties: const [(id: 'customer-1', name: 'Customer One')],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets(
    'customer statement uses a Sales and Receipt table with reconciled totals',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const type = StatementsReportType.customerStatement;
      final controller = StatementsReportController(
        type: type,
        repository: _CustomerStatementRepository(),
      );
      Get.put(controller, tag: type.name);
      await controller.load();
      controller.selectParty('customer-1');
      expect(controller.applyFilters(), isTrue);

      await tester.pumpWidget(
        const GetMaterialApp(home: StatementsReportView(type: type)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Opening Balance'), findsOneWidget);
      expect(find.text('Total Sales'), findsOneWidget);
      expect(find.text('Total Receipts'), findsOneWidget);
      expect(find.text('Closing Balance'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Voucher'), findsOneWidget);
      expect(find.text('Sales'), findsWidgets);
      expect(find.text('Receipt'), findsWidgets);
      expect(find.text('Running Balance'), findsOneWidget);
      expect(find.text('GSO-01'), findsOneWidget);
      expect(find.text('26 Oct 2026'), findsOneWidget);
      expect(find.text('₹7,35,155.34'), findsNWidgets(6));
      expect(find.text('₹0.00'), findsNWidgets(3));
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('Purchase'), findsNothing);
      expect(find.text('Payment'), findsNothing);

      final table = tester.widget<Table>(find.byType(Table).last);
      expect(table.children, hasLength(3));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
        findsOneWidget,
      );

      tester.view.physicalSize = const Size(320, 720);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Running Balance'), findsOneWidget);
    },
  );
}

StatementsReportRecord _record({
  required String id,
  required String reference,
  required DateTime date,
  required double debit,
  required double credit,
  required String transactionType,
}) =>
    StatementsReportRecord(
      id: id,
      date: date,
      reference: reference,
      partyId: 'customer-1',
      partyName: 'Customer One',
      branchId: '',
      branchName: '',
      description: transactionType,
      amount: debit + credit,
      debit: debit,
      credit: credit,
      status: 'Approved',
      transactionType: transactionType,
    );
