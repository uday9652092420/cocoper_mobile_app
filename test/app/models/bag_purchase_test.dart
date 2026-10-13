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
}
