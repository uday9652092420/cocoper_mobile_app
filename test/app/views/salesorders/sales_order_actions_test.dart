import 'package:cocoper_mobile/app/controllers/salesorders/sales_order_controller.dart';
import 'package:cocoper_mobile/app/models/sales_order.dart';
import 'package:cocoper_mobile/app/models/sales_order_line.dart';
import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/views/salesorders/savedsalesorders_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _StubSalesOrderController extends SalesOrderController {
  List<SalesOrder> orders = [];
  bool failListLoad = false;
  final fetchIds = <String>[];

  @override
  Future<void> loadLookups() async {}

  @override
  Future<void> loadSalesOrders() async {
    isLoadingList.value = true;
    hasListError.value = failListLoad;
    if (!failListLoad) salesOrders.assignAll(orders);
    isLoadingList.value = false;
  }

  @override
  Future<SalesOrder?> fetchSalesOrderById(String id) async {
    fetchIds.add(id);
    hasListError.value = failListLoad;
    if (failListLoad) return null;
    for (final order in orders) {
      if (order.id == id) {
        return order;
      }
    }
    return null;
  }
}

SalesOrder _order({
  required String id,
  required String status,
  String mode = '',
  List<SalesOrderLine> lines = const [],
}) {
  return SalesOrder(
    id: id,
    soNumber: 'SO-$id',
    date: '2026-10-15',
    customerId: 'customer-$id',
    customerName: 'Customer $id',
    status: status,
    mode: mode,
    remarks: 'Test remarks',
    poNumber: 'PO-$id',
    lines: lines,
  );
}

late _StubSalesOrderController _controller;

Future<void> _pumpSavedOrders(WidgetTester tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      home: const SavedSalesOrdersView(),
      getPages: AppPages.routes,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    Get.testMode = true;
    _controller = _StubSalesOrderController();
    Get.put<SalesOrderController>(_controller, permanent: true);
  });

  tearDown(Get.reset);

  testWidgets('draft actions show View and Edit but not unverified Delete', (
    tester,
  ) async {
    _controller.orders = [_order(id: '1', status: 'Draft')];
    await _pumpSavedOrders(tester);

    expect(find.byTooltip('View Sales Order'), findsOneWidget);
    expect(find.byTooltip('Edit Sales Order'), findsOneWidget);
    expect(find.byTooltip('Delete unavailable'), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    final editIcon = tester.widget<Icon>(find.byIcon(Icons.edit_outlined));
    expect(editIcon.size, 19);
    expect(editIcon.color, const Color(0xFF2D8135));
    final viewIcon =
        tester.widget<Icon>(find.byIcon(Icons.visibility_outlined));
    expect(viewIcon.size, 19);
    expect(viewIcon.color, const Color(0xFF2D8135));
  });

  testWidgets('approved order remains read-only and hides Edit and Delete', (
    tester,
  ) async {
    _controller.orders = [_order(id: '1', status: ' Approved ')];
    await _pumpSavedOrders(tester);

    expect(find.byTooltip('View Sales Order'), findsOneWidget);
    expect(find.byTooltip('Edit Sales Order'), findsNothing);
    expect(find.byTooltip('Delete unavailable'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('unknown status does not expose Draft-only Edit or Delete', (
    tester,
  ) async {
    _controller.orders = [_order(id: '1', status: 'Awaiting Review')];
    await _pumpSavedOrders(tester);

    expect(find.byTooltip('View Sales Order'), findsOneWidget);
    expect(find.byTooltip('Edit Sales Order'), findsNothing);
    expect(find.byTooltip('Delete unavailable'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('missing status is shown as Unknown and fails closed', (
    tester,
  ) async {
    _controller.orders = [_order(id: 'missing-status', status: '')];
    await _pumpSavedOrders(tester);

    expect(find.text('Unknown'), findsOneWidget);
    expect(find.byTooltip('Edit Sales Order'), findsNothing);
    expect(find.byTooltip('Delete unavailable'), findsNothing);
  });

  testWidgets('Edit opens refreshed Sales Order data by selected ID', (
    tester,
  ) async {
    _controller.orders = [
      _order(id: 'one', status: 'Draft'),
      _order(
        id: 'two',
        status: 'Draft',
        mode: SalesOrderController.modeTonage,
        lines: const [
          SalesOrderLine(
            itemId: 'item-2',
            itemName: 'Coconut Bondam',
            quantity: 3000,
            discount: 100,
            actualQuantity: 2900,
            saleCost: 45,
            saleAmount: 130500,
            pieces: 10,
          ),
        ],
      ),
    ];
    await _pumpSavedOrders(tester);

    await tester.tap(find.byTooltip('Edit Sales Order').last);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.editSalesOrder);
    expect(_controller.salesOrders.map((order) => order.id), contains('two'));
    expect(_controller.fetchIds, contains('two'));
    expect(find.text('Edit Sales Order'), findsOneWidget);
    final fieldValues = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((field) => field.controller?.text)
        .toList();
    expect(fieldValues, contains('SO-two'));
    expect(find.text('Customer two'), findsOneWidget);
    expect(find.text('Test remarks'), findsOneWidget);
    expect(find.text('Coconut Bondam'), findsOneWidget);
    expect(fieldValues, contains('3000'));
    expect(find.text('2,900'), findsOneWidget);
    expect(find.text('₹130,500'), findsOneWidget);
    expect(find.text('Approved Sales Orders are read-only.'), findsNothing);
    expect(find.textContaining('saving is unavailable'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(
      find.text(
        'Saving is disabled until the backend update contract is verified.',
      ),
      findsOneWidget,
    );
    expect(find.byType(OutlinedButton), findsNothing);
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .any((field) => field.enabled),
      isTrue,
    );
  });

  testWidgets('approved order opens read-only without mutation controls', (
    tester,
  ) async {
    _controller.orders = [_order(id: 'locked', status: 'Approved')];
    await _pumpSavedOrders(tester);
    Get.toNamed<void>(Routes.editSalesOrder, arguments: 'locked');
    await tester.pumpAndSettle();

    expect(find.text('Approved Sales Orders are read-only.'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Approve'), findsNothing);
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .every((field) => !field.enabled),
      isTrue,
    );
  });

  testWidgets('editing a supported line recalculates derived amount', (
    tester,
  ) async {
    _controller.orders = [
      _order(
        id: 'editable',
        status: 'Draft',
        mode: SalesOrderController.modeTonage,
        lines: const [
          SalesOrderLine(
            itemId: 'item-1',
            itemName: 'Coconut',
            quantity: 3000,
            discount: 100,
            actualQuantity: 2900,
            saleCost: 45,
            saleAmount: 130500,
            pieces: 10,
          ),
        ],
      ),
    ];
    await _pumpSavedOrders(tester);
    await tester.tap(find.byTooltip('Edit Sales Order'));
    await tester.pumpAndSettle();

    final quantityField = find.byWidgetPredicate(
      (widget) => widget is TextFormField && widget.controller?.text == '3000',
    );
    expect(quantityField, findsOneWidget);
    final quantityWidget = tester.widget<TextFormField>(quantityField);
    expect(quantityWidget.enabled, isTrue);
    quantityWidget.controller!.text = '4000';
    quantityWidget.onChanged?.call('4000');
    await tester.pump();

    expect(find.text('₹163,636.36'), findsOneWidget);
    quantityWidget.controller!.text = '0';
    quantityWidget.onChanged?.call('0');
    expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
    await tester.pump();
    expect(quantityWidget.controller!.text, '0');
    expect(find.text('Must be greater than 0'), findsOneWidget);
  });

  testWidgets('unknown order status fails closed in the edit route', (
    tester,
  ) async {
    _controller.orders = [_order(id: 'unknown', status: 'Awaiting Review')];
    await _pumpSavedOrders(tester);
    Get.toNamed<void>(Routes.editSalesOrder, arguments: 'unknown');
    await tester.pumpAndSettle();

    expect(
        find.textContaining('not a verified editable Draft'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .every((field) => !field.enabled),
      isTrue,
    );
  });

  testWidgets('view resolves the selected order by ID from refreshed list', (
    tester,
  ) async {
    _controller.orders = [
      _order(id: 'first', status: 'Draft'),
      _order(id: 'second', status: 'Approved'),
    ];
    await _pumpSavedOrders(tester);

    await tester.tap(find.byTooltip('View Sales Order').last);
    await tester.pumpAndSettle();

    expect(
        _controller.salesOrders.map((order) => order.id), contains('second'));
    expect(find.text('SO-second'), findsOneWidget);
    expect(find.text('Customer second'), findsOneWidget);
    expect(find.text('SO-first'), findsNothing);
  });

  testWidgets('failed list load does not expose stale order details', (
    tester,
  ) async {
    _controller.orders = [_order(id: 'first', status: 'Draft')];
    await _pumpSavedOrders(tester);

    _controller.failListLoad = true;
    await tester.tap(find.byTooltip('View Sales Order'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load this Sales Order.'), findsOneWidget);
    expect(find.text('SO-first'), findsNothing);
  });
}
