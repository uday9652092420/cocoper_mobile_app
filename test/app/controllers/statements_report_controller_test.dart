import 'package:cocoper_mobile/app/controllers/statements_report_controller.dart';
import 'package:cocoper_mobile/app/models/statements_report.dart';
import 'package:cocoper_mobile/app/repositories/statements_report_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStatementsReportRepository extends StatementsReportRepository {
  @override
  Future<StatementsReportData> load(StatementsReportType type) async {
    return StatementsReportData(
      records: [
        StatementsReportRecord(
          id: 'purchase-1',
          date: DateTime(2025, 1, 1),
          reference: 'PI-1',
          partyId: 'supplier-1',
          partyName: 'Supplier One',
          branchId: '',
          branchName: '',
          description: 'Purchase invoice',
          amount: 100,
          debit: 100,
          credit: 0,
          status: 'Pending',
        ),
        StatementsReportRecord(
          id: 'payment-1',
          date: DateTime(2025, 1, 4),
          reference: 'SP-1',
          partyId: 'supplier-1',
          partyName: 'Supplier One',
          branchId: '',
          branchName: '',
          description: 'Supplier payment',
          amount: 40,
          debit: 0,
          credit: 40,
          status: 'Approved',
        ),
        StatementsReportRecord(
          id: 'purchase-2',
          date: DateTime(2025, 1, 9),
          reference: 'PI-2',
          partyId: 'supplier-1',
          partyName: 'Supplier One',
          branchId: '',
          branchName: '',
          description: 'Purchase invoice',
          amount: 20,
          debit: 20,
          credit: 0,
          status: 'Pending',
        ),
        StatementsReportRecord(
          id: 'purchase-other',
          date: DateTime(2025, 1, 8),
          reference: 'PI-3',
          partyId: 'supplier-2',
          partyName: 'Supplier Two',
          branchId: '',
          branchName: '',
          description: 'Purchase invoice',
          amount: 999,
          debit: 999,
          credit: 0,
          status: 'Pending',
        ),
      ],
      parties: const [
        (id: 'supplier-1', name: 'Supplier One'),
        (id: 'supplier-2', name: 'Supplier Two'),
      ],
    );
  }
}

class _FixedStatementsReportRepository extends StatementsReportRepository {
  _FixedStatementsReportRepository(this.data);

  final StatementsReportData data;
  var loadCount = 0;

  @override
  Future<StatementsReportData> load(StatementsReportType type) async {
    loadCount++;
    return data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('supplier report filters dates and calculates running balances',
      () async {
    final controller = StatementsReportController(
      type: StatementsReportType.supplierStatement,
      repository: _FakeStatementsReportRepository(),
    );
    await controller.load();
    controller.selectParty('supplier-1');
    expect(controller.visibleRecords, isEmpty);
    controller.setDateRange(
      DateTimeRangeValues(
        start: DateTime(2025, 1, 4),
        end: DateTime(2025, 1, 9),
      ),
    );
    controller.setSort(StatementsReportSortField.date, ascending: true);

    expect(controller.visibleRecords.map((record) => record.reference),
        ['SP-1', 'PI-2']);
    expect(controller.openingBalance, 100);
    expect(controller.totalDebit, 20);
    expect(controller.totalCredit, 40);
    expect(controller.closingBalance, 80);
    expect(controller.visibleRecords.map((record) => record.balance), [60, 80]);

    controller.setSearch('PI-2');
    expect(controller.visibleRecords, hasLength(1));
    expect(controller.totalDebit, 20);
    expect(controller.totalCredit, 40);
    expect(controller.closingBalance, 80);
  });

  test('statement remains empty until a party is selected', () async {
    final controller = StatementsReportController(
      type: StatementsReportType.customerStatement,
      repository: _FakeStatementsReportRepository(),
    );
    await controller.load();

    expect(controller.visibleRecords, isEmpty);
    controller.selectParty('supplier-1');
    controller.applyFilters();
    expect(controller.visibleRecords, hasLength(3));
  });

  test('sales filters combine party, type, branch and inclusive dates',
      () async {
    final repository = _FixedStatementsReportRepository(
      StatementsReportData(
        records: [
          _record(
            id: 'sale-1',
            date: DateTime(2025, 2, 1),
            reference: 'DS-1',
            partyId: 'customer-1',
            partyName: 'Customer One',
            branchId: 'branch-1',
            partyType: 'Local',
            amount: 100,
          ),
          _record(
            id: 'sale-2',
            date: DateTime(2025, 2, 28),
            reference: 'DS-2',
            partyId: 'customer-1',
            partyName: 'Customer One',
            branchId: 'branch-1',
            partyType: 'Local',
            amount: 200,
          ),
          _record(
            id: 'sale-3',
            date: DateTime(2025, 2, 14),
            reference: 'DS-3',
            partyId: 'customer-1',
            partyName: 'Customer One',
            branchId: 'branch-2',
            partyType: 'National',
            amount: 300,
          ),
          _record(
            id: 'sale-4',
            date: DateTime(2025, 2, 14),
            reference: 'DS-4',
            partyId: 'customer-2',
            partyName: 'Customer Two',
            branchId: 'branch-1',
            partyType: 'Local',
            amount: 400,
          ),
        ],
        parties: const [
          (id: 'customer-1', name: 'Customer One'),
          (id: 'customer-2', name: 'Customer Two'),
        ],
        branches: const [
          (id: 'branch-1', name: 'Branch One'),
          (id: 'branch-2', name: 'Branch Two'),
        ],
      ),
    );
    final controller = StatementsReportController(
      type: StatementsReportType.salesRegister,
      repository: repository,
    );
    await controller.load();

    controller.selectParty('customer-1');
    controller.selectType('Local');
    controller.selectBranch('branch-1');
    controller.setStartDate(DateTime(2025, 2, 1));
    controller.setEndDate(DateTime(2025, 2, 28));
    expect(controller.visibleRecords, hasLength(4));
    expect(repository.loadCount, 1);

    expect(controller.applyFilters(), isTrue);
    controller.setSort(StatementsReportSortField.date, ascending: true);
    expect(
      controller.visibleRecords.map((record) => record.reference),
      ['DS-1', 'DS-2'],
    );
    expect(controller.totalAmount, 300);
    controller.setSearch('DS-2');
    expect(
        controller.visibleRecords.map((record) => record.reference), ['DS-2']);
    expect(controller.totalAmount, 200);
    expect(repository.loadCount, 1);

    controller.clearFilters();
    expect(controller.visibleRecords, hasLength(4));
    expect(controller.totalAmount, 1000);
  });

  test('dispatch filters combine customer, status and date range', () async {
    final repository = _FixedStatementsReportRepository(
      StatementsReportData(
        records: [
          _dispatchRecord(
            id: 'dispatch-1',
            date: DateTime(2025, 3, 1),
            customerId: 'customer-1',
            status: 'Draft',
          ),
          _dispatchRecord(
            id: 'dispatch-2',
            date: DateTime(2025, 3, 10),
            customerId: 'customer-1',
            status: 'Dispatched',
          ),
          _dispatchRecord(
            id: 'dispatch-3',
            date: DateTime(2025, 3, 8),
            customerId: 'customer-2',
            status: 'Draft',
          ),
        ],
      ),
    );
    final controller = StatementsReportController(
      type: StatementsReportType.pendingDispatch,
      repository: repository,
    );
    await controller.load();
    controller.selectParty('customer-1');
    controller.selectStatus('Draft');
    controller.setStartDate(DateTime(2025, 3, 1));
    controller.setEndDate(DateTime(2025, 3, 10));

    expect(controller.applyFilters(), isTrue);
    expect(
        controller.visibleRecords.map((record) => record.id), ['dispatch-1']);
  });

  test('invalid date order is rejected until dates are corrected', () async {
    final controller = StatementsReportController(
      type: StatementsReportType.purchaseRegister,
      repository: _FixedStatementsReportRepository(
        const StatementsReportData(records: []),
      ),
    );
    await controller.load();
    controller.setStartDate(DateTime(2025, 4, 10));
    controller.setEndDate(DateTime(2025, 4, 1));

    expect(controller.applyFilters(), isFalse);
    expect(controller.startDate.value, isNull);
    expect(controller.filterErrorMessage.value, isNotEmpty);
  });

  test('register sorting supports amount direction and reset', () async {
    final controller = StatementsReportController(
      type: StatementsReportType.purchaseRegister,
      repository: _FixedStatementsReportRepository(
        StatementsReportData(
          records: [
            _record(
              id: 'purchase-1',
              date: DateTime(2025, 1, 1),
              reference: 'PI-1',
              partyId: 'supplier-1',
              partyName: 'Supplier One',
              branchId: 'branch-1',
              partyType: '',
              amount: 100,
            ),
            _record(
              id: 'purchase-2',
              date: DateTime(2025, 1, 2),
              reference: 'PI-2',
              partyId: 'supplier-2',
              partyName: 'Supplier Two',
              branchId: 'branch-2',
              partyType: '',
              amount: 50,
            ),
          ],
        ),
      ),
    );
    await controller.load();
    controller.setSort(StatementsReportSortField.amount, ascending: true);
    expect(
      controller.visibleRecords.map((record) => record.reference),
      ['PI-2', 'PI-1'],
    );

    controller.setSort(StatementsReportSortField.reference, ascending: false);
    expect(
      controller.visibleRecords.map((record) => record.reference),
      ['PI-2', 'PI-1'],
    );

    controller.resetSorting();
    expect(controller.sortField.value, StatementsReportSortField.date);
    expect(controller.sortAscending.value, isFalse);
    expect(
      controller.visibleRecords.map((record) => record.reference),
      ['PI-2', 'PI-1'],
    );
  });

  test('statement sort preserves chronological running balances', () async {
    final controller = StatementsReportController(
      type: StatementsReportType.supplierStatement,
      repository: _FixedStatementsReportRepository(
        StatementsReportData(
          records: [
            _statementRecord(
              id: 'purchase-1',
              date: DateTime(2025, 1, 1),
              reference: 'PI-1',
              debit: 100,
              credit: 0,
              transactionType: 'Purchase',
            ),
            _statementRecord(
              id: 'payment-1',
              date: DateTime(2025, 1, 2),
              reference: 'SP-1',
              debit: 0,
              credit: 40,
              transactionType: 'Payment',
            ),
          ],
          parties: const [(id: 'supplier-1', name: 'Supplier One')],
        ),
      ),
    );
    await controller.load();
    controller.selectParty('supplier-1');
    controller.applyFilters();
    controller.setSort(StatementsReportSortField.reference, ascending: false);

    final records = controller.visibleRecords;
    expect(records.map((record) => record.reference), ['SP-1', 'PI-1']);
    expect(
      {
        for (final record in records) record.reference: record.balance,
      },
      {'PI-1': 100, 'SP-1': 60},
    );
  });
}

StatementsReportRecord _record({
  required String id,
  required DateTime date,
  required String reference,
  required String partyId,
  required String partyName,
  required String branchId,
  required String partyType,
  required double amount,
}) =>
    StatementsReportRecord(
      id: id,
      date: date,
      reference: reference,
      partyId: partyId,
      partyName: partyName,
      branchId: branchId,
      branchName: branchId,
      branchIds: [branchId],
      partyType: partyType,
      description: 'Sales invoice',
      amount: amount,
      debit: amount,
      credit: 0,
      status: 'Approved',
    );

StatementsReportRecord _dispatchRecord({
  required String id,
  required DateTime date,
  required String customerId,
  required String status,
}) =>
    StatementsReportRecord(
      id: id,
      date: date,
      reference: id,
      partyId: customerId,
      partyName: customerId,
      branchId: '',
      branchName: '',
      description: 'Dispatch record',
      amount: 0,
      debit: 0,
      credit: 0,
      status: status,
    );

StatementsReportRecord _statementRecord({
  required String id,
  required DateTime date,
  required String reference,
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
      transactionType: transactionType,
      amount: debit + credit,
      debit: debit,
      credit: credit,
      status: '',
    );
