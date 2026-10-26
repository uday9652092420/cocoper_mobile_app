import 'package:cocoper_mobile/app/models/supplier_payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the backend supplier-payment record and preserves attachment data',
      () {
    final payment = SupplierPayment.fromJson({
      'id': 'payment-db-id',
      'paymentNumber': 'SP-09',
      'supplierId': 'supplier-id',
      'supplierName': 'Supplier One',
      'date': '2026-10-17T00:00:00.000Z',
      'invoiceMode': 'Invoice by Invoice',
      'paymentMode': 'Bank',
      'amount': '25.75',
      'purchaseInvoiceId': 'invoice-db-id',
      'remarks': 'Part payment',
      'attachmentNames': '["proof.pdf"]',
      'attachmentFiles': '["data:application/pdf;base64,AQID"]',
      'approved': false,
      'organizationId': 'organization-id',
    });

    expect(payment.id, 'payment-db-id');
    expect(payment.paymentNumber, 'SP-09');
    expect(payment.supplierId, 'supplier-id');
    expect(payment.date, '2026-10-17');
    expect(payment.amount, 25.75);
    expect(payment.purchaseInvoiceId, 'invoice-db-id');
    expect(payment.hasAttachmentFields, isTrue);
    expect(payment.canSafelyPreserveAttachments, isTrue);
    expect(payment.attachmentNamesJson, '["proof.pdf"]');
  });

  test('uses the backend business date for UTC-serialized payment dates', () {
    expect(
      SupplierPayment.fromJson({
        'date': '2026-10-25T22:00:00.000Z',
      }).date,
      '2026-10-26',
    );
    expect(
      SupplierPayment.fromJson({
        'date': '2026-10-17T00:00:00.000Z',
      }).date,
      '2026-10-17',
    );
    expect(
      SupplierPayment.fromJson({'date': '2026-10-26'}).date,
      '2026-10-26',
    );
  });

  test(
      'serializes the verified camelCase update payload and nulls cumulative invoice',
      () {
    const payment = SupplierPayment(
      id: 'payment-db-id',
      paymentNumber: 'SP-09',
      supplierId: 'supplier-id',
      supplierName: 'Supplier One',
      date: '2026-10-17',
      invoiceMode: 'Cumulative',
      paymentMode: 'UPI',
      amount: 11.5,
      purchaseInvoiceId: 'must-not-be-sent',
      remarks: 'Updated',
      attachmentNamesJson: '[]',
      attachmentFilesJson: '[]',
    );

    expect(
      payment.toRequestJson(
        organizationId: 'organization-id',
      ),
      {
        'paymentNumber': 'SP-09',
        'supplierId': 'supplier-id',
        'supplierName': 'Supplier One',
        'date': '2026-10-17',
        'invoiceMode': 'Cumulative',
        'paymentMode': 'UPI',
        'amount': 11.5,
        'purchaseInvoiceId': null,
        'remarks': 'Updated',
        'attachmentNames': '[]',
        'attachmentFiles': '[]',
        'organizationId': 'organization-id',
      },
    );
  });

  test('distinguishes absent attachment fields from explicit no attachments',
      () {
    final absent = SupplierPayment.fromJson({'id': 'payment-id'});
    final empty = SupplierPayment.fromJson({
      'id': 'payment-id',
      'attachmentNames': null,
      'attachmentFiles': null,
    });

    expect(absent.hasAttachmentFields, isFalse);
    expect(empty.hasAttachmentFields, isTrue);
    expect(absent.canSafelyPreserveAttachments, isFalse);
    expect(empty.canSafelyPreserveAttachments, isTrue);
    expect(
      SupplierPayment.fromJson({
        'attachmentNames': '["proof.pdf"]',
        'attachmentFiles': null,
      }).canSafelyPreserveAttachments,
      isFalse,
    );
    expect(
      SupplierPayment.fromJson({
        'attachmentNames': '["proof.pdf"]',
        'attachmentFiles': '[]',
      }).canSafelyPreserveAttachments,
      isFalse,
    );
    expect(
      SupplierPaymentAttachment.decodeStringArray('["a.pdf",2]'),
      isNull,
    );
    expect(
      SupplierPaymentAttachment.mimeTypeForName('image.PNG'),
      'image/png',
    );
  });
}
