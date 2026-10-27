import 'package:cocoper_mobile/app/models/sales_order.dart';
import 'package:cocoper_mobile/app/models/sales_order_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sales Order response mapping', () {
    test('maps nested customer and line item values', () {
      final order = SalesOrder.fromJson({
        'id': 'sales-order-1',
        'so_number': 'SO-1',
        'date': '2026-10-16',
        'customer': <dynamic, dynamic>{
          'id': 'customer-1',
          'name': 'Customer One',
        },
        'source_po_id': 'purchase-order-1',
        'lines': [
          <dynamic, dynamic>{
            'item': <dynamic, dynamic>{
              '_id': 'item-1',
              'name': 'Coconut',
            },
            'quantity': '3',
            'discount': '0.1',
            'pieces': '12',
            'base_cost': '20',
            'actual_quantity': '2.9',
            'sale_cost': '50',
            'sale_amount': '145',
          },
        ],
      });

      expect(order.id, 'sales-order-1');
      expect(order.soNumber, 'SO-1');
      expect(order.customerId, 'customer-1');
      expect(order.customerName, 'Customer One');
      expect(order.sourcePoId, 'purchase-order-1');
      expect(order.lines, hasLength(1));
      expect(order.lines.single.itemId, 'item-1');
      expect(order.lines.single.itemName, 'Coconut');
      expect(order.lines.single.quantity, 3);
      expect(order.lines.single.discount, 0.1);
      expect(order.lines.single.baseCost, 20);
      expect(order.lines.single.actualQuantity, 2.9);
      expect(order.lines.single.saleCost, 50);
      expect(order.lines.single.saleAmount, 145);
    });
  });

  test('conversion payload preserves the original purchase-order reference',
      () {
    const order = SalesOrder(
      soNumber: 'COP-SO-01',
      date: '2026-10-26',
      customerId: 'customer-1',
      remarks: 'Converted from COP-01',
      status: 'Draft',
      mode: 'tonage',
      branchId: 'branch-1',
      sourcePoId: 'purchase-order-1',
      poNumber: 'COP-01',
      lines: [
        SalesOrderLine(
          itemId: 'item-1',
          quantity: 10,
          actualQuantity: 10,
          saleCost: 20,
          saleAmount: 200,
          amount: 200,
        ),
      ],
    );

    final payload = order.toCreateRequestJson();

    expect(payload['sourcePoId'], 'purchase-order-1');
    expect(payload['poNumber'], 'COP-01');
    expect(payload['branchId'], 'branch-1');
    expect(payload['lines'], hasLength(1));
    expect(payload.containsKey('organizationId'), isFalse);
  });

  test('parses the created Sales Order from the response envelope', () {
    final order = SalesOrder.fromCreateResponse({
      'success': true,
      'data': {
        'id': 'sales-order-1',
        'soNumber': 'SO-02',
        'sourcePoId': 'purchase-order-1',
      },
    });

    expect(order?.id, 'sales-order-1');
    expect(order?.soNumber, 'SO-02');
    expect(order?.sourcePoId, 'purchase-order-1');
  });

  test('maps canonical backend sourcePOId into the mobile conversion link', () {
    final order = SalesOrder.fromJson({
      'id': 'sales-order-2',
      'soNumber': 'SO-03',
      'sourcePOId': 'purchase-order-2',
    });

    expect(order.sourcePoId, 'purchase-order-2');
  });
}
