import 'package:cocoper_mobile/app/controllers/statements_report_controller.dart';
import 'package:cocoper_mobile/app/models/statements_report.dart';
import 'package:cocoper_mobile/app/repositories/statements_report_repository.dart';
import 'package:cocoper_mobile/app/views/reportsstatements/statements_report_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _SupplierStatementRepository extends StatementsReportRepository {
  @override
  Future<StatementsReportData> load(StatementsReportType type) async {
    return StatementsReportData(
      records: [
        _record(
          id: 'purchase',
          reference: 'GPI-01',
          date: DateTime(2026, 10, 26),
          debit: 1617660,
          credit: 0,
          transactionType: 'Purchase',
        ),
        _record(
          id: 'payment-1',
          reference: 'SP-01',
          date: DateTime(2026, 10, 27),
          debit: 0,
          credit: 1000,
          transactionType: 'Payment',
        ),
        _record(
          id: 'payment-2',
          reference: 'SP-02',
          date: DateTime(2026, 10, 27),
          debit: 0,
          credit: 50000,
          transactionType: 'Payment',
        ),
      ],
      parties: const [(id: 'supplier-1', name: 'Supplier One')],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.testMode = true);
  tearDown(() {
    Get.reset();
  });

  testWidgets('supplier statement presents compact table and reconciled totals',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const type = StatementsReportType.supplierStatement;
    final controller = StatementsReportController(
      type: type,
      repository: _SupplierStatementRepository(),
    );
    Get.put(controller, tag: type.name);
    await controller.load();
    controller.selectParty('supplier-1');
    expect(controller.applyFilters(), isTrue);

    await tester.pumpWidget(
      const GetMaterialApp(home: StatementsReportView(type: type)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Opening Balance'), findsOneWidget);
    expect(find.text('Total Purchase'), findsOneWidget);
    expect(find.text('Total Payment'), findsOneWidget);
    expect(find.text('Closing Balance'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Voucher'), findsOneWidget);
    expect(find.text('Purchase'), findsWidgets);
    expect(find.text('Payment'), findsWidgets);
    expect(find.text('Running Balance'), findsOneWidget);
    expect(find.text('GPI-01'), findsOneWidget);
    expect(find.text('SP-01'), findsOneWidget);
    expect(find.text('SP-02'), findsOneWidget);
    expect(find.text('26 Oct 2026'), findsOneWidget);
    expect(find.text('27 Oct 2026'), findsNWidgets(2));
    expect(find.text('₹16,17,660.00'), findsWidgets);
    expect(find.text('₹51,000.00'), findsNWidgets(2));
    expect(find.text('₹15,66,660.00'), findsWidgets);
    expect(find.text('—'), findsNWidgets(3));
    final table = tester.widget<Table>(find.byType(Table));
    expect(table.children, hasLength(5));
    expect(find.text('TOTAL'), findsOneWidget);
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
  });
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
      partyId: 'supplier-1',
      partyName: 'Supplier One',
      branchId: '',
      branchName: '',
      description: transactionType,
      amount: debit + credit,
      debit: debit,
      credit: credit,
      status: '',
      transactionType: transactionType,
    );
