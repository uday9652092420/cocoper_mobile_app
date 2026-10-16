import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/controllers/customerreceipt/customer_receipt_controller.dart';
import 'package:cocoper_mobile/app/views/customerreceipt/savedcustomerreceipt_view.dart';
import 'package:cocoper_mobile/app/views/dashboard/operations_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('Operations opens the registered saved customer receipts view', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestReceiptBinding(),
        initialRoute: '/test_operations',
        getPages: [
          GetPage(
            name: '/test_operations',
            page: () => const OperationsView(),
          ),
          ...AppPages.routes,
        ],
      ),
    );

    await tester.ensureVisible(find.text('Customer Receipts'));
    await tester.tap(find.text('Customer Receipts'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.savedCustomerReceipts);
    expect(find.byType(SavedCustomerReceiptsView), findsOneWidget);
    expect(find.text('New Customer Receipt'), findsOneWidget);
    expect(find.text('No saved customer receipts'), findsOneWidget);
  });
}

class _TestReceiptBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<CustomerReceiptController>(_TestCustomerReceiptController());
  }
}

class _TestCustomerReceiptController extends CustomerReceiptController {
  @override
  Future<void> loadCustomerReceipts() async {}

  @override
  Future<void> loadCustomers() async {}
}
