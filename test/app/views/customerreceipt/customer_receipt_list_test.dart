import 'package:cocoper_mobile/app/controllers/customerreceipt/customer_receipt_controller.dart';
import 'package:cocoper_mobile/app/models/customer_receipt.dart';
import 'package:cocoper_mobile/app/models/lookup_option.dart';
import 'package:cocoper_mobile/app/views/customerreceipt/savedcustomerreceipt_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('Draft receipt actions are available and View is read-only',
      (tester) async {
    final controller = _ReceiptListController([
      _receipt('draft-1', 'Draft'),
    ]);
    await tester.pumpWidget(_App(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(find.text('Draft receipt'), findsNWidgets(2));
    expect(find.text('Acme Foods'), findsNWidgets(2));
    expect(find.text('Cumulative'), findsOneWidget);
    expect(find.text('Cash'), findsNWidgets(2));
  });

  testWidgets('Approved and unknown statuses fail closed for mutations',
      (tester) async {
    final controller = _ReceiptListController([
      CustomerReceipt.fromJson({
        'id': 'approved-1',
        'receipt_no': 'RCP-Approved',
        'customer_id': 'customer-1',
        'approved': true,
      }),
      _receipt('unknown-1', 'Legacy Status'),
    ]);
    await tester.pumpWidget(_App(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsNothing);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('View'), findsNWidgets(2));
  });

  testWidgets('Edit is available for server-listed unapproved receipts',
      (tester) async {
    final receipt = CustomerReceipt.fromJson({
      'id': 'draft-from-api',
      'receipt_no': 'RCP-02',
      'customer_id': 'customer-1',
      'approved': false,
    });
    final controller = _ReceiptListController([receipt]);
    await tester.pumpWidget(_App(controller: controller));
    await tester.pumpAndSettle();

    expect(receipt.status, 'Draft');
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('list shows its count and clears receipt search', (tester) async {
    final controller = _ReceiptListController([
      _receipt('draft-1', 'Draft'),
      _receipt('draft-2', 'Draft'),
    ]);
    await tester.pumpWidget(_App(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('2 receipts'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'RCP-not-found',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching receipts'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(controller.searchQuery.value, isEmpty);
    expect(find.text('2 receipts'), findsOneWidget);
  });

  testWidgets('long receipt details fit on a narrow mobile screen',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _ReceiptListController([
      const CustomerReceipt(
        id: 'draft-long',
        receiptNumber: 'RCP-VERY-LONG-RECEIPT-NUMBER-000000000000000000',
        date: '2026-10-16',
        customerId: 'customer-1',
        invoiceMode: 'Invoice by Invoice',
        invoiceNumber: 'INV-000000000000000000',
        paymentMode: 'UPI',
        amount: 9876543210.99,
        status: 'Draft',
      ),
    ]);
    controller.customers.assignAll(const [
      LookupOption(
        id: 'customer-1',
        label:
            'An exceptionally long customer name that should wrap without overflowing the receipt card',
      ),
    ]);
    await tester.pumpWidget(_App(controller: controller));
    await tester.pumpAndSettle();

    final layoutError = tester.takeException();
    expect(
      layoutError,
      isNull,
      reason: '$layoutError',
    );
  });

  testWidgets('cancelling delete confirmation makes no delete request',
      (tester) async {
    final controller = _ReceiptListController([
      _receipt('draft-1', 'Draft'),
    ]);
    await tester.pumpWidget(_App(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.deleteCalls, 0);
  });
}

CustomerReceipt _receipt(String id, String status) => CustomerReceipt(
      id: id,
      receiptNumber: '$status receipt',
      date: '2026-10-16',
      customerId: 'customer-1',
      invoiceMode: 'Cumulative',
      paymentMode: 'Cash',
      amount: 120,
      status: status,
    );

class _App extends StatelessWidget {
  const _App({required this.controller});

  final _ReceiptListController controller;

  @override
  Widget build(BuildContext context) => GetMaterialApp(
        initialBinding: _ReceiptBinding(controller),
        home: const SavedCustomerReceiptsView(),
      );
}

class _ReceiptBinding extends Bindings {
  _ReceiptBinding(this.controller);

  final _ReceiptListController controller;

  @override
  void dependencies() {
    Get.put<CustomerReceiptController>(controller);
  }
}

class _ReceiptListController extends CustomerReceiptController {
  _ReceiptListController(List<CustomerReceipt> initialReceipts) {
    receipts.assignAll(initialReceipts);
    customers.assignAll(const [
      LookupOption(id: 'customer-1', label: 'Acme Foods'),
    ]);
  }

  int deleteCalls = 0;

  @override
  Future<void> loadCustomerReceipts() async {}

  @override
  Future<void> loadCustomers() async {}

  @override
  Future<bool> deleteReceipt(CustomerReceipt receipt) async {
    deleteCalls++;
    return true;
  }
}
