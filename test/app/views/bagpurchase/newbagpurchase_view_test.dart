import 'package:cocoper_mobile/app/controllers/bagpurchase/bag_purchase_controller.dart';
import 'package:cocoper_mobile/app/models/bag_purchase.dart';
import 'package:cocoper_mobile/app/views/bagpurchase/newbagpurchase_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bags = <BagPurchaseLookup>[
  BagPurchaseLookup(
    id: 'bag-1',
    name: 'Jute Bag',
    code: 'JB-01',
    ratePerBag: 20,
  ),
  BagPurchaseLookup(id: 'bag-2', name: 'Poly Bag', ratePerBag: 15),
];

const _suppliers = <BagPurchaseLookup>[
  BagPurchaseLookup(id: 'supplier-1', name: 'Kerala Cocos'),
];

const _branches = <BagPurchaseLookup>[
  BagPurchaseLookup(id: 'branch-1', name: 'Warangal', code: 'RB-02'),
];

class _StubBagPurchaseController extends BagPurchaseController {
  _StubBagPurchaseController() {
    suppliers.assignAll(_suppliers);
    branches.assignAll(_branches);
    gunnyBags.assignAll(_bags);
  }

  /// Date value that reached the create/update request.
  String? submittedDate;

  @override
  Future<void> loadLookups({String branchId = ''}) async {}

  @override
  Future<bool> createPurchase({
    required String date,
    required String supplierId,
    required String branchId,
    required String remarks,
    required List<BagPurchaseLine> lines,
    bool saveAndNew = false,
  }) async {
    submittedDate = date;
    return true;
  }

  @override
  Future<bool> updatePurchase({
    required String id,
    required String date,
    required String supplierId,
    required String branchId,
    required String remarks,
    required List<BagPurchaseLine> lines,
  }) async {
    submittedDate = date;
    return true;
  }
}

late _StubBagPurchaseController stub;

Future<void> _pumpForm(WidgetTester tester, {BagPurchase? purchase}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      home: NewBagPurchaseView(purchase: purchase),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the form on top of a root route so the form can pop itself after save.
Future<void> _pumpFormOnRoute(
  WidgetTester tester, {
  BagPurchase? purchase,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: '/form',
      getPages: [
        GetPage(
          name: '/',
          page: () => const Scaffold(body: SizedBox.shrink()),
        ),
        GetPage(
          name: '/form',
          page: () => NewBagPurchaseView(purchase: purchase),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'organizationId': 'org-1',
      'selectedBranchId': 'branch-1',
    });
    stub = _StubBagPurchaseController();
    Get.put<BagPurchaseController>(stub);
  });

  tearDown(Get.reset);

  testWidgets('new purchase form lists gunny bags and prefills the bag rate', (
    tester,
  ) async {
    await _pumpForm(tester);
    expect(
        find.text(
            'Unable to load gunny bags. Check your connection and retry.'),
        findsNothing);

    await tester.tap(find.text('Select bag'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Jute Bag (JB-01)'), findsWidgets);

    await tester.tap(find.text('Jute Bag (JB-01)').last);
    await tester.pumpAndSettle();

    final rateField =
        tester.widgetList<TextField>(find.byType(TextField)).where(
              (field) => field.controller?.text == '20',
            );
    expect(rateField, isNotEmpty);
  });

  testWidgets('edit form keeps the stored bag type and quantity', (
    tester,
  ) async {
    final purchase = BagPurchase.fromJson({
      'id': 'purchase-1',
      'purchase_no': 'BP-002',
      'purchase_date': '2026-09-04',
      'supplier_id': 'supplier-1',
      'branch_id': 'branch-1',
      'lines': [
        {
          'id': 'line-1',
          'bag_type_id': 'bag-1',
          'bag_name': 'Jute Bag',
          'quantity': 6000,
          'rate': 20,
        },
      ],
    });

    await _pumpForm(tester, purchase: purchase);

    expect(find.text('Edit Bag Purchase'), findsOneWidget);
    expect(find.text('Jute Bag (JB-01)'), findsWidgets);
    expect(find.text('₹120,000'), findsWidgets);
    expect(find.textContaining('Total Quantity: 6,000'), findsOneWidget);
  });

  testWidgets('edit form keeps the saved business date and resubmits it', (
    tester,
  ) async {
    final purchase = BagPurchase.fromJson({
      'id': 'purchase-1',
      'purchase_no': 'BP-003',
      'purchase_date': '2026-10-13T22:00:00.000Z',
      'supplier_id': 'supplier-1',
      'branch_id': 'branch-1',
      'remarks': 'Good Services',
      'lines': [
        {
          'id': 'line-1',
          'gunny_bag_id': 'bag-1',
          'gunny_bag_name': 'Jute Bag',
          'quantity': 50,
          'rate': 15,
          'amount': 750,
        },
      ],
    });

    await _pumpFormOnRoute(tester, purchase: purchase);

    // The serialized 2026-10-13T22:00Z must prefill as the saved date.
    expect(find.text('14/10/2026'), findsOneWidget);
    expect(find.text('13/10/2026'), findsNothing);

    await tester.ensureVisible(find.text('Update'));
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(stub.submittedDate, '2026-10-14');
  });

  testWidgets('new purchase submits the displayed date as a date-only value', (
    tester,
  ) async {
    final today = DateTime.now();
    final displayedDate = DateFormat('dd/MM/yyyy').format(today);
    final requestDate = DateFormat('yyyy-MM-dd').format(today);

    await _pumpFormOnRoute(tester);
    expect(find.text(displayedDate), findsOneWidget);

    await tester.tap(find.text('Select supplier'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kerala Cocos').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select bag'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jute Bag (JB-01)').last);
    await tester.pumpAndSettle();

    final quantityField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == '0' &&
          (widget.controller?.text ?? '').isEmpty,
    );
    expect(quantityField, findsOneWidget);
    await tester.enterText(quantityField, '10');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(stub.submittedDate, requestDate);
  });
}
