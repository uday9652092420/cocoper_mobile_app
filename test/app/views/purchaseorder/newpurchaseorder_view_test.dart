import 'package:cocoper_mobile/app/controllers/purchaseorder/purchase_order_controller.dart';
import 'package:cocoper_mobile/app/controllers/salesorders/sales_order_controller.dart';
import 'package:cocoper_mobile/app/models/lookup_option.dart';
import 'package:cocoper_mobile/app/models/purchase_order.dart';
import 'package:cocoper_mobile/app/models/purchase_order_line.dart';
import 'package:cocoper_mobile/app/views/purchaseorder/newpurchaseorder_view.dart';
import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const _items = <LookupOption>[
  LookupOption(id: 'item-1', label: 'Coconut Bondam'),
];

const _suppliers = <LookupOption>[
  LookupOption(id: 'supplier-1', label: 'Kerala Cocos'),
];

const _branches = <LookupOption>[
  LookupOption(id: 'branch-1', label: 'Warangal'),
];

class _StubPurchaseOrderController extends PurchaseOrderController {
  _StubPurchaseOrderController() {
    items.assignAll(_items);
    suppliers.assignAll(_suppliers);
    branches.assignAll(_branches);
  }

  @override
  Future<void> loadLookups() async {}

  @override
  Future<void> loadPurchaseOrders() async {}

  @override
  Future<String> prepareCreate() async => 'TPO-01';

  PurchaseOrder? authoritativeOrder;
  bool saveSucceeds = true;
  bool approvalSucceeds = true;
  bool failNextDetailFetch = false;
  int detailFetchCount = 0;
  final updateStatuses = <String>[];

  @override
  Future<PurchaseOrder?> fetchPurchaseOrderById(String id) async {
    detailFetchCount++;
    if (failNextDetailFetch) {
      failNextDetailFetch = false;
      return null;
    }
    return authoritativeOrder;
  }

  @override
  Future<bool> updatePurchaseOrder({
    required String id,
    required String status,
    required String poNumber,
    required String supplierId,
    required String branchId,
    required String date,
    required String mode,
    required String remarks,
    required List<PurchaseOrderLine> lines,
  }) async {
    updateStatuses.add(status);
    final succeeds = status == 'Approved' ? approvalSucceeds : saveSucceeds;
    if (!succeeds) return false;

    authoritativeOrder = PurchaseOrder(
      id: id,
      poNumber: poNumber,
      supplierId: supplierId,
      branchId: branchId,
      date: date,
      mode: mode,
      remarks: remarks,
      status: status,
      lines: lines,
    );
    return true;
  }
}

class _StubSalesOrderController extends SalesOrderController {
  @override
  Future<void> loadLookups() async {}

  @override
  Future<void> loadSalesOrders() async {}

  @override
  Future<String> generateSoNumber() async => 'TSO-01';
}

late _StubPurchaseOrderController _stub;
late _StubSalesOrderController _salesOrderStub;

Future<void> _pumpForm(WidgetTester tester) async {
  await tester.pumpWidget(const GetMaterialApp(home: NewPurchaseOrderView()));
  await tester.pumpAndSettle();
}

PurchaseOrder _testOrder({String status = 'Draft'}) {
  return PurchaseOrder(
    id: 'po-1',
    poNumber: 'TPO-01',
    supplierId: 'supplier-1',
    branchId: 'branch-1',
    date: '2026-10-15',
    mode: 'tonage',
    status: status,
    lines: const [
      PurchaseOrderLine(
        itemId: 'item-1',
        quantity: 2,
        purchaseCost: 100,
        purchaseAmount: 200,
        amount: 200,
      ),
    ],
  );
}

Future<void> _pumpEditForm(WidgetTester tester, PurchaseOrder order) async {
  await tester.pumpWidget(
    GetMaterialApp(home: NewPurchaseOrderView(order: order)),
  );
  await tester.pumpAndSettle();
}

/// Finds the input that sits directly under [label] on the form.
Finder _fieldUnder(String label) {
  final column =
      find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
  return find.descendant(of: column, matching: find.byType(TextField)).first;
}

/// Global x of the caret for the field matched by [field].
double _caretX(WidgetTester tester, Finder field, {int? offset}) {
  final state = tester.state<EditableTextState>(
    find.descendant(of: field, matching: find.byType(EditableText)).first,
  );
  final caret = state.renderEditable.getLocalRectForCaret(
    TextPosition(
      offset: offset ?? state.textEditingValue.selection.extentOffset,
    ),
  );
  return state.renderEditable
      .localToGlobal(caret.center, ancestor: state.renderEditable)
      .dx;
}

void main() {
  setUp(() {
    Get.testMode = true;
    _stub = _StubPurchaseOrderController();
    Get.put<PurchaseOrderController>(_stub);
    _salesOrderStub = _StubSalesOrderController();
    Get.put<SalesOrderController>(_salesOrderStub);
  });

  tearDown(Get.reset);

  testWidgets('purchase order data entry fields are left aligned and LTR', (
    tester,
  ) async {
    await _pumpForm(tester);

    for (final label in [
      'PO Number',
      'Remarks',
      'Qty (Tons)',
      'Disc (Kgs)',
      'Cost',
      'Pieces',
    ]) {
      final field = tester.widget<TextField>(_fieldUnder(label));
      expect(field.textAlign, TextAlign.start, reason: '$label alignment');
      expect(
        field.textDirection,
        TextDirection.ltr,
        reason: '$label direction',
      );
    }
  });

  testWidgets('an empty line item field keeps the caret on the left', (
    tester,
  ) async {
    await _pumpForm(tester);

    final qtyField = _fieldUnder('Qty (Tons)');
    await tester.ensureVisible(qtyField);
    await tester.pumpAndSettle();

    // Tapping the far right of an empty field must still start at the left.
    final rect = tester.getRect(qtyField);
    await tester.tapAt(Offset(rect.right - 8, rect.center.dy));
    await tester.pumpAndSettle();

    expect(
      _caretX(tester, qtyField),
      lessThan(rect.center.dx),
      reason: 'entry must start from the left',
    );
  });

  testWidgets('typed digits grow to the right from the left edge', (
    tester,
  ) async {
    await _pumpForm(tester);

    final qtyField = _fieldUnder('Qty (Tons)');
    await tester.ensureVisible(qtyField);
    await tester.pumpAndSettle();
    await tester.enterText(qtyField, '2548');
    await tester.pumpAndSettle();

    final rect = tester.getRect(qtyField);
    expect(tester.widget<TextField>(qtyField).controller!.text, '2548');
    expect(
      _caretX(tester, qtyField, offset: 0),
      lessThan(rect.center.dx),
      reason: 'the value must begin at the left edge of the field',
    );
  });

  testWidgets('edit advances to approval only after the server confirms save', (
    tester,
  ) async {
    _stub.authoritativeOrder = _testOrder();
    await _pumpEditForm(tester, _testOrder());

    expect(_stub.detailFetchCount, 1);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Convert to Sales Order'), findsNothing);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(_stub.updateStatuses, ['Draft']);
    expect(_stub.detailFetchCount, 2);
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Convert to Sales Order'), findsNothing);
    expect(
        tester.widget<TextField>(_fieldUnder('Qty (Tons)')).readOnly, isFalse);
  });

  testWidgets('failed save and approval do not advance the workflow', (
    tester,
  ) async {
    _stub.authoritativeOrder = _testOrder();
    _stub.saveSucceeds = false;
    await _pumpEditForm(tester, _testOrder());

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(_stub.detailFetchCount, 1);

    _stub.saveSucceeds = true;
    _stub.approvalSucceeds = false;
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(_stub.updateStatuses, ['Draft', 'Draft', 'Approved']);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Convert to Sales Order'), findsNothing);
    expect(
        tester.widget<TextField>(_fieldUnder('Qty (Tons)')).readOnly, isFalse);
  });

  testWidgets('confirmed approval locks the authoritative order', (
    tester,
  ) async {
    _stub.authoritativeOrder = _testOrder();
    await _pumpEditForm(tester, _testOrder());
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(_stub.authoritativeOrder!.status, 'Approved');
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Convert to Sales Order'), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .every((field) => field.readOnly),
      isTrue,
    );
    expect(
      tester
          .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .every((field) => field.onChanged == null),
      isTrue,
    );
  });

  testWidgets('failed approval refresh locks stale draft until retried', (
    tester,
  ) async {
    _stub.authoritativeOrder = _testOrder();
    await _pumpEditForm(tester, _testOrder());
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    _stub.failNextDetailFetch = true;
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(_stub.authoritativeOrder!.status, 'Approved');
    expect(find.text('Retry loading Purchase Order'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Convert to Sales Order'), findsNothing);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .every((field) => field.readOnly),
      isTrue,
    );

    await tester.tap(find.text('Retry loading Purchase Order'));
    await tester.pumpAndSettle();

    expect(find.text('Retry loading Purchase Order'), findsNothing);
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Convert to Sales Order'), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .every((field) => field.readOnly),
      isTrue,
    );
  });

  testWidgets('reopened approved order is refreshed and read-only', (
    tester,
  ) async {
    _stub.authoritativeOrder = _testOrder(status: ' approved ');
    await _pumpEditForm(tester, _testOrder());

    expect(_stub.detailFetchCount, 1);
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Convert to Sales Order'), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .every((field) => field.readOnly),
      isTrue,
    );
  });

  testWidgets('unknown persisted status remains read-only', (tester) async {
    _stub.authoritativeOrder = _testOrder(status: ' Awaiting Review ');
    await _pumpEditForm(tester, _testOrder());

    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Convert to Sales Order'), findsNothing);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .every((field) => field.readOnly),
      isTrue,
    );
    expect(
      tester
          .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .every((field) => field.onChanged == null),
      isTrue,
    );
  });

  testWidgets('approved order opens the registered Sales Order draft route', (
    tester,
  ) async {
    final approvedOrder = _testOrder(status: ' Approved ');
    _stub.authoritativeOrder = approvedOrder;
    await tester.pumpWidget(
      GetMaterialApp(
        home: NewPurchaseOrderView(order: approvedOrder),
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Convert to Sales Order'), findsOneWidget);
    await tester.tap(find.text('Convert to Sales Order'));
    await tester.pumpAndSettle();

    expect(find.text('Sales Line Items'), findsOneWidget);
    expect(
      tester.widgetList<TextField>(find.byType(TextField)).any(
            (field) => field.controller?.text == 'Converted from TPO-01',
          ),
      isTrue,
      reason: 'the source PO number must be passed into the Sales Order form',
    );
  });
}
