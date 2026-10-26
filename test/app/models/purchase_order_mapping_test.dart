import 'package:cocoper_mobile/app/models/purchase_order.dart';
import 'package:cocoper_mobile/app/models/purchase_order_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes a mobile purchase order with organization and branch scope',
      () {
    const order = PurchaseOrder(
      poNumber: 'COP-01',
      supplierId: 'supplier-1',
      branchId: 'branch-1',
      date: '2026-10-26',
      remarks: 'Purchase',
      status: 'Draft',
      mode: 'tonage',
      lines: [
        PurchaseOrderLine(
          itemId: 'item-1',
          quantity: 10,
          discount: 1,
          piecesPercentage: 0,
          pieces: 2,
          baseCost: 20,
          actualQuantity: 10,
          purchaseCost: 20,
          purchaseAmount: 200,
          amount: 200,
        ),
      ],
    );

    expect(order.toRequestJson(organizationId: 'org-1'), {
      'poNumber': 'COP-01',
      'organizationId': 'org-1',
      'supplierId': 'supplier-1',
      'branchId': 'branch-1',
      'date': '2026-10-26',
      'remarks': 'Purchase',
      'status': 'Draft',
      'mode': 'tonage',
      'lines': [
        {
          'itemId': 'item-1',
          'quantity': 10,
          'discount': 1,
          'piecesPercentage': 0,
          'pieces': 2,
          'baseCost': 20,
          'actualQuantity': 10,
          'purchaseCost': 20,
          'purchaseAmount': 200,
          'amount': 200,
          'rate': null,
        },
      ],
    });
  });

  test('maps a saved purchase order response including its generated ID', () {
    final order = PurchaseOrder.fromJson({
      'id': 'po-1',
      'poNumber': 'COP-01',
      'organizationId': 'org-1',
      'branchId': 'branch-1',
      'supplierId': 'supplier-1',
      'date': '2026-10-26',
      'status': 'Draft',
      'mode': 'tonage',
      'lines': [
        {'itemId': 'item-1', 'quantity': 10, 'purchaseCost': 20},
      ],
    });

    expect(order.id, 'po-1');
    expect(order.organizationId, 'org-1');
    expect(order.branchId, 'branch-1');
    expect(order.supplierId, 'supplier-1');
    expect(order.lines.single.itemId, 'item-1');
    expect(order.lines.single.quantity, 10);
  });
}
