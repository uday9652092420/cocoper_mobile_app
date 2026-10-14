import 'package:cocoper_mobile/app/controllers/bagpurchase/bag_purchase_controller.dart';
import 'package:cocoper_mobile/app/models/bag_purchase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/bag_purchase_fixtures.dart';

/// Serves canned saved-list payloads so the controller state machine can be
/// exercised without a network round trip.
class _StubBagPurchaseController extends BagPurchaseController {
  _StubBagPurchaseController(this.respond);

  final Future<List<BagPurchase>> Function(String organizationId) respond;
  final requestedOrganizations = <String>[];

  @override
  Future<List<BagPurchase>> fetchPurchaseList(String organizationId) {
    requestedOrganizations.add(organizationId);
    return respond(organizationId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'organizationId': 'org-1'});
  });

  test('list request is organization-scoped and never sends a branch scope', () {
    final query = BagPurchaseController.purchaseListQueryParameters('org-1');
    expect(query, {'organizationId': 'org-1'});
    expect(query.containsKey('branchId'), isFalse);

    final headers = BagPurchaseController.purchaseListHeaders('org-1');
    expect(headers, {'x-organization-id': 'org-1'});
    expect(headers.containsKey('x-branch-id'), isFalse);
  });

  test('decodes the verified backend envelope and record shape', () {
    final purchases = BagPurchaseController.decodePurchaseList(
      bagPurchaseListResponse,
    );

    expect(purchases, hasLength(3));
    expect(
      purchases.map((purchase) => purchase.purchaseNumber),
      ['BP-003', 'BP-002', 'BP-001'],
    );

    final latest = purchases.first;
    expect(latest.id, '9a0ec645-d776-409f-9305-1627ab017b21');
    // The backend serializes the date-only value at its own midnight; the model
    // keeps the selected business date.
    expect(latest.purchaseDate, '2026-10-14');
    expect(latest.supplierId, 'SUP-1788498304343');
    expect(latest.supplierCode, 'RS-02');
    // The backend pads the supplier name; the parser trims it.
    expect(latest.supplierName, 'Kerala Cocos Suppliers Pvt Ltd');
    expect(latest.remarks, 'Good Services');
    expect(latest.lineCount, 1);
    expect(latest.totalAmount, 750);
    expect(latest.branchId, '4039b460-48dd-47d4-bcd1-c2b1b27473b1');
    expect(
      latest.organizationId,
      '711212e2-0af4-48a0-9dcc-c27908e0bc57',
    );
    expect(latest.lines.single.gunnyBagId, 'GB-1790760444200');
    expect(latest.lines.single.gunnyBagName, 'Polyster Bag');
    expect(latest.lines.single.quantity, 50);
    expect(latest.lines.single.rate, 15);
    expect(latest.lines.single.amount, 750);

    final oldest = purchases.last;
    expect(oldest.purchaseNumber, 'BP-001');
    expect(oldest.supplierName, 'Godavari Cocos Suppliers Pvt Ltd');
    expect(oldest.totalAmount, 72000);
  });

  test('decodes the serialized purchase dates to the business dates', () {
    final purchases = BagPurchaseController.decodePurchaseList(
      bagPurchaseListResponse,
    );

    // Live UAT values: 2026-10-13T22:00Z, 2026-09-03T22:00Z, 2026-08-31T22:00Z.
    expect(
      purchases.map((purchase) => purchase.purchaseDate),
      ['2026-10-14', '2026-09-04', '2026-09-01'],
    );
  });

  test('decodes bare arrays, items wrappers, and empty successes', () {
    expect(
      BagPurchaseController.decodePurchaseList(bagPurchaseRecordsPayload),
      hasLength(3),
    );
    expect(
      BagPurchaseController.decodePurchaseList({
        'items': bagPurchaseRecordsPayload,
      }),
      hasLength(3),
    );
    expect(
      BagPurchaseController.decodePurchaseList({'data': <Object?>[]}),
      isEmpty,
    );
  });

  test('rejects an envelope without a list instead of reporting no records', () {
    expect(
      () => BagPurchaseController.decodePurchaseList({'success': true}),
      throwsException,
    );
    expect(
      () => BagPurchaseController.decodePurchaseList('not json'),
      throwsException,
    );
  });

  test('loads the saved records for the signed-in organization', () async {
    final controller = _StubBagPurchaseController(
      (_) async => decodedBagPurchases(),
    );

    await controller.loadPurchases();

    expect(controller.requestedOrganizations, ['org-1']);
    expect(controller.hasListError.value, isFalse);
    expect(controller.listError.value, isEmpty);
    expect(controller.purchases, hasLength(3));
    expect(controller.filteredPurchases, hasLength(3));
  });

  test('filters the loaded records by the supported search fields', () async {
    final controller = _StubBagPurchaseController(
      (_) async => decodedBagPurchases(),
    );
    await controller.loadPurchases();

    controller.searchQuery.value = 'BP-002';
    expect(controller.filteredPurchases.single.purchaseNumber, 'BP-002');

    controller.searchQuery.value = 'godavari';
    expect(controller.filteredPurchases.single.purchaseNumber, 'BP-001');

    controller.searchQuery.value = 'RS-02';
    expect(
      controller.filteredPurchases.map((purchase) => purchase.purchaseNumber),
      ['BP-003', 'BP-002'],
    );

    controller.searchQuery.value = 'nothing matches';
    expect(controller.filteredPurchases, isEmpty);
  });

  test('treats a successful empty list as empty, not as an error', () async {
    final controller = _StubBagPurchaseController(
      (_) async => const <BagPurchase>[],
    );

    await controller.loadPurchases();

    expect(controller.hasListError.value, isFalse);
    expect(controller.listError.value, isEmpty);
    expect(controller.purchases, isEmpty);
    expect(controller.filteredPurchases, isEmpty);
  });

  test('surfaces a request failure instead of showing no purchases', () async {
    final controller = _StubBagPurchaseController(
      (_) async => throw Exception('Bag purchases request failed (HTTP 500)'),
    );

    await controller.loadPurchases();

    expect(controller.hasListError.value, isTrue);
    expect(
      controller.listError.value,
      contains('Bag purchases request failed (HTTP 500)'),
    );
    expect(controller.purchases, isEmpty);
  });
}
