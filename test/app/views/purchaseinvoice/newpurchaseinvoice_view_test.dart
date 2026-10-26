import 'package:cocoper_mobile/app/controllers/purchaseinvoice/purchase_invoice_controller.dart';
import 'package:cocoper_mobile/app/models/lookup_option.dart';
import 'package:cocoper_mobile/app/views/purchaseinvoice/newpurchaseinvoice_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _StubPurchaseInvoiceController extends PurchaseInvoiceController {
  _StubPurchaseInvoiceController() {
    branches.assignAll(const [
      LookupOption(id: 'branch-1', label: 'First Branch'),
      LookupOption(id: 'branch-2', label: 'Second Branch'),
    ]);
  }

  @override
  Future<String> prepareCreate() async => 'RPI-01';
}

void main() {
  tearDown(Get.reset);

  testWidgets('new purchase invoice defaults to the first available branch', (
    tester,
  ) async {
    Get.put<PurchaseInvoiceController>(_StubPurchaseInvoiceController());

    await tester.pumpWidget(
      const GetMaterialApp(home: NewPurchaseInvoiceView()),
    );
    await tester.pumpAndSettle();

    final branchDropdown = find.byType(DropdownButtonFormField<String>).first;
    expect(
      tester.state<FormFieldState<String>>(branchDropdown).value,
      'branch-1',
    );
    expect(find.text('First Branch'), findsOneWidget);
  });
}
