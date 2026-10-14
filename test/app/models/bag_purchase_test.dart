import 'package:cocoper_mobile/app/models/bag_purchase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses scoped gunny bag lookup fields and wrapped list responses', () {
    final bags = BagPurchaseLookup.decodeGunnyBagResponse({
      'success': true,
      'data': [
        {
          'bag_type_id': 17,
          'bag_name': 'Jute Bag',
          'bag_code': 'JB-01',
          'rate_per_bag': '20',
        },
        {
          'bagTypeId': 'bag-2',
          'bagName': 'Poly Bag',
          'rate_per_bag': null,
        },
        {'bag_name': 'Missing ID'},
        {'bag_type_id': 'bag-3'},
      ],
    });

    expect(bags, isNotNull);
    expect(bags, hasLength(2));
    expect(bags![0].id, '17');
    expect(bags[0].name, 'Jute Bag');
    expect(bags[0].label, 'Jute Bag (JB-01)');
    expect(bags[0].ratePerBag, 20);
    expect(bags[1].id, 'bag-2');
    expect(bags[1].name, 'Poly Bag');
    expect(bags[1].ratePerBag, 0);
    expect(
        BagPurchaseLookup.decodeGunnyBagResponse({'data': 'invalid'}), isNull);
    expect(
      BagPurchaseLookup.decodeGunnyBagResponse({'data': <Object?>[]}),
      equals(<BagPurchaseLookup>[]),
    );
  });

  test('parses bare and nested gunny bag list responses', () {
    final bare = BagPurchaseLookup.decodeGunnyBagResponse([
      {'id': 1, 'name': 'Jute Bag', 'rate_per_bag': 20},
      {'_id': '2', 'gunny_bag_name': 'Poly Bag'},
    ]);
    expect(bare, hasLength(2));
    expect(bare![0].id, '1');
    expect(bare[1].name, 'Poly Bag');

    final nested = BagPurchaseLookup.decodeGunnyBagResponse({
      'items': [
        {'bagId': 'bag-1', 'label': 'Nested Bag', 'ratePerBag': '12.5'},
      ],
    });
    expect(nested, hasLength(1));
    expect(nested!.single.id, 'bag-1');
    expect(nested.single.name, 'Nested Bag');
    expect(nested.single.ratePerBag, 12.5);
  });

  test('parses purchase details and serializes the verified line payload', () {
    final purchase = BagPurchase.fromJson({
      'id': 'purchase-1',
      'purchase_no': 'BP-001',
      'purchase_date': '2026-06-14',
      'supplier_id': 'supplier-1',
      'supplier_name': 'Supplier One',
      'branch_id': 'branch-1',
      'branch_name': 'Main',
      'line_count': 1,
      'total_amount': '20',
      'lines': [
        {
          'id': 'line-1',
          'gunny_bag_id': 'bag-1',
          'gunny_bag_name': 'Jute Bag',
          'quantity': '2',
          'rate': '10',
          'amount': '20',
        },
      ],
    });

    expect(purchase.purchaseNumber, 'BP-001');
    expect(purchase.supplierName, 'Supplier One');
    expect(purchase.branchName, 'Main');
    expect(purchase.totalAmount, 20);
    expect(purchase.lineCount, 1);
    expect(purchase.lines.single.amount, 20);
    expect(purchase.lines.single.toRequestJson(), {
      'gunny_bag_id': 'bag-1',
      'quantity': 2,
      'rate': 10,
    });
  });

  test('parses stored bag type IDs and names when editing purchases', () {
    final line = BagPurchaseLine.fromJson({
      'bag_type_id': 'bag-1',
      'bag_name': 'Jute Bag',
      'quantity': 6000,
      'rate': 20,
    });

    expect(line.gunnyBagId, 'bag-1');
    expect(line.gunnyBagName, 'Jute Bag');
    expect(line.amount, 120000);
  });

  test('reads purchase dates as the business calendar date', () {
    void expectDate(DateTime? date, int year, int month, int day) {
      expect(date, isNotNull);
      expect([date!.year, date.month, date.day], [year, month, day]);
    }

    // Live UAT serialization: the date-only value is stored at midnight in the
    // backend timezone, UTC+02:00 in summer and UTC+01:00 in winter.
    expectDate(
      BagPurchase.parsePurchaseDate('2026-10-13T22:00:00.000Z'),
      2026,
      10,
      14,
    );
    expectDate(
      BagPurchase.parsePurchaseDate('2026-11-19T23:00:00.000Z'),
      2026,
      11,
      20,
    );
    expectDate(
      BagPurchase.parsePurchaseDate('2026-01-14T23:00:00.000Z'),
      2026,
      1,
      15,
    );

    // Date-only and display values are already the business date.
    expectDate(BagPurchase.parsePurchaseDate('2026-10-14'), 2026, 10, 14);
    expectDate(BagPurchase.parsePurchaseDate('14/10/2026'), 2026, 10, 14);
    expectDate(BagPurchase.parsePurchaseDate('4/9/2026'), 2026, 9, 4);

    // Unusable values are reported instead of guessed.
    expect(BagPurchase.parsePurchaseDate(''), isNull);
    expect(BagPurchase.parsePurchaseDate('not a date'), isNull);
    expect(BagPurchase.parsePurchaseDate('2026-02-30'), isNull);
  });

  test('keeps the business date and the raw value for stored records', () {
    final purchase = BagPurchase.fromJson({
      'id': 'purchase-9',
      'purchase_no': 'BP-005',
      'purchase_date': '2026-10-13T22:00:00.000Z',
    });
    expect(purchase.purchaseDate, '2026-10-14');

    final dateOnly = BagPurchase.fromJson({
      'id': 'purchase-10',
      'purchase_no': 'BP-006',
      'purchase_date': '2026-10-14',
    });
    expect(dateOnly.purchaseDate, '2026-10-14');

    // A missing or unusable value is never invented or shifted.
    expect(BagPurchase.fromJson(const {}).purchaseDate, '');
    final unusable = BagPurchase.fromJson({
      'id': 'purchase-11',
      'purchase_date': 'whenever',
    });
    expect(unusable.purchaseDate, 'whenever');
  });
}
