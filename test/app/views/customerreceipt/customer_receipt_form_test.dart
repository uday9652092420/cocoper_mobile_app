import 'dart:async';
import 'dart:typed_data';

import 'package:cocoper_mobile/app/controllers/customerreceipt/customer_receipt_controller.dart';
import 'package:cocoper_mobile/app/models/customer_receipt.dart';
import 'package:cocoper_mobile/app/models/lookup_option.dart';
import 'package:cocoper_mobile/app/views/customerreceipt/editcustomerreceipt_view.dart';
import 'package:cocoper_mobile/app/views/customerreceipt/newcustomerreceipt_view.dart';
import 'package:cocoper_mobile/app/views/customerreceipt/customer_receipt_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('new receipt loads allocated number and validates required data',
      (tester) async {
    final controller = _FakeCustomerReceiptController();

    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestReceiptBinding(controller),
        home: const NewCustomerReceiptView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Customer Receipt'), findsOneWidget);
    expect(find.text('CR-104'), findsOneWidget);
    expect(find.text('Payment Screenshot'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Select a customer.'), findsOneWidget);
    expect(find.text('Amount is required.'), findsOneWidget);
    expect(controller.saveCalls, 0);
  });

  testWidgets('failed auto-number generation can be retried', (tester) async {
    final controller = _FakeCustomerReceiptController()
      ..numberResults = [null, 'CR-105'];

    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestReceiptBinding(controller),
        home: const NewCustomerReceiptView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not generate a receipt number'),
        findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    final numberField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(numberField.controller?.text, 'CR-105');
    expect(find.textContaining('Could not generate a receipt number'),
        findsNothing);
  });

  testWidgets('new receipt is visible while number generation is pending',
      (tester) async {
    final controller = _FakeCustomerReceiptController()
      ..numberCompleter = Completer<String?>();

    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestReceiptBinding(controller),
        home: const NewCustomerReceiptView(),
      ),
    );
    await tester.pump();

    expect(find.text('New Customer Receipt'), findsOneWidget);
    expect(find.text('Receipt Number'), findsOneWidget);
    expect(controller.numberCall, 1);
    expect(
        tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .first
            .controller
            ?.text,
        isEmpty);

    controller.numberCompleter!.complete('CR-106');
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .first
          .controller
          ?.text,
      'CR-106',
    );
  });

  testWidgets('late number response does not overwrite manual receipt number',
      (tester) async {
    final controller = _FakeCustomerReceiptController()
      ..numberCompleter = Completer<String?>();

    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestReceiptBinding(controller),
        home: const NewCustomerReceiptView(),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'MANUAL-01');

    controller.numberCompleter!.complete('CR-107');
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .first
          .controller
          ?.text,
      'MANUAL-01',
    );
  });

  testWidgets('selecting an invoice prefills its remaining balance',
      (tester) async {
    final controller = _FakeCustomerReceiptController()
      ..invoiceRows = const [
        CustomerReceiptInvoice(
          id: 'sale-1',
          number: 'INV-001',
          displayNumber: 'DS-001',
          customerId: 'customer-1',
          customerName: 'Acme Foods',
          total: 1000,
        ),
      ]
      ..receiptRows = const [
        CustomerReceipt(
          customerId: 'customer-1',
          invoiceMode: 'Invoice by Invoice',
          invoiceNumber: 'INV-001',
          amount: 250,
        ),
      ];

    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestReceiptBinding(controller),
        home: const NewCustomerReceiptView(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme Foods').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DS-001 · 1000').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .elementAt(2)
          .controller
          ?.text,
      '750',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(controller.saveCalls, 1);
    expect(controller.savedReceipt?.invoiceNumber, 'INV-001');
    expect(controller.savedReceipt?.amount, 750);
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .elementAt(2)
          .controller
          ?.text,
      '750',
    );
  });

  testWidgets('changing customer or invoice mode clears invoice amount',
      (tester) async {
    final controller = _FakeCustomerReceiptController()
      ..invoiceRows = const [
        CustomerReceiptInvoice(
          id: 'sale-1',
          number: 'INV-001',
          displayNumber: 'DS-001',
          customerId: 'customer-1',
          customerName: 'Acme Foods',
          total: 1000,
        ),
        CustomerReceiptInvoice(
          id: 'sale-2',
          number: 'INV-002',
          displayNumber: 'DS-002',
          customerId: 'customer-1',
          customerName: 'Acme Foods',
          total: 200,
        ),
      ];

    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestReceiptBinding(controller),
        home: const NewCustomerReceiptView(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme Foods').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DS-001 · 1000').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DS-002 · 200').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .elementAt(2)
          .controller
          ?.text,
      '200',
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cumulative').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .elementAt(2)
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.text('DS-001 · 1000'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invoice by Invoice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DS-002 · 200').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other Foods').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .elementAt(2)
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.text('DS-002 · 200'), findsNothing);
  });

  testWidgets('edit receipt loads the selected draft fields', (tester) async {
    final controller = _FakeCustomerReceiptController();

    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestReceiptBinding(controller),
        home: const EditCustomerReceiptView(receiptId: 'receipt-7'),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.fetchedId, 'receipt-7');
    expect(find.text('Edit Customer Receipt'), findsOneWidget);
    expect(find.text('Acme Foods'), findsOneWidget);
    expect(find.text('Cumulative'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);

    final fieldControllers = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((field) => field.controller?.text)
        .toList();
    expect(fieldControllers, contains('CR-103'));
    expect(fieldControllers, contains('750'));
    expect(fieldControllers, contains('Advance payment'));
  });

  testWidgets('edit preserves fields and permits update with replacement files',
      (tester) async {
    final controller = _FakeCustomerReceiptController();

    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestReceiptBinding(controller),
        home: CustomerReceiptFormView(
          isEdit: true,
          receiptId: 'receipt-7',
          attachmentPicker: () async => [
            CustomerReceiptAttachment(
              name: 'replacement.png',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Select replacement attachment(s)'),
        findsOneWidget);
    expect(
        find.textContaining('Editing is temporarily read-only'), findsNothing);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(controller.saveCalls, 0);

    await tester.enterText(find.byType(TextFormField).last, 'Updated remark');
    await tester.tap(find.text('Attach File / Upload Attachment'));
    await tester.pumpAndSettle();
    expect(find.text('replacement.png'), findsOneWidget);
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(controller.saveCalls, 1);
    expect(controller.lastIsEdit, isTrue);
    expect(controller.savedReceipt?.id, 'receipt-7');
    expect(controller.savedReceipt?.remarks, 'Updated remark');
    expect(controller.savedAttachments.single.name, 'replacement.png');
    expect(controller.savedAttachments.single.dataUrl,
        'data:image/png;base64,AQID');
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .last
          .controller
          ?.text,
      'Updated remark',
    );
  });

  testWidgets('existing receipt without attachment data cannot save silently',
      (tester) async {
    final controller = _FakeCustomerReceiptController();
    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestReceiptBinding(controller),
        home: const EditCustomerReceiptView(receiptId: 'receipt-7'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Save Changes'),
          )
          .onPressed,
      isNull,
    );
    expect(controller.saveCalls, 0);
  });

  testWidgets('supports multiple PDF, JPG, and PNG files and removal',
      (tester) async {
    final controller = _FakeCustomerReceiptController();
    final attachments = [
      CustomerReceiptAttachment(
        name: 'proof.pdf',
        bytes: Uint8List.fromList([1]),
      ),
      CustomerReceiptAttachment(
        name: 'photo.jpg',
        bytes: Uint8List.fromList([2]),
      ),
      CustomerReceiptAttachment(
        name: 'scan.png',
        bytes: Uint8List.fromList([3]),
      ),
    ];
    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestReceiptBinding(controller),
        home: CustomerReceiptFormView(
          isEdit: false,
          attachmentPicker: () async => attachments,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach File / Upload Attachment'));
    await tester.pumpAndSettle();

    expect(find.text('proof.pdf'), findsOneWidget);
    expect(find.text('photo.jpg'), findsOneWidget);
    expect(find.text('scan.png'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Remove photo.jpg'));
    await tester.tap(find.byTooltip('Remove photo.jpg'));
    await tester.pumpAndSettle();
    expect(find.text('photo.jpg'), findsNothing);
    expect(find.text('proof.pdf'), findsOneWidget);
    expect(find.text('scan.png'), findsOneWidget);
  });

  testWidgets('unsupported attachment is rejected and cancel is harmless',
      (tester) async {
    final controller = _FakeCustomerReceiptController();
    var shouldReturnUnsupported = true;
    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestReceiptBinding(controller),
        home: CustomerReceiptFormView(
          isEdit: false,
          attachmentPicker: () async => shouldReturnUnsupported
              ? [
                  CustomerReceiptAttachment(
                    name: 'notes.txt',
                    bytes: Uint8List.fromList([1]),
                  ),
                ]
              : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach File / Upload Attachment'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unsupported file "notes.txt"'), findsOneWidget);
    expect(find.text('notes.txt'), findsNothing);

    shouldReturnUnsupported = false;
    await tester.tap(find.text('Attach File / Upload Attachment'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unsupported file "notes.txt"'), findsNothing);
    expect(find.text('New Customer Receipt'), findsOneWidget);
  });

  testWidgets('failed create keeps entered form values on screen',
      (tester) async {
    final controller = _FakeCustomerReceiptController();

    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestReceiptBinding(controller),
        home: const NewCustomerReceiptView(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme Foods').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cumulative').last);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(2), '125');
    await tester.enterText(fields.at(3), 'Keep this note');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(controller.saveCalls, 1);
    final values = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((field) => field.controller?.text)
        .toList();
    expect(values, contains('125'));
    expect(values, contains('Keep this note'));
    expect(find.text('New Customer Receipt'), findsOneWidget);
  });
}

class _TestReceiptBinding extends Bindings {
  _TestReceiptBinding(this.controller);

  final CustomerReceiptController controller;

  @override
  void dependencies() {
    Get.put<CustomerReceiptController>(controller);
  }
}

class _FakeCustomerReceiptController extends CustomerReceiptController {
  int saveCalls = 0;
  String? fetchedId;
  CustomerReceipt? savedReceipt;
  List<CustomerReceiptAttachment> savedAttachments = [];
  bool? lastIsEdit;
  List<String?> numberResults = ['CR-104'];
  int numberCall = 0;
  Completer<String?>? numberCompleter;
  List<CustomerReceiptInvoice> invoiceRows = [];
  List<CustomerReceipt> receiptRows = [];

  final _receipt = const CustomerReceipt(
    id: 'receipt-7',
    receiptNumber: 'CR-103',
    date: '2025-01-15',
    customerId: 'customer-1',
    invoiceMode: 'Cumulative',
    paymentMode: 'UPI',
    amount: 750,
    remarks: 'Advance payment',
    status: 'Draft',
  );

  @override
  Future<void> loadFormLookups() async {
    customers.assignAll(const [
      LookupOption(id: 'customer-1', label: 'Acme Foods'),
      LookupOption(id: 'customer-2', label: 'Other Foods'),
    ]);
    approvedInvoices.assignAll(invoiceRows);
    receipts.assignAll(receiptRows);
    lookupError.value = '';
  }

  @override
  Future<String?> generateReceiptNumber() async {
    numberCall++;
    if (numberCompleter != null) return numberCompleter!.future;
    if (numberCall > numberResults.length) return null;
    return numberResults[numberCall - 1];
  }

  @override
  Future<CustomerReceipt?> fetchReceipt(String id) async {
    fetchedId = id;
    return id == _receipt.id ? _receipt : null;
  }

  @override
  Future<bool> saveReceipt(
    CustomerReceipt receipt, {
    required bool isEdit,
    List<CustomerReceiptAttachment> attachments = const [],
  }) async {
    saveCalls++;
    savedReceipt = receipt;
    savedAttachments = attachments;
    lastIsEdit = isEdit;
    return false;
  }
}
