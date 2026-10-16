import 'dart:convert';
import 'dart:typed_data';

import 'package:cocoper_mobile/app/controllers/customerreceipt/customer_receipt_controller.dart';
import 'package:cocoper_mobile/app/models/customer_receipt.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

void main() {
  tearDown(Get.reset);

  group('Customer receipt API contract', () {
    test('parses the documented wrapped scalar next-number response', () {
      expect(
        CustomerReceiptController.parseReceiptNumberResponse(
          const {'success': true, 'data': 'RCP-01'},
        ),
        'RCP-01',
      );
    });

    test('parses a successful response with receipt_no inside data', () {
      expect(
        CustomerReceiptController.parseReceiptNumberResponse(
          const {
            'success': true,
            'data': {'receipt_no': 'RCP-02'},
          },
        ),
        'RCP-02',
      );
    });

    test('does not use a number from an unsuccessful response', () {
      expect(
        CustomerReceiptController.parseReceiptNumberResponse(
          const {'success': false, 'data': 'RCP-01'},
        ),
        isNull,
      );
    });

    test('serializes cumulative receipts with null invoice and no attachments',
        () {
      const receipt = CustomerReceipt(
        receiptNumber: 'RCP-01',
        date: '2026-10-16',
        customerId: 'customer-4',
        invoiceMode: 'Cumulative',
        paymentMode: 'Cash',
        amount: 250,
      );

      final request = receipt.toRequestJson(organizationId: 'org-7');

      expect(request, {
        'receipt_no': 'RCP-01',
        'customer_id': 'customer-4',
        'receipt_date': '2026-10-16',
        'invoice_mode': 'Cumulative',
        'invoice_no': null,
        'amount': 250,
        'payment_mode': 'Cash',
        'remarks': '',
        'attachment_names': null,
        'attachment_files': null,
        'organization_id': 'org-7',
      });
    });

    test('serializes attachment names and data URLs as JSON strings', () {
      const receipt = CustomerReceipt(
        receiptNumber: 'RCP-03',
        date: '2026-10-16',
        customerId: 'customer-4',
        invoiceMode: 'Cumulative',
        paymentMode: 'Cash',
        amount: 250,
      );
      final pdf = CustomerReceiptAttachment(
        name: 'proof.pdf',
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      );
      final request = receipt.toRequestJson(
        organizationId: 'org-7',
        attachmentNamesJson: jsonEncode([pdf.name]),
        attachmentFilesJson: jsonEncode([pdf.dataUrl]),
      );

      expect(request['attachment_names'], '["proof.pdf"]');
      expect(
        request['attachment_files'],
        '["data:application/pdf;base64,JVBERg=="]',
      );
      expect(request['attachment_names'], isA<String>());
      expect(request['attachment_files'], isA<String>());
    });

    test('uses the required MIME data URL for each supported file type', () {
      const content = [1, 2, 3];
      for (final entry in const {
        'receipt.pdf': 'application/pdf',
        'receipt.jpg': 'image/jpeg',
        'receipt.jpeg': 'image/jpeg',
        'receipt.png': 'image/png',
      }.entries) {
        final attachment = CustomerReceiptAttachment(
          name: entry.key,
          bytes: Uint8List.fromList(content),
        );
        expect(attachment.dataUrl, 'data:${entry.value};base64,AQID');
      }
      expect(
        CustomerReceiptAttachment.mimeTypeForName('receipt.txt'),
        isNull,
      );
    });

    test('maps backend approved flag to fail-closed receipt status', () {
      expect(
        CustomerReceipt.fromJson({'approved': false}).status,
        'Draft',
      );
      expect(
        CustomerReceipt.fromJson({'approved': 'true'}).status,
        'Approved',
      );
      expect(CustomerReceipt.fromJson({'approved': 'pending'}).status, '');
      expect(
        CustomerReceipt.fromJson({'approved': true, 'status': 'Closed'}).status,
        'Approved',
      );
      expect(
        CustomerReceipt.fromJson({'approved': false, 'status': 'Legacy'})
            .status,
        'Legacy',
      );
    });

    test('rejects non-integer amounts for receipt creation', () {
      const receipt = CustomerReceipt(
        receiptNumber: 'RCP-02',
        date: '2026-10-16',
        customerId: 'customer-4',
        invoiceMode: 'Cumulative',
        paymentMode: 'Cash',
        amount: 250.5,
      );

      expect(
        CustomerReceiptController.validate(receipt),
        'Amount must be a whole number of rupees.',
      );
    });

    test('parses invoice number and numeric-string totals from direct sales',
        () {
      final invoice = CustomerReceiptInvoice.fromSaleJson({
        'id': 'sale-1',
        'invoice_no': 'INV-001',
        'directSaleNo': 'DS-001',
        'customer_id': 'customer-1',
        'invoiceTotal': '1000.50',
        'approved': true,
      });

      expect(invoice.number, 'INV-001');
      expect(invoice.displayNumber, 'DS-001');
      expect(invoice.total, 1000.5);
      expect(invoice.approved, isTrue);
    });

    test('allocates direct and cumulative payments using web invoice ordering',
        () {
      final invoices = [
        const CustomerReceiptInvoice(
          id: 'sale-2',
          number: 'INV-002',
          displayNumber: 'DS-002',
          customerId: 'customer-1',
          customerName: '',
          invoiceDate: '2025-02-01',
          total: 800,
        ),
        const CustomerReceiptInvoice(
          id: 'sale-1',
          number: 'INV-001',
          displayNumber: 'DS-001',
          customerId: 'customer-1',
          customerName: '',
          invoiceDate: '2025-01-01',
          total: 1000,
        ),
        const CustomerReceiptInvoice(
          id: 'sale-3',
          number: 'INV-003',
          customerId: 'customer-1',
          customerName: '',
          invoiceDate: '2025-03-01',
          total: 200,
          approved: false,
        ),
      ];
      final receipts = [
        const CustomerReceipt(
          customerId: 'customer-1',
          invoiceMode: 'Invoice by Invoice',
          invoiceNumber: 'INV-001',
          amount: 200,
        ),
        const CustomerReceipt(
          customerId: 'customer-1',
          invoiceMode: 'Cumulative',
          amount: 500,
        ),
      ];

      final balances = CustomerReceiptController.resolveCustomerInvoiceBalances(
        'customer-1',
        invoices,
        receipts,
      );

      expect(balances.map((invoice) => invoice.number), ['INV-001', 'INV-002']);
      expect(balances[0].total, 1000);
      expect(balances[0].paid, 700);
      expect(balances[0].outstanding, 300);
      expect(balances[1].paid, 0);
      expect(balances[1].outstanding, 800);
      expect(
        CustomerReceiptController.resolveCustomerInvoiceBalances(
          'customer-2',
          invoices,
          receipts,
        ),
        isEmpty,
      );
    });

    test('parses numeric-string receipt amounts for invoice balances', () {
      final receipt = CustomerReceipt.fromJson({
        'customer_id': 'customer-1',
        'invoice_mode': 'Invoice by Invoice',
        'invoice_no': 'INV-001',
        'amount': '25.50',
      });
      expect(receipt.amount, 25.5);
    });

    test('edit sends PUT data and preserves attachments returned by API',
        () async {
      final controller = _ReceiptWriteController(
        latestReceipt: const CustomerReceipt(
          id: 'receipt-9',
          receiptNumber: 'RCP-09',
          date: '2026-10-16',
          customerId: 'customer-4',
          invoiceMode: 'Cumulative',
          paymentMode: 'Cash',
          amount: 200,
          status: 'Draft',
          attachmentNamesJson: '["proof.png"]',
          attachmentFilesJson: '["data:image/png;base64,AQID"]',
          hasAttachmentFields: true,
        ),
      );

      final saved = await controller.saveReceipt(
        const CustomerReceipt(
          id: 'receipt-9',
          receiptNumber: 'RCP-09',
          date: '2026-10-16',
          customerId: 'customer-4',
          invoiceMode: 'Cumulative',
          paymentMode: 'Cash',
          amount: 250,
          status: 'Draft',
        ),
        isEdit: true,
      );

      expect(saved, isTrue);
      expect(controller.updateId, 'receipt-9');
      expect(controller.createRequestCount, 0);
      expect(controller.updateRequest?['amount'], 250);
      expect(controller.updateRequest?['attachment_names'], '["proof.png"]');
      expect(
        controller.updateRequest?['attachment_files'],
        '["data:image/png;base64,AQID"]',
      );
      expect(controller.updateRequest?['organization_id'], 'org-4');
      expect(controller.refreshCount, 1);
    });

    test('edit with unknown existing attachments requires replacement files',
        () async {
      final controller = _ReceiptWriteController(
        latestReceipt: const CustomerReceipt(
          id: 'receipt-10',
          receiptNumber: 'RCP-10',
          date: '2026-10-16',
          customerId: 'customer-4',
          invoiceMode: 'Cumulative',
          paymentMode: 'Cash',
          amount: 200,
          status: 'Draft',
        ),
      );

      final saved = await controller.saveReceipt(
        const CustomerReceipt(
          id: 'receipt-10',
          receiptNumber: 'RCP-10',
          date: '2026-10-16',
          customerId: 'customer-4',
          invoiceMode: 'Cumulative',
          paymentMode: 'Cash',
          amount: 250,
          status: 'Draft',
        ),
        isEdit: true,
      );

      expect(saved, isFalse);
      expect(controller.updateId, isNull);
      expect(controller.createRequestCount, 0);
      expect(controller.refreshCount, 0);
      expect(controller.lastError, contains('Select replacement attachment'));
    });

    test('create sends selected attachments and refreshes after success',
        () async {
      final controller = _ReceiptWriteController(
        latestReceipt: const CustomerReceipt(),
      );
      final attachment = CustomerReceiptAttachment(
        name: 'proof.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final saved = await controller.saveReceipt(
        const CustomerReceipt(
          receiptNumber: 'RCP-11',
          date: '2026-10-16',
          customerId: 'customer-4',
          invoiceMode: 'Cumulative',
          paymentMode: 'UPI',
          amount: 300,
        ),
        isEdit: false,
        attachments: [attachment],
      );

      expect(saved, isTrue);
      expect(controller.createRequestCount, 1);
      expect(controller.updateId, isNull);
      expect(controller.createRequest?['attachment_names'], '["proof.jpg"]');
      expect(
        controller.createRequest?['attachment_files'],
        '["data:image/jpeg;base64,AQID"]',
      );
      expect(controller.refreshCount, 1);
    });
  });
}

class _ReceiptWriteController extends CustomerReceiptController {
  _ReceiptWriteController({required this.latestReceipt});

  final CustomerReceipt latestReceipt;
  String? updateId;
  Map<String, dynamic>? createRequest;
  Map<String, dynamic>? updateRequest;
  int createRequestCount = 0;
  int refreshCount = 0;
  String? lastError;

  @override
  Future<CustomerReceipt?> fetchReceipt(String id) async => latestReceipt;

  @override
  Future<String> getReceiptOrganizationId() async => 'org-4';

  @override
  Future<Response<dynamic>?> createCustomerReceiptRequest(
    Map<String, dynamic> body,
  ) async {
    createRequestCount++;
    createRequest = body;
    return _successResponse();
  }

  @override
  Future<Response<dynamic>?> updateCustomerReceiptRequest(
    String id,
    Map<String, dynamic> body,
  ) async {
    updateId = id;
    updateRequest = body;
    return _successResponse();
  }

  @override
  Future<void> loadCustomerReceipts() async {
    refreshCount++;
  }

  @override
  void showReceiptSaveError(String message) {
    lastError = message;
  }

  @override
  void showReceiptSaveSuccess(bool isEdit) {}

  Response<dynamic> _successResponse() => Response<dynamic>(
        requestOptions: RequestOptions(path: 'customer-receipts'),
        statusCode: 200,
        data: const {'success': true},
      );
}
