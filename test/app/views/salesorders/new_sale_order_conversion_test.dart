import 'package:cocoper_mobile/app/controllers/salesorders/sales_order_controller.dart';
import 'package:cocoper_mobile/app/models/lookup_option.dart';
import 'package:cocoper_mobile/app/models/purchase_order.dart';
import 'package:cocoper_mobile/app/models/purchase_order_line.dart';
import 'package:cocoper_mobile/app/models/sales_order_line.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/views/salesorders/newsaleorder_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _StubSalesOrderController extends SalesOrderController {
  _StubSalesOrderController() {
    customers.assignAll(const [
      LookupOption(id: 'customer-1', label: 'Customer One'),
    ]);
  }

  bool createCalled = false;
  List<SalesOrderLine> submittedLines = const [];

  @override
  Future<void> loadLookups() async {}

  @override
  Future<bool> loadSalesOrders({bool showErrors = true}) async => true;

  @override
  Future<String> generateSoNumber() async => 'SO-01';

  @override
  Future<bool> createSalesOrder({
    required String soNumber,
    required String date,
    required String customerId,
    required String remarks,
    required String mode,
    String branchId = '',
    required String sourcePoId,
    required String poNumber,
    required List<SalesOrderLine> lines,
  }) async {
    createCalled = true;
    submittedLines = lines;
    lastCreatedSalesOrderId = 'so-01';
    lastCreatedSalesOrderReference = soNumber;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  late _StubSalesOrderController controller;

  const purchaseOrder = PurchaseOrder(
    id: 'po-01',
    poNumber: 'PO-01',
    supplierId: 'supplier-1',
    branchId: 'branch-1',
    date: '2026-10-15',
    mode: SalesOrderController.modeTonage,
    status: 'Approved',
    lines: [
      PurchaseOrderLine(
        itemId: 'item-1',
        itemName: 'Coconut',
        quantity: 10,
        purchaseAmount: 200,
        pieces: 10,
      ),
    ],
  );

  setUp(() {
    Get.testMode = true;
    controller = _StubSalesOrderController();
    Get.put<SalesOrderController>(controller);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, (call) async => true);
  });

  tearDown(() {
    Get.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, null);
  });

  Future<void> openConversion(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Get.toNamed<void>(
                Routes.newSaleOrder,
                arguments: purchaseOrder,
              ),
              child: const Text('Open conversion'),
            ),
          ),
        ),
        getPages: [
          GetPage<dynamic>(
            name: Routes.newSaleOrder,
            page: () => const NewSaleOrderView(),
          ),
          GetPage<dynamic>(
            name: Routes.savedSalesOrders,
            page: () => const Scaffold(body: Text('Saved Sales Orders')),
          ),
        ],
      ),
    );
    await tester.tap(find.text('Open conversion'));
    await tester.pumpAndSettle();
  }

  Finder salePriceField() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Sale Price *',
      description: 'Sale Price field',
    );
  }

  Future<void> selectCustomer(WidgetTester tester) async {
    final customerDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    customerDropdown.onChanged?.call('customer-1');
    await tester.pumpAndSettle();
  }

  testWidgets('converted line leaves Sale Price unset and blocks saving', (
    tester,
  ) async {
    await openConversion(tester);

    expect(tester.widget<TextField>(salePriceField()).controller!.text, '');
    expect(find.text('Enter Sale Price'), findsOneWidget);
    await selectCustomer(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(controller.createCalled, isFalse);
    expect(Get.currentRoute, Routes.newSaleOrder);
  });

  testWidgets('entered Sale Price is sent separately and recalculates amount', (
    tester,
  ) async {
    await openConversion(tester);
    await selectCustomer(tester);
    await tester.enterText(salePriceField(), '6000');
    await tester.pumpAndSettle();

    expect(find.text('₹60000.00/-'), findsNWidgets(2));
    expect(find.text('₹59800.00/-'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(controller.createCalled, isTrue);
    expect(controller.submittedLines.single.salePrice, 6000);
    expect(controller.submittedLines.single.saleAmount, 60000);
    expect(controller.submittedLines.single.baseCost, 6000);
    expect(Get.currentRoute, '/');
  });
}
