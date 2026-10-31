import 'package:cocoper_mobile/app/controllers/salesorders/sales_order_controller.dart';
import 'package:cocoper_mobile/app/models/lookup_option.dart';
import 'package:cocoper_mobile/app/models/sales_order.dart';
import 'package:cocoper_mobile/app/models/sales_order_line.dart';
import 'package:cocoper_mobile/app/views/salesorders/viewsalesorder_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _SalesOrderControllerFake extends SalesOrderController {
  _SalesOrderControllerFake(this.order);

  final SalesOrder order;

  @override
  Future<void> loadLookups() async {}

  @override
  Future<SalesOrder?> fetchSalesOrderById(String id) async => order;
}

void main() {
  tearDown(Get.reset);

  testWidgets('shows saved sales fields and resolves names from lookups',
      (tester) async {
    final controller = _SalesOrderControllerFake(
      const SalesOrder(
        id: 'so-1',
        soNumber: 'SO-1',
        customerId: 'customer-1',
        sourcePoId: 'po-1',
        poNumber: 'PO-1',
        status: 'Draft',
        savedTotalAmount: 356.5,
        lines: [
          SalesOrderLine(
            itemId: 'item-1',
            quantity: 12,
            discount: 0.5,
            pieces: 4,
            baseCost: 7.13,
            actualQuantity: 11.5,
            salePrice: 31,
            saleAmount: 356.5,
            amount: 356.5,
          ),
        ],
      ),
    );
    controller.customers.add(
      const LookupOption(id: 'customer-1', label: 'Customer One'),
    );
    controller.items.add(
      const LookupOption(id: 'item-1', label: 'Item One'),
    );
    Get.put<SalesOrderController>(controller);

    await tester.pumpWidget(
      const GetMaterialApp(
        home: ViewSalesOrderView(orderId: 'so-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customer One'), findsOneWidget);
    expect(find.text('Item One'), findsOneWidget);
    expect(find.text('PO-1'), findsOneWidget);
    expect(find.textContaining('Actual quantity: 11.5'), findsOneWidget);
    expect(find.textContaining('Sale Price: ₹31/-'), findsOneWidget);
    expect(find.textContaining('Sale amount: ₹356.5/-'), findsOneWidget);
    expect(find.text('₹356.5/-'), findsNWidgets(2));
  });
}
