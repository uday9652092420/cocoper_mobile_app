import 'package:cocoper_mobile/app/controllers/loading&dispatch/loading_dispatch_controller.dart';
import 'package:cocoper_mobile/app/models/bag_purchase.dart';
import 'package:cocoper_mobile/app/models/loading_dispatch.dart';
import 'package:cocoper_mobile/app/models/lookup_option.dart';
import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/views/dashboard/operations_view.dart';
import 'package:cocoper_mobile/app/views/loading&dispatch/savedloading&dispatches_view.dart';
import 'package:cocoper_mobile/app/views/loading&dispatch/viewloading&dispacth_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const _dispatch = LoadingDispatch(
  id: 'dispatch-1',
  dispatchNumber: 'DSP-001',
  customerId: 'customer-1',
  lorryNumber: 'TN-01-AB-1234',
  driverName: 'Driver One',
  driverMobile: '9876543210',
  dispatchDate: '2026-10-17',
  dispatchStatus: 'Draft',
  lines: [
    LoadingDispatchLine(
      id: 'line-1',
      branchId: 'branch-1',
      date: '2026-10-17',
      itemId: 'item-1',
      bharthi: 'Standard',
      quantity: 10,
      pendingQuantity: 10,
    ),
  ],
);

late _TestLoadingDispatchController _controller;

Future<void> _pumpOperations(WidgetTester tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: '/test_operations',
      getPages: [
        GetPage(name: '/test_operations', page: () => const OperationsView()),
        ...AppPages.routes,
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSavedList(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Loading & Dispatch'));
  await tester.tap(find.text('Loading & Dispatch'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(Get.currentRoute, Routes.savedLoadingDispatches);
}

Finder _formField(String label) => find
    .ancestor(
      of: find.text(label),
      matching: find.byType(TextFormField),
    )
    .first;

Future<void> _selectOption(
  WidgetTester tester,
  String hint,
  String option,
) async {
  await tester.ensureVisible(find.text(hint));
  await tester.tap(find.text(hint), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _fillDraftFields(WidgetTester tester) async {
  await tester.enterText(_formField('Lorry Number'), 'TS-09-AA-1234');
  await tester.enterText(_formField('Driver Name'), 'Test Driver');
  await tester.enterText(_formField('Driver Mobile'), '9876543210');
  await _selectOption(tester, 'Select customer', 'Customer One');
  await _selectOption(tester, 'Select branch', 'Main Branch');
  await _selectOption(tester, 'Select item', 'Coconut');
  await _selectOption(
    tester,
    'Select Gunny Bag (Bharthi)',
    'Jute Bag (JB-01)',
  );
  await tester.enterText(_formField('Quantity'), '25.5');
}

void main() {
  setUp(() {
    Get.testMode = true;
    _controller = _TestLoadingDispatchController();
    Get.put<LoadingDispatchController>(_controller);
  });

  tearDown(Get.reset);

  testWidgets('Operations opens the registered Loading & Dispatch screen',
      (tester) async {
    await _pumpOperations(tester);
    await _openSavedList(tester);

    expect(Get.currentRoute, Routes.savedLoadingDispatches);
    expect(find.byType(SavedLoadingDispatchesView), findsOneWidget);
    expect(find.text('Add New Dispatch'), findsOneWidget);
    expect(find.text('No saved dispatches.'), findsOneWidget);
  });

  testWidgets('new dispatch validates and saves its header and loading line',
      (tester) async {
    await _pumpOperations(tester);
    await _openSavedList(tester);
    await tester.tap(find.text('Add New Dispatch'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.newLoadingDispatch);
    expect(find.text('Dispatch Number'), findsNothing);
    await tester.ensureVisible(find.text('Save Draft'));
    await tester.tap(find.text('Save Draft'));
    await tester.pumpAndSettle();
    expect(find.text('Select a customer.'), findsOneWidget);
    expect(_controller.savedDispatch, isNull);

    await _fillDraftFields(tester);
    await tester.tap(find.text('Save Draft'));
    await tester.pumpAndSettle();

    expect(_controller.savedDispatch?.id, isEmpty);
    expect(_controller.savedDispatch?.customerId, 'customer-1');
    expect(_controller.savedDispatch?.lorryNumber, 'TS-09-AA-1234');
    expect(_controller.savedDispatch?.lines.single.branchId, 'branch-1');
    expect(_controller.savedDispatch?.lines.single.itemId, 'item-1');
    expect(_controller.savedDispatch?.lines.single.quantity, 25.5);
    expect(_controller.savedDispatch?.lines.single.bharthi, 'Jute Bag');
    expect(Get.currentRoute, Routes.savedLoadingDispatches);
  });

  testWidgets('loading lines can be added and removed', (tester) async {
    await _pumpOperations(tester);
    await _openSavedList(tester);
    await tester.tap(find.text('Add New Dispatch'));
    await tester.pumpAndSettle();

    expect(find.text('Loading Line 1'), findsOneWidget);
    await tester.tap(find.text('Add Line'));
    await tester.pumpAndSettle();
    expect(find.text('Loading Line 2'), findsOneWidget);
    await tester.ensureVisible(find.text('Loading Line 2'));
    await tester.tap(find.byTooltip('Remove loading line 2'));
    await tester.pumpAndSettle();
    expect(find.text('Loading Line 2'), findsNothing);
    expect(find.text('Loading Line 1'), findsOneWidget);
  });

  testWidgets('editing dispatch preserves its ID and line IDs', (tester) async {
    _controller.dispatches.assignAll([_dispatch]);
    await _pumpOperations(tester);
    await _openSavedList(tester);
    expect(find.text('DSP-001'), findsOneWidget);
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.editLoadingDispatch);
    expect(find.text('Dispatch Number'), findsNothing);
    await tester.enterText(_formField('Driver Name'), 'Updated Driver');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(_controller.savedDispatch?.id, 'dispatch-1');
    expect(_controller.savedDispatch?.lines.single.id, 'line-1');
    expect(_controller.savedDispatch?.driverName, 'Updated Driver');
    expect(Get.currentRoute, Routes.savedLoadingDispatches);
  });

  testWidgets('view details is read-only and back returns to saved list',
      (tester) async {
    _controller.dispatches.assignAll([_dispatch]);
    await _pumpOperations(tester);
    await _openSavedList(tester);
    expect(find.text('DSP-001'), findsOneWidget);
    await tester.ensureVisible(find.text('View'));
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.viewLoadingDispatch);
    expect(find.byType(ViewLoadingDispatchView), findsOneWidget);
    expect(find.text('DSP-001'), findsOneWidget);
    expect(find.text('Driver One'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Routes.savedLoadingDispatches);
  });

  testWidgets('delete requires confirmation and deletes the selected ID',
      (tester) async {
    _controller.dispatches.assignAll([_dispatch]);
    await _pumpOperations(tester);
    await _openSavedList(tester);
    expect(find.text('DSP-001'), findsOneWidget);
    await tester.ensureVisible(find.text('Delete'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete dispatch?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(_controller.deletedDispatchId, 'dispatch-1');
  });

  test('dispatch search includes customer, number, lorry, and driver fields',
      () {
    _controller.dispatches.assignAll([_dispatch]);

    for (final query in [
      'DSP-001',
      'Customer One',
      'TN-01-AB-1234',
      'Driver One',
      '9876543210',
    ]) {
      _controller.searchQuery.value = query;
      expect(_controller.filteredDispatches, [_dispatch], reason: query);
    }
    _controller.searchQuery.value = 'missing';
    expect(_controller.filteredDispatches, isEmpty);
  });
}

class _TestLoadingDispatchController extends LoadingDispatchController {
  _TestLoadingDispatchController() {
    customers.assignAll(const [
      LookupOption(id: 'customer-1', label: 'Customer One'),
    ]);
    branches.assignAll(const [
      LookupOption(id: 'branch-1', label: 'Main Branch'),
    ]);
    items.assignAll(const [
      LookupOption(id: 'item-1', label: 'Coconut'),
    ]);
    gunnyBags.assignAll(const [
      BagPurchaseLookup(
        id: 'bag-1',
        name: 'Jute Bag',
        code: 'JB-01',
      ),
    ]);
  }

  LoadingDispatch? savedDispatch;
  String? deletedDispatchId;

  @override
  Future<void> loadLookups() async {}

  @override
  Future<void> loadDispatches({bool force = false}) async {}

  @override
  Future<LoadingDispatch?> loadDispatchById(String id) async {
    for (final dispatch in dispatches) {
      if (dispatch.id == id) {
        detail.value = dispatch;
        return dispatch;
      }
    }
    return null;
  }

  @override
  Future<bool> saveDispatch(LoadingDispatch dispatch) async {
    savedDispatch = dispatch;
    return true;
  }

  @override
  Future<bool> deleteDispatch(LoadingDispatch dispatch) async {
    deletedDispatchId = dispatch.id;
    return true;
  }
}
