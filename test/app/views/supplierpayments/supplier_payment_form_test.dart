import 'dart:convert';

import 'package:cocoper_mobile/app/controllers/supplierpayments/supplier_payment_controller.dart';
import 'package:cocoper_mobile/app/models/lookup_option.dart';
import 'package:cocoper_mobile/app/models/purchase_invoice.dart';
import 'package:cocoper_mobile/app/models/supplier_payment.dart';
import 'package:cocoper_mobile/app/repositories/supplier_payment_repository.dart';
import 'package:cocoper_mobile/app/views/supplierpayments/supplier_payment_form.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const _pngDataUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l4sAAAAASUVORK5CYII=';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('edit previews saved attachment and hides actions after approval',
      (tester) async {
    final repository = _SupplierPaymentFormRepository();
    final controller = SupplierPaymentController(repository: repository);
    Get.put<SupplierPaymentController>(controller);

    await tester.pumpWidget(
      const GetMaterialApp(
        home: SupplierPaymentFormView(isEdit: true, paymentId: 'payment-id'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('saved-proof.png'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);

    final previewButton = find.byTooltip('Preview saved-proof.png');
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close attachment preview'), findsOneWidget);
    await tester.tap(find.byTooltip('Close attachment preview'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(find.text('Approve Supplier Payment'), findsOneWidget);
    await tester.tap(find.text('Approve').last);
    await tester.pumpAndSettle();

    expect(repository.approveCalls, 1);
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets('approved edit starts without actions or an Obx error',
      (tester) async {
    final repository = _SupplierPaymentFormRepository()..approved = true;
    final controller = SupplierPaymentController(repository: repository);
    Get.put<SupplierPaymentController>(controller);

    await tester.pumpWidget(
      const GetMaterialApp(
        home: SupplierPaymentFormView(isEdit: true, paymentId: 'payment-id'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Approve'), findsNothing);
  });
}

class _SupplierPaymentFormRepository extends SupplierPaymentRepository {
  int approveCalls = 0;
  bool approved = false;

  SupplierPayment get _payment => SupplierPayment(
        id: 'payment-id',
        paymentNumber: 'SP-12',
        supplierId: 'supplier-id',
        supplierName: 'ABC Supplier',
        date: '2026-11-02',
        invoiceMode: 'Cumulative',
        paymentMode: 'UPI',
        amount: 5000,
        remarks: 'Payment made',
        attachmentNamesJson: jsonEncode(['saved-proof.png']),
        attachmentFilesJson: jsonEncode([_pngDataUrl]),
        hasAttachmentFields: true,
        approved: approved,
      );

  @override
  Future<List<SupplierPayment>> fetchSupplierPayments() async => [_payment];

  @override
  Future<List<LookupOption>> fetchSuppliers() async => const [];

  @override
  Future<List<PurchaseInvoice>> fetchPurchaseInvoices() async => const [];

  @override
  Future<dio.Response<dynamic>?> approveSupplierPayment(String id) async {
    approveCalls++;
    approved = true;
    return dio.Response<dynamic>(
      requestOptions: dio.RequestOptions(path: 'supplier-payments/$id/approve'),
      statusCode: 200,
      data: {
        'success': true,
        'data': {'id': id, 'approved': true},
      },
    );
  }
}
