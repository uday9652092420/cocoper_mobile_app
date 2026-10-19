import 'package:cocoper_mobile/app/controllers/statements_report_controller.dart';
import 'package:cocoper_mobile/app/models/statements_report.dart';
import 'package:cocoper_mobile/app/repositories/statements_report_repository.dart';
import 'package:cocoper_mobile/app/views/reportsstatements/statements_report_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _StatementsReportRepository extends StatementsReportRepository {
  @override
  Future<StatementsReportData> load(StatementsReportType type) async {
    return const StatementsReportData(
      records: [
        StatementsReportRecord(
          id: 'sale-1',
          date: null,
          reference: 'DS-1',
          partyId: 'customer-1',
          partyName: 'Customer One',
          branchId: 'branch-1',
          branchName: 'Branch One',
          branchIds: ['branch-1'],
          partyType: 'Local',
          transactionType: 'Sale',
          description: 'Direct sale',
          amount: 250,
          debit: 250,
          credit: 0,
          status: 'Approved',
        ),
      ],
      parties: [(id: 'customer-1', name: 'Customer One')],
      branches: [(id: 'branch-1', name: 'Branch One')],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('sales report exposes responsive filters and sort sheet',
      (tester) async {
    const type = StatementsReportType.salesRegister;
    Get.put(
      StatementsReportController(
        type: type,
        repository: _StatementsReportRepository(),
      ),
      tag: type.name,
    );

    await tester.pumpWidget(
      const GetMaterialApp(home: StatementsReportView(type: type)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filter reports'));
    await tester.pumpAndSettle();
    expect(find.text('Filter reports'), findsOneWidget);
    expect(find.text('All Customers'), findsOneWidget);
    expect(find.text('All Types'), findsOneWidget);
    expect(find.text('All Branches'), findsOneWidget);
    expect(find.text('From Date'), findsOneWidget);
    expect(find.text('To Date'), findsOneWidget);
    expect(find.text('Apply Filters'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sort reports'));
    await tester.pumpAndSettle();

    expect(find.text('Sort records'), findsOneWidget);
    expect(find.text('Ascending'), findsOneWidget);
    expect(find.text('Descending'), findsOneWidget);
    expect(find.text('Invoice Date'), findsOneWidget);
    expect(find.text('Invoice Number'), findsOneWidget);
    expect(find.text('Customer Name'), findsOneWidget);
    expect(find.text('Transaction Type'), findsOneWidget);
    expect(find.text('Branch'), findsOneWidget);
    expect(find.text('Amount'), findsNWidgets(2));
    expect(find.text('Reset Sorting'), findsOneWidget);
  });
}
