import 'package:cocoper_mobile/app/controllers/supplierpayments/supplier_payment_controller.dart';
import 'package:cocoper_mobile/app/models/supplier_payment.dart';
import 'package:cocoper_mobile/app/views/supplierpayments/savedsupplierpayments_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('only unapproved supplier payments can be deleted', (
    tester,
  ) async {
    final controller = _TestSupplierPaymentController()
      ..payments.assignAll([
        const SupplierPayment(
          id: 'draft-id',
          paymentNumber: 'SP-DRAFT',
          supplierName: 'Supplier',
        ),
        const SupplierPayment(
          id: 'approved-id',
          paymentNumber: 'SP-APPROVED',
          supplierName: 'Supplier',
          approved: true,
        ),
      ]);
    Get.put<SupplierPaymentController>(controller);

    await tester.pumpWidget(
      const GetMaterialApp(home: SavedSupplierPaymentsView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('SP-DRAFT'), findsOneWidget);
    expect(find.text('SP-APPROVED'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Supplier Payment'), findsOneWidget);
    expect(find.textContaining('SP-DRAFT'), findsNWidgets(2));

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(controller.deletedPaymentIds, ['draft-id']);
  });
}

class _TestSupplierPaymentController extends SupplierPaymentController {
  final deletedPaymentIds = <String>[];

  @override
  Future<void> loadSupplierPayments() async {}

  @override
  Future<bool> deleteSupplierPayment(SupplierPayment payment) async {
    deletedPaymentIds.add(payment.id);
    return true;
  }
}
