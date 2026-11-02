import 'dart:async';

import 'package:cocoper_mobile/app/controllers/purchaseinvoice/purchase_invoice_controller.dart';
import 'package:cocoper_mobile/app/models/lookup_option.dart';
import 'package:cocoper_mobile/app/models/purchase_invoice.dart';
import 'package:cocoper_mobile/app/models/purchase_invoice_line.dart';
import 'package:cocoper_mobile/app/models/purchase_order.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/views/purchaseinvoice/purchaseinvoicedetail_view.dart';
import 'package:cocoper_mobile/app/views/purchaseinvoice/newpurchaseinvoice_view.dart';
import 'package:cocoper_mobile/app/views/purchaseinvoice/savedpurchaseinvoices_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _StubPurchaseInvoiceController extends PurchaseInvoiceController {
  _StubPurchaseInvoiceController() {
    branches.assignAll(const [
      LookupOption(id: 'branch-1', label: 'First Branch'),
      LookupOption(id: 'branch-2', label: 'Second Branch'),
    ]);
    suppliers.assignAll(const [
      LookupOption(id: 'supplier-1', label: 'Supplier One'),
    ]);
    items.assignAll(const [LookupOption(id: 'item-1', label: 'Coconut')]);
  }

  Completer<void>? lookupsCompleter;
  List<PurchaseOrder> purchaseOrdersForTest = const [];
  PurchaseInvoice? invoiceToApprove;
  int approvalCount = 0;

  @override
  Future<void> loadLookups() async {
    await lookupsCompleter?.future;
    purchaseOrders.assignAll(purchaseOrdersForTest);
  }

  @override
  Future<String> prepareCreate() async => 'RPI-01';

  @override
  Future<void> loadPurchaseInvoices() async {}

  @override
  Future<bool> approvePurchaseInvoice(String id) async {
    approvalCount++;
    final invoice = invoiceToApprove;
    if (invoice == null || invoice.id != id) return false;
    purchaseInvoices.assignAll([
      PurchaseInvoice(
        id: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        supplierId: invoice.supplierId,
        supplierName: invoice.supplierName,
        branchId: invoice.branchId,
        branchName: invoice.branchName,
        purchaseOrderId: invoice.purchaseOrderId,
        date: invoice.date,
        mode: invoice.mode,
        status: 'Approved',
        lines: invoice.lines,
      ),
    ]);
    return true;
  }
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

  testWidgets('edit invoice keeps its PO selected while lookups load', (
    tester,
  ) async {
    final controller = _StubPurchaseInvoiceController()
      ..lookupsCompleter = Completer<void>()
      ..purchaseOrdersForTest = const [
        PurchaseOrder(
          id: 'po-1',
          poNumber: 'PO-01',
          supplierId: 'supplier-1',
          supplierName: 'Supplier One',
          branchId: 'branch-1',
          status: 'Approved',
          purchaseOrderInvoiceStatus: 'true',
        ),
      ];
    Get.put<PurchaseInvoiceController>(controller);

    await tester.pumpWidget(
      const GetMaterialApp(
        home: NewPurchaseInvoiceView(
          invoice: PurchaseInvoice(
            id: 'invoice-1',
            invoiceNumber: 'RPI-19',
            supplierId: 'supplier-1',
            branchId: 'branch-1',
            purchaseOrderId: 'po-1',
            date: '02/11/2026',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('po-1'), findsOneWidget);

    controller.lookupsCompleter!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PO-01 — Supplier One'), findsOneWidget);
  });

  testWidgets('approving an edited invoice opens its read-only saved view', (
    tester,
  ) async {
    const invoice = PurchaseInvoice(
      id: 'invoice-1',
      invoiceNumber: 'RPI-19',
      supplierId: 'supplier-1',
      supplierName: 'Supplier One',
      branchId: 'branch-1',
      branchName: 'First Branch',
      date: '02/11/2026',
      status: 'Draft',
      lines: [
        PurchaseInvoiceLine(
          itemId: 'item-1',
          itemName: 'Coconut',
          quantityTons: 1,
          purchaseCost: 100,
          purchaseAmount: 100,
        ),
      ],
    );
    final controller = _StubPurchaseInvoiceController()
      ..invoiceToApprove = invoice
      ..purchaseInvoices.assignAll([invoice]);
    Get.put<PurchaseInvoiceController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        home: const NewPurchaseInvoiceView(invoice: invoice),
        getPages: [
          GetPage<dynamic>(
            name: Routes.purchaseInvoices,
            page: () => const SavedPurchaseInvoicesView(),
          ),
          GetPage<dynamic>(
            name: Routes.purchaseInvoiceDetail,
            page: () => const PurchaseInvoiceDetailView(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(controller.approvalCount, 1);
    expect(Get.currentRoute, Routes.purchaseInvoices);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Delete'), findsNothing);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Routes.purchaseInvoiceDetail);
    expect(find.text('RPI-19'), findsOneWidget);
  });
}
