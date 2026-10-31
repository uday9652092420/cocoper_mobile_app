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
        'totalAmount': '145.00',
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
      expect(order.lines.single.salePrice, 50);
      expect(order.lines.single.saleAmount, 145);
      expect(order.lineTotalAmount, 145);
      expect(order.totalAmount, 145);
    });

    test('preserves persisted total and explicit zero sale amounts', () {
      final order = SalesOrder.fromJson({
        'total_amount': '0',
        'lines': [
          {'saleAmount': 0, 'amount': 42},
        ],
      });

      expect(order.totalAmount, 0);
      expect(order.lineTotalAmount, 0);
      expect(order.lines.single.effectiveSaleAmount, 0);
    });

    test('uses line total only when the backend total is absent', () {
      final order = SalesOrder.fromJson({
        'lines': [
          {'amount': '42'},
        ],
      });

      expect(order.totalAmount, 42);
      expect(order.lineTotalAmount, 42);
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
          salePrice: 20,
          saleAmount: 200,
          amount: 200,
        ),
      ],
    );

    final payload = order.toCreateRequestJson();

    expect(payload['sourcePOId'], 'purchase-order-1');
    expect(payload.containsKey('sourcePoId'), isFalse);
    expect(payload['poNumber'], 'COP-01');
    expect(payload['branchId'], 'branch-1');
    expect(payload['totalAmount'], 200);
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

  test('maps persisted organization and branch IDs from both API casings', () {
    final order = SalesOrder.fromJson({
      'id': 'sales-order-scoped',
      'organization_id': 'organization-1',
      'branch_id': 'branch-1',
    });

    expect(order.organizationId, 'organization-1');
    expect(order.branchId, 'branch-1');
    expect(
      order.toUpdateRequestJson(),
      containsPair('organizationId', 'organization-1'),
    );
    expect(
      order.toUpdateRequestJson(),
      isNot(contains('branchId')),
    );
  });

  test('maps branch ID from the nested branch relation', () {
    final order = SalesOrder.fromJson({
      'id': 'sales-order-nested-branch',
      'branch': <dynamic, dynamic>{'id': 'branch-2'},
    });

    expect(order.branchId, 'branch-2');
    expect(
      order.toUpdateRequestJson(),
      isNot(contains('branchId')),
    );
  });

  test('preserves Sales Order line IDs in update JSON', () {
    final line = SalesOrderLine.fromJson({
      'id': 'SOL-1',
      'itemId': 'item-1',
      'quantity': 50,
      'discount': 15,
      'saleCost': 6000,
    });

    expect(line.id, 'SOL-1');
    expect(line.toJson()['id'], 'SOL-1');
  });

  test('maps Sale Price to the legacy saleCost API field', () {
    final line = SalesOrderLine.fromJson({
      'itemId': 'item-1',
      'quantity': 4,
      'discount': 0.5,
      'pieces': 8,
      'actualQuantity': 3.5,
      'baseCost': 12,
      'saleCost': 31.25,
      'saleAmount': 109.38,
      'amount': 109.38,
    });

    expect(line.salePrice, 31.25);
    expect(line.baseCost, 12);
    expect(line.effectiveSaleAmount, 109.38);
    expect(line.toJson()['saleCost'], 31.25);
    expect(line.toJson().containsKey('salePrice'), isFalse);
  });
}
