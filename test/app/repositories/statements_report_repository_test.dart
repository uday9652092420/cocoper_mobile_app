import 'package:cocoper_mobile/app/models/statements_report.dart';
import 'package:cocoper_mobile/app/repositories/statements_report_repository.dart';
import 'package:cocoper_mobile/app/services/statements_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixtureReportService extends StatementsReportService {
  _FixtureReportService(this.responses);

  final Map<String, List<dynamic>> responses;

  @override
  Future<List<dynamic>> fetchList(String endpoint) async =>
      responses[endpoint] ?? const [];
}

void main() {
  test('sales report maps customer type, branch, date and amount', () async {
    final repository = StatementsReportRepository(
      service: _FixtureReportService({
        'direct-sales': [
          {
            'id': 'sale-1',
            'directSaleNo': 'DS-1',
            'customerId': 'customer-1',
            'customerType': 'Local',
            'branchId': 'branch-1',
            'invoiceDate': '2025-05-14',
            'invoiceTotal': '250.50',
            'approved': true,
          },
        ],
        'customers': [
          {'id': 'customer-1', 'name': 'Customer One'},
        ],
        'branches': [
          {'id': 'branch-1', 'branch_name': 'Branch One'},
        ],
      }),
    );

    final data = await repository.load(StatementsReportType.salesRegister);

    expect(data.records, hasLength(1));
    expect(data.records.single.partyType, 'Local');
    expect(data.records.single.partyName, 'Customer One');
    expect(data.records.single.branchName, 'Branch One');
    expect(data.records.single.date, DateTime(2025, 5, 14));
    expect(data.records.single.amount, 250.5);
  });

  test('dispatch report maps status, driver mobile and line quantities',
      () async {
    final repository = StatementsReportRepository(
      service: _FixtureReportService({
        'loading-dispatch': [
          {
            'id': 'dispatch-1',
            'dispatchNumber': 'LD-1',
            'customerId': 'customer-1',
            'lorryNumber': 'TS-01',
            'driverName': 'Driver One',
            'driverMobile': '1234567890',
            'dispatchDate': '2025-06-01',
            'dispatchStatus': 'Draft',
            'lines': [
              {
                'branchId': 'branch-1',
                'quantity': 100,
                'loadedQuantity': 40,
                'pendingQuantity': 60,
              },
            ],
          },
        ],
        'customers': [
          {'id': 'customer-1', 'name': 'Customer One'},
        ],
        'branches': [
          {'id': 'branch-1', 'branch_name': 'Branch One'},
        ],
      }),
    );

    final data = await repository.load(StatementsReportType.pendingDispatch);
    final record = data.records.single;

    expect(record.reference, 'LD-1');
    expect(record.status, 'Draft');
    expect(record.partyName, 'Customer One');
    expect(record.branchName, 'Branch One');
    expect(record.lorryNumber, 'TS-01');
    expect(record.driverName, 'Driver One');
    expect(record.driverMobile, '1234567890');
    expect(record.totalQuantity, 100);
    expect(record.loadedQuantity, 40);
    expect(record.pendingQuantity, 60);
  });

  test('supplier statement uses the supplier payment business date', () async {
    const purchaseTimestamp = '2026-10-26';
    const paymentTimestamp = '2026-10-26T22:00:00.000Z';
    final repository = StatementsReportRepository(
      service: _FixtureReportService({
        'purchase-invoices': [
          {
            'id': 'purchase-1',
            'invoiceNo': 'GPI-01',
            'supplierId': 'supplier-1',
            'invoiceDate': purchaseTimestamp,
            'grandTotal': 1617660,
          },
        ],
        'supplier-payments': [
          {
            'id': 'payment-1',
            'paymentNumber': 'SP-01',
            'supplierId': 'supplier-1',
            'date': paymentTimestamp,
            'createdAt': '2026-10-26T08:00:00.000Z',
            'amount': 1000,
          },
          {
            'id': 'payment-2',
            'paymentNumber': 'SP-02',
            'supplierId': 'supplier-1',
            'date': '2026-10-27',
            'amount': 50000,
          },
        ],
        'suppliers': [
          {'id': 'supplier-1', 'supplier_name': 'Supplier One'},
        ],
      }),
    );

    final data = await repository.load(StatementsReportType.supplierStatement);

    expect(data.records.map((record) => record.reference),
        ['GPI-01', 'SP-01', 'SP-02']);
    expect(data.records[0].date?.day, 26);
    expect(data.records[0].date?.month, 10);
    expect(data.records[1].date?.day, 27);
    expect(data.records[1].date?.month, 10);
    expect(data.records[2].date?.day, 27);
    expect(data.records[2].date?.month, 10);
  });
}
