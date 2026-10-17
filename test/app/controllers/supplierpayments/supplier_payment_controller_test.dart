import 'package:cocoper_mobile/app/controllers/supplierpayments/supplier_payment_controller.dart';
import 'package:cocoper_mobile/app/models/purchase_invoice.dart';
import 'package:cocoper_mobile/app/models/supplier_payment.dart';
import 'package:cocoper_mobile/app/repositories/supplier_payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSupplierPaymentRepository extends SupplierPaymentRepository {
  _FakeSupplierPaymentRepository(this.records);

  final List<SupplierPayment> records;

  @override
  Future<List<SupplierPayment>> fetchSupplierPayments() async => records;
}

void main() {
  const payment = SupplierPayment(
    id: 'payment-id',
    paymentNumber: 'SP-01',
    supplierId: 'supplier-id',
    supplierName: 'Supplier',
    date: '2026-10-17',
    invoiceMode: 'Invoice by Invoice',
    paymentMode: 'Cash',
    amount: 20,
    purchaseInvoiceId: 'invoice-id',
    attachmentNamesJson: '[]',
    attachmentFilesJson: '[]',
    hasAttachmentFields: true,
  );

  test('validates required fields and positive amounts', () {
    expect(
      SupplierPaymentController.validate(payment, isEdit: true),
      isNull,
    );
    expect(
      SupplierPaymentController.validate(
        const SupplierPayment(
          paymentNumber: 'SP-01',
          date: '2026-10-17',
          supplierId: 'supplier-id',
          invoiceMode: 'Cumulative',
          paymentMode: 'Cash',
          amount: 0,
        ),
        isEdit: false,
      ),
      'Enter an amount greater than zero.',
    );
    expect(
      SupplierPaymentController.validate(
        const SupplierPayment(
          paymentNumber: 'SP-01',
          date: '2026-10-17',
          supplierId: 'supplier-id',
          invoiceMode: 'Invoice by Invoice',
          paymentMode: 'Cash',
          amount: 10,
        ),
        isEdit: false,
      ),
      'Select a purchase invoice.',
    );
  });

  test('filters listing and reloads a payment by database ID', () async {
    final controller = SupplierPaymentController(
      repository: _FakeSupplierPaymentRepository([
        payment,
        const SupplierPayment(
          id: 'other-id',
          paymentNumber: 'SP-02',
          supplierName: 'Another Supplier',
        ),
      ]),
    );

    await controller.loadSupplierPayments();
    controller.searchQuery.value = 'another';
    expect(controller.filteredPayments.single.id, 'other-id');

    final loaded = await controller.loadSupplierPaymentById('payment-id');
    expect(loaded?.id, 'payment-id');
    expect(loaded?.attachmentFilesJson, '[]');
    expect(controller.detail.value?.id, 'payment-id');
  });

  test('invoice options use supplier and outstanding values from the API', () {
    final controller = SupplierPaymentController(
      repository: _FakeSupplierPaymentRepository(const []),
    );
    controller.purchaseInvoices.value = [
      const PurchaseInvoice(
        id: 'invoice-open',
        supplierId: 'supplier-id',
        invoiceNumber: 'PI-OPEN',
        status: 'Approved',
        outstandingAmount: 35,
      ),
      const PurchaseInvoice(
        id: 'invoice-paid',
        supplierId: 'supplier-id',
        invoiceNumber: 'PI-PAID',
        status: 'Approved',
        outstandingAmount: 0,
      ),
      const PurchaseInvoice(
        id: 'invoice-other',
        supplierId: 'another-supplier',
        invoiceNumber: 'PI-OTHER',
        status: 'Approved',
        outstandingAmount: 50,
      ),
    ];

    expect(
      controller
          .invoicesForSupplier('supplier-id')
          .map((invoice) => invoice.id),
      ['invoice-open'],
    );
    expect(
      controller.outstandingForInvoice(
        controller.purchaseInvoices.first,
        editing: payment,
      ),
      35,
    );
  });
}
