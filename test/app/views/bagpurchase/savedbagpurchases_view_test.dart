import 'package:cocoper_mobile/app/controllers/bagpurchase/bag_purchase_controller.dart';
import 'package:cocoper_mobile/app/models/bag_purchase.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/views/bagpurchase/savedbagpurchases_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/bag_purchase_fixtures.dart';

/// Serves the captured list payload through the production decode path.
class _StubBagPurchaseController extends BagPurchaseController {
  _StubBagPurchaseController({this.payload, this.failure});

  final Object? payload;
  final Object? failure;
  final requestedOrganizations = <String>[];
  int loadCalls = 0;

  @override
  Future<List<BagPurchase>> fetchPurchaseList(String organizationId) async {
    requestedOrganizations.add(organizationId);
    loadCalls++;
    if (failure != null) throw failure!;
    return BagPurchaseController.decodePurchaseList(payload);
  }
}

Future<void> _pumpSavedPurchases(
  WidgetTester tester,
  BagPurchaseController controller,
) async {
  Get.put<BagPurchaseController>(controller);
  await tester.pumpWidget(
    const GetMaterialApp(home: SavedBagPurchasesView()),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({'organizationId': 'org-1'});
  });

  tearDown(Get.reset);

  testWidgets('renders the saved purchases returned by the backend', (
    tester,
  ) async {
    final controller = _StubBagPurchaseController(
      payload: bagPurchaseListResponse,
    );

    await _pumpSavedPurchases(tester, controller);

    expect(controller.requestedOrganizations, ['org-1']);
    expect(find.text('3 purchases'), findsOneWidget);
    expect(find.text('BP-003'), findsOneWidget);
    expect(find.text('BP-002'), findsOneWidget);
    expect(find.text('BP-001'), findsOneWidget);
    expect(find.text('Good Services'), findsNWidgets(3));
    expect(find.text('No bag purchases found.'), findsNothing);
  });

  testWidgets('shows the saved business date, not the serialized UTC day', (
    tester,
  ) async {
    final controller = _StubBagPurchaseController(
      payload: bagPurchaseListResponse,
    );

    await _pumpSavedPurchases(tester, controller);

    // Live UAT values are 2026-10-13T22:00Z, 2026-09-03T22:00Z, 2026-08-31T22:00Z.
    expect(find.text('14/10/2026'), findsOneWidget);
    expect(find.text('4/9/2026'), findsOneWidget);
    expect(find.text('1/9/2026'), findsOneWidget);
    expect(find.textContaining('13/10/2026'), findsNothing);
    expect(find.textContaining('3/9/2026'), findsNothing);
    expect(find.textContaining('31/8/2026'), findsNothing);
  });

  testWidgets('keeps the empty state for a successful empty response', (
    tester,
  ) async {
    final controller = _StubBagPurchaseController(
      payload: <String, dynamic>{'success': true, 'data': <Object?>[]},
    );

    await _pumpSavedPurchases(tester, controller);

    expect(find.text('0 purchases'), findsOneWidget);
    expect(find.text('No bag purchases found.'), findsOneWidget);
  });

  testWidgets('shows the error state with a working retry on failure', (
    tester,
  ) async {
    final controller = _StubBagPurchaseController(
      failure: Exception('Unable to load bag purchases (HTTP 500).'),
    );

    await _pumpSavedPurchases(tester, controller);

    expect(
      find.text('Unable to load bag purchases (HTTP 500).'),
      findsOneWidget,
    );
    expect(find.text('No bag purchases found.'), findsNothing);
    expect(controller.loadCalls, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(controller.loadCalls, 2);
    expect(
      find.text('Unable to load bag purchases (HTTP 500).'),
      findsOneWidget,
    );
  });

  testWidgets('filters the displayed purchases and count by search', (
    tester,
  ) async {
    final controller = _StubBagPurchaseController(
      payload: bagPurchaseListResponse,
    );

    await _pumpSavedPurchases(tester, controller);

    await tester.enterText(find.byType(TextField).first, 'BP-002');
    await tester.pumpAndSettle();

    expect(find.text('1 purchases'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('BP-002'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('BP-001'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('BP-003'),
      ),
      findsNothing,
    );
  });

  testWidgets('refresh reloads the saved purchases', (tester) async {
    final controller = _StubBagPurchaseController(
      payload: bagPurchaseListResponse,
    );

    await _pumpSavedPurchases(tester, controller);
    expect(controller.loadCalls, 1);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(controller.loadCalls, 2);
    expect(find.text('3 purchases'), findsOneWidget);
    expect(find.text('BP-001'), findsOneWidget);
  });

  testWidgets('opening a saved purchase uses its backend id and branch', (
    tester,
  ) async {
    final controller = _StubBagPurchaseController(
      payload: bagPurchaseListResponse,
    );
    BagPurchase? opened;

    Get.put<BagPurchaseController>(controller);
    await tester.pumpWidget(
      GetMaterialApp(
        home: const SavedBagPurchasesView(),
        getPages: [
          GetPage(
            name: Routes.viewBagPurchase,
            page: () {
              opened = Get.arguments as BagPurchase?;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final viewButton = find.byTooltip('View').first;
    await tester.ensureVisible(viewButton);
    await tester.tap(viewButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(opened, isNotNull);
    expect(opened!.id, '9a0ec645-d776-409f-9305-1627ab017b21');
    expect(opened!.purchaseNumber, 'BP-003');
    expect(opened!.branchId, '4039b460-48dd-47d4-bcd1-c2b1b27473b1');
    expect(controller.loadCalls, 1);

    // The saved list is refreshed once the record screen is closed.
    Get.back<void>();
    await tester.pumpAndSettle();

    expect(controller.loadCalls, 2);
  });
}
