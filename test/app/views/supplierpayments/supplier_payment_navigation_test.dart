import 'package:cocoper_mobile/app/controllers/supplierpayments/supplier_payment_controller.dart';
import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/views/dashboard/operations_view.dart';
import 'package:cocoper_mobile/app/views/supplierpayments/savedsupplierpayments_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('Operations opens the registered Supplier Payments screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestSupplierPaymentBinding(),
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

    await tester.ensureVisible(find.text('Supplier Payments'));
    await tester.tap(find.text('Supplier Payments'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.savedSupplierPayments);
    expect(find.byType(SavedSupplierPaymentsView), findsOneWidget);
    expect(find.text('Add New Supplier Payment'), findsOneWidget);
    expect(find.text('No saved supplier payments.'), findsOneWidget);
  });
}

class _TestSupplierPaymentBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<SupplierPaymentController>(_TestSupplierPaymentController());
  }
}

class _TestSupplierPaymentController extends SupplierPaymentController {
  @override
  Future<void> loadSupplierPayments() async {}
}
