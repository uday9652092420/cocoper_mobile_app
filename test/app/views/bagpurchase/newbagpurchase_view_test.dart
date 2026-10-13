import 'package:cocoper_mobile/app/controllers/bagpurchase/bag_purchase_controller.dart';
import 'package:cocoper_mobile/app/models/bag_purchase.dart';
import 'package:cocoper_mobile/app/views/bagpurchase/newbagpurchase_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
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

  @override
  Future<void> loadLookups({String branchId = ''}) async {}
}

Future<void> _pumpForm(WidgetTester tester, {BagPurchase? purchase}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      home: NewBagPurchaseView(purchase: purchase),
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
    Get.put<BagPurchaseController>(_StubBagPurchaseController());
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
}
