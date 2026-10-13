import 'package:cocoper_mobile/app/controllers/bagpurchase/bag_purchase_controller.dart';
import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:cocoper_mobile/app/views/dashboard/operations_view.dart';
import 'package:cocoper_mobile/app/views/bagpurchase/newbagpurchase_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  late _TestBagPurchaseController controller;

  setUp(() {
    Get.testMode = true;
    controller = _TestBagPurchaseController();
    Get.put<BagPurchaseController>(controller);
  });

  tearDown(Get.reset);

  testWidgets('Operations opens saved purchases and New opens the form', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/test_operations',
        getPages: [
          GetPage(
            name: '/test_operations',
            page: () => const OperationsView(),
          ),
          ...AppPages.routes,
        ],
      ),
    );

    await tester.tap(find.text('Bag Purchase').first);
    await tester.pumpAndSettle();
    expect(find.text('Saved Bag Purchases'), findsOneWidget);

    await tester.tap(find.text('New Bag Purchase').first);
    await tester.pumpAndSettle();
    expect(find.text('New Bag Purchase'), findsWidgets);
    expect(find.byType(NewBagPurchaseView), findsOneWidget);
    expect(find.text('Bag purchase lines'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Bag Purchases'), findsOneWidget);
    expect(controller.loadPurchaseCalls, 2);
  });
}

class _TestBagPurchaseController extends BagPurchaseController {
  int loadPurchaseCalls = 0;

  @override
  Future<void> loadPurchases() async {
    loadPurchaseCalls++;
  }

  @override
  Future<void> loadLookups({String branchId = ''}) async {}
}
