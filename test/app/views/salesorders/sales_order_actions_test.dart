import 'package:cocoper_mobile/app/controllers/salesorders/sales_order_controller.dart';
import 'package:cocoper_mobile/app/models/sales_order.dart';
import 'package:cocoper_mobile/app/models/sales_order_line.dart';
import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/services/mobile_app_permissions.dart';
import 'package:cocoper_mobile/app/views/salesorders/savedsalesorders_view.dart';
import 'package:cocoper_mobile/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _StubSalesOrderController extends SalesOrderController {
  List<SalesOrder> orders = [];
  bool failListLoad = false;
  bool saveSucceeds = true;
  bool deleteSucceeds = true;
  int updateCount = 0;
  int approveCount = 0;
  int deleteCount = 0;
  Map<String, Object?>? lastUpdate;
  Map<String, String>? lastApprovalScope;
  final fetchIds = <String>[];

  @override
  Future<void> loadLookups() async {}

  @override
  Future<bool> loadSalesOrders({bool showErrors = true}) async {
    isLoadingList.value = true;
    hasListError.value = failListLoad;
    if (!failListLoad) salesOrders.assignAll(orders);
    isLoadingList.value = false;
    return !failListLoad;
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

  @override
  Future<bool> updateSalesOrder({
    required String id,
    required String status,
    String organizationId = '',
    String branchId = '',
    required String soNumber,
    required String date,
    required String customerId,
    required String remarks,
    required String mode,
    required List<SalesOrderLine> lines,
  }) async {
    updateCount++;
    lastUpdate = {
      'id': id,
      'status': status,
      'organizationId': organizationId,
      'branchId': branchId,
      'soNumber': soNumber,
      'date': date,
      'customerId': customerId,
      'remarks': remarks,
      'mode': mode,
      'lines': lines,
    };
    return saveSucceeds;
  }

  @override
  Future<bool> approveSalesOrder({
    required String id,
    required String status,
    String organizationId = '',
    String branchId = '',
    required String soNumber,
    required String date,
    required String customerId,
    required String remarks,
    required String mode,
    required List<SalesOrderLine> lines,
  }) async {
    approveCount++;
    lastApprovalScope = {
      'organizationId': organizationId,
      'branchId': branchId,
    };
    if (!saveSucceeds) return false;
    orders = orders
        .map(
          (order) => order.id != id
              ? order
              : SalesOrder(
                  id: order.id,
                  soNumber: order.soNumber,
                  date: order.date,
                  organizationId: order.organizationId,
                  customerId: order.customerId,
                  customerName: order.customerName,
                  branchId: order.branchId,
                  remarks: order.remarks,
                  status: 'Approved',
                  mode: order.mode,
                  sourcePoId: order.sourcePoId,
                  poNumber: order.poNumber,
                  savedTotalAmount: order.savedTotalAmount,
                  lines: order.lines,
                ),
        )
        .toList();
    return true;
  }

  @override
  Future<bool> deleteSalesOrder(String id) async {
    deleteCount++;
    if (!deleteSucceeds) return false;
    orders.removeWhere((order) => order.id == id);
    salesOrders.removeWhere((order) => order.id == id);
    return true;
  }
}

SalesOrder _order({
  required String id,
  required String status,
  String organizationId = '',
  String branchId = '',
  String mode = '',
  List<SalesOrderLine> lines = const [],
}) {
  return SalesOrder(
    id: id,
    soNumber: 'SO-$id',
    date: '2026-10-15',
    customerId: 'customer-$id',
    customerName: 'Customer $id',
    organizationId: organizationId,
    branchId: branchId,
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
    MobileAppPermissions.current = const MobileAppPermissions(
      mobileAppLogin: true,
      mobileAppLabourAttendance: false,
      modulePermissions: {
        'sales-order.edit',
        'sales-order.delete',
        'sales-order.approve',
      },
      hasModulePermissions: true,
    );
    _controller = _StubSalesOrderController();
    Get.put<SalesOrderController>(_controller, permanent: true);
  });

  tearDown(() {
    MobileAppPermissions.current = null;
    Get.reset();
  });

  testWidgets('draft order with permissions shows View, Edit and Delete', (
    tester,
  ) async {
    _controller.orders = [_order(id: '1', status: 'Draft')];
    await _pumpSavedOrders(tester);

    expect(find.byTooltip('View Sales Order'), findsOneWidget);
    expect(find.byTooltip('Edit Sales Order'), findsOneWidget);
    expect(find.byTooltip('Delete Sales Order'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    final editIcon = tester.widget<Icon>(find.byIcon(Icons.edit_outlined));
    expect(editIcon.size, 19);
    expect(editIcon.color, AppColors.primaryLight);
    final viewIcon =
        tester.widget<Icon>(find.byIcon(Icons.visibility_outlined));
    expect(viewIcon.size, 19);
    expect(viewIcon.color, AppColors.primaryLight);
  });

  testWidgets('approved order displays View only', (
    tester,
  ) async {
    _controller.orders = [_order(id: '1', status: ' Approved ')];
    await _pumpSavedOrders(tester);

    expect(find.byTooltip('View Sales Order'), findsOneWidget);
    expect(find.byTooltip('Edit Sales Order'), findsNothing);
    expect(find.byTooltip('Delete Sales Order'), findsNothing);
    expect(find.byTooltip('Delete Sales Order'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('unknown status exposes View only', (
    tester,
  ) async {
    _controller.orders = [_order(id: '1', status: 'Awaiting Review')];
    await _pumpSavedOrders(tester);

    expect(find.byTooltip('View Sales Order'), findsOneWidget);
    expect(find.byTooltip('Edit Sales Order'), findsNothing);
    expect(find.byTooltip('Delete Sales Order'), findsNothing);
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
    expect(find.byTooltip('Delete Sales Order'), findsNothing);
  });

  testWidgets('missing edit permission hides only Edit', (tester) async {
    MobileAppPermissions.current = const MobileAppPermissions(
      mobileAppLogin: true,
      mobileAppLabourAttendance: false,
      modulePermissions: {'sales-order.delete'},
      hasModulePermissions: true,
    );
    _controller.orders = [_order(id: 'delete-only', status: 'Draft')];
    await _pumpSavedOrders(tester);

    expect(find.byTooltip('View Sales Order'), findsOneWidget);
    expect(find.byTooltip('Edit Sales Order'), findsNothing);
    expect(find.byTooltip('Delete Sales Order'), findsOneWidget);
  });

  testWidgets('missing delete permission hides only Delete', (tester) async {
    MobileAppPermissions.current = const MobileAppPermissions(
      mobileAppLogin: true,
      mobileAppLabourAttendance: false,
      modulePermissions: {'sales-order.edit'},
      hasModulePermissions: true,
    );
    _controller.orders = [_order(id: 'edit-only', status: 'Draft')];
    await _pumpSavedOrders(tester);

    expect(find.byTooltip('View Sales Order'), findsOneWidget);
    expect(find.byTooltip('Edit Sales Order'), findsOneWidget);
    expect(find.byTooltip('Delete Sales Order'), findsNothing);
  });

  testWidgets('missing Sales Order action catalog does not hide Draft actions',
      (tester) async {
    MobileAppPermissions.current = const MobileAppPermissions(
      mobileAppLogin: true,
      mobileAppLabourAttendance: false,
      modulePermissions: {'purchase-order.read'},
      hasModulePermissions: true,
    );
    _controller.orders = [_order(id: 'legacy-actions', status: 'Draft')];
    await _pumpSavedOrders(tester);

    expect(find.byTooltip('View Sales Order'), findsOneWidget);
    expect(find.byTooltip('Edit Sales Order'), findsOneWidget);
    expect(find.byTooltip('Delete Sales Order'), findsOneWidget);
  });

  testWidgets('delete requires confirmation and deletes selected order', (
    tester,
  ) async {
    _controller.orders = [_order(id: 'delete-me', status: 'Draft')];
    await _pumpSavedOrders(tester);

    await tester.tap(find.byTooltip('Delete Sales Order'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Sales Order'), findsOneWidget);
    expect(
      find.text('Are you sure you want to delete SO-delete-me?'),
      findsOneWidget,
    );
    expect(_controller.deleteCount, 0);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(_controller.deleteCount, 1);
    expect(_controller.salesOrders, isEmpty);
    expect(find.byTooltip('Delete Sales Order'), findsNothing);
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
            actualQuantity: 2900.4,
            salePrice: 45,
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
    expect(find.text('2,900.4'), findsNothing);
    expect(find.text('₹130,500'), findsOneWidget);
    expect(find.text('Approved Sales Orders are read-only.'), findsNothing);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .any((field) => field.enabled),
      isTrue,
    );
  });

  testWidgets('successful Sales Order save returns to the saved list', (
    tester,
  ) async {
    _controller.orders = [
      _order(
        id: 'save-me',
        status: 'Draft',
        organizationId: 'organization-1',
        branchId: 'branch-1',
        mode: SalesOrderController.modeTonage,
        lines: const [
          SalesOrderLine(
            itemId: 'item-1',
            itemName: 'Coconut',
            quantity: 3000,
            actualQuantity: 3000,
            salePrice: 45,
            saleAmount: 135000,
            pieces: 10,
          ),
        ],
      ),
    ];
    await _pumpSavedOrders(tester);
    await tester.tap(find.byTooltip('Edit Sales Order'));
    await tester.pumpAndSettle();

    final salePrice = find.ancestor(
      of: find.text('Sale Price *'),
      matching: find.byType(TextFormField),
    );
    tester.widget<TextFormField>(salePrice).controller!.text = '50';
    tester.widget<TextFormField>(salePrice).onChanged?.call('50');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(_controller.updateCount, 1);
    expect(_controller.lastUpdate!['organizationId'], 'organization-1');
    expect(_controller.lastUpdate!['branchId'], 'branch-1');
    final updatedLines =
        _controller.lastUpdate!['lines'] as List<SalesOrderLine>;
    expect(updatedLines.single.salePrice, 50);
    expect(Get.currentRoute, Routes.savedSalesOrders);
    expect(find.text('SAVED SALES ORDERS'), findsOneWidget);
  });

  testWidgets('failed Sales Order save remains on the edit form', (
    tester,
  ) async {
    _controller.saveSucceeds = false;
    _controller.orders = [
      _order(
        id: 'save-fails',
        status: 'Draft',
        mode: SalesOrderController.modeTonage,
        lines: const [
          SalesOrderLine(
            itemId: 'item-1',
            itemName: 'Coconut',
            quantity: 3000,
            actualQuantity: 3000,
            salePrice: 45,
            saleAmount: 135000,
            pieces: 10,
          ),
        ],
      ),
    ];
    await _pumpSavedOrders(tester);
    await tester.tap(find.byTooltip('Edit Sales Order'));
    await tester.pumpAndSettle();

    final salePrice = find.ancestor(
      of: find.text('Sale Price *'),
      matching: find.byType(TextFormField),
    );
    final salePriceField = tester.widget<TextFormField>(salePrice);
    salePriceField.controller!.text = '48';
    salePriceField.onChanged?.call('48');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(_controller.updateCount, 1);
    expect(Get.currentRoute, Routes.editSalesOrder);
    expect(find.text('Edit Sales Order'), findsOneWidget);
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .any((field) => field.controller?.text == '48'),
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

  testWidgets('draft edit screen shows fixed Approve and Save actions', (
    tester,
  ) async {
    _controller.orders = [
      _order(
        id: 'approve-me',
        status: 'Draft',
        mode: SalesOrderController.modeTonage,
        lines: const [
          SalesOrderLine(
            itemId: 'item-1',
            itemName: 'Coconut',
            quantity: 3000,
            actualQuantity: 3000,
            salePrice: 45,
            saleAmount: 135000,
            pieces: 10,
          ),
        ],
      ),
    ];
    await _pumpSavedOrders(tester);
    await tester.tap(find.byTooltip('Edit Sales Order'));
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    final actionColumn = tester.widget<Column>(
      find
          .ancestor(
            of: find.text('Save Changes'),
            matching: find.byType(Column),
          )
          .first,
    );
    expect(actionColumn.mainAxisSize, MainAxisSize.min);
    expect(
      tester.widgetList<ElevatedButton>(find.byType(ElevatedButton)).length,
      1,
    );
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('transactions.sales permission shows both Draft actions', (
    tester,
  ) async {
    MobileAppPermissions.current = const MobileAppPermissions(
      mobileAppLogin: true,
      mobileAppLabourAttendance: false,
      modulePermissions: {'transactions.sales'},
      hasModulePermissions: true,
    );
    _controller.orders = [
      _order(
        id: 'legacy-sales-permission',
        status: 'Draft',
        mode: SalesOrderController.modeTonage,
        lines: const [
          SalesOrderLine(
            itemId: 'item-1',
            quantity: 10,
            actualQuantity: 10,
            salePrice: 25,
          ),
        ],
      ),
    ];
    await _pumpSavedOrders(tester);
    await tester.tap(find.byTooltip('Edit Sales Order'));
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });

  testWidgets('canceling approval confirmation sends no request', (
    tester,
  ) async {
    _controller.orders = [
      _order(
        id: 'cancel-approval',
        status: 'Draft',
        mode: SalesOrderController.modeTonage,
        lines: const [
          SalesOrderLine(
            itemId: 'item-1',
            quantity: 10,
            actualQuantity: 10,
            salePrice: 25,
          ),
        ],
      ),
    ];
    await _pumpSavedOrders(tester);
    await tester.tap(find.byTooltip('Edit Sales Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Approve Sales Order?'), findsOneWidget);
    expect(
      find.text('Are you sure you want to approve this Sales Order?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(_controller.approveCount, 0);
    expect(Get.currentRoute, Routes.editSalesOrder);
  });

  testWidgets('confirmed approval returns to the list as Approved', (
    tester,
  ) async {
    _controller.orders = [
      _order(
        id: 'approved-now',
        status: 'Draft',
        organizationId: 'organization-1',
        branchId: 'branch-1',
        mode: SalesOrderController.modeTonage,
        lines: const [
          SalesOrderLine(
            itemId: 'item-1',
            quantity: 10,
            actualQuantity: 10,
            salePrice: 25,
          ),
        ],
      ),
    ];
    await _pumpSavedOrders(tester);
    await tester.tap(find.byTooltip('Edit Sales Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(_controller.approveCount, 1);
    expect(_controller.lastApprovalScope, {
      'organizationId': 'organization-1',
      'branchId': 'branch-1',
    });
    expect(Get.currentRoute, Routes.savedSalesOrders);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.byTooltip('View Sales Order'), findsOneWidget);
    expect(find.byTooltip('Edit Sales Order'), findsNothing);
    expect(find.byTooltip('Delete Sales Order'), findsNothing);

    Get.toNamed<void>(Routes.editSalesOrder, arguments: 'approved-now');
    await tester.pumpAndSettle();
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets('failed approval keeps Draft Edit and Delete actions', (
    tester,
  ) async {
    _controller.saveSucceeds = false;
    _controller.orders = [
      _order(
        id: 'approval-fails',
        status: 'Draft',
        mode: SalesOrderController.modeTonage,
        lines: const [
          SalesOrderLine(
            itemId: 'item-1',
            quantity: 10,
            actualQuantity: 10,
            salePrice: 25,
          ),
        ],
      ),
    ];
    await _pumpSavedOrders(tester);
    await tester.tap(find.byTooltip('Edit Sales Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(_controller.approveCount, 1);
    expect(Get.currentRoute, Routes.editSalesOrder);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Approved Sales Orders are read-only.'), findsNothing);
    Get.back<void>();
    await tester.pumpAndSettle();

    expect(find.text('Draft'), findsOneWidget);
    expect(find.byTooltip('View Sales Order'), findsOneWidget);
    expect(find.byTooltip('Edit Sales Order'), findsOneWidget);
    expect(find.byTooltip('Delete Sales Order'), findsOneWidget);
  });

  testWidgets('edit action is hidden without edit permission', (tester) async {
    MobileAppPermissions.current = const MobileAppPermissions(
      mobileAppLogin: true,
      mobileAppLabourAttendance: false,
      modulePermissions: {'sales-order.approve'},
      hasModulePermissions: true,
    );
    _controller.orders = [_order(id: 'no-edit', status: 'Draft')];
    await _pumpSavedOrders(tester);

    expect(find.byTooltip('View Sales Order'), findsOneWidget);
    expect(find.byTooltip('Edit Sales Order'), findsNothing);
  });

  testWidgets('approval permission does not grant edit permission', (
    tester,
  ) async {
    MobileAppPermissions.current = const MobileAppPermissions(
      mobileAppLogin: true,
      mobileAppLabourAttendance: false,
      modulePermissions: {'sales-order.approve'},
      hasModulePermissions: true,
    );
    _controller.orders = [
      _order(
        id: 'approve-only',
        status: 'Draft',
        mode: SalesOrderController.modeTonage,
        lines: const [
          SalesOrderLine(
            itemId: 'item-1',
            quantity: 10,
            actualQuantity: 10,
            salePrice: 25,
          ),
        ],
      ),
    ];
    await _pumpSavedOrders(tester);
    expect(find.byTooltip('Edit Sales Order'), findsNothing);
    expect(find.byTooltip('Delete Sales Order'), findsNothing);
    Get.toNamed<void>(Routes.editSalesOrder, arguments: 'approve-only');
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .every((field) => !field.enabled),
      isTrue,
    );
  });

  testWidgets('edit permission shows Save and a disabled Approve button', (
    tester,
  ) async {
    MobileAppPermissions.current = const MobileAppPermissions(
      mobileAppLogin: true,
      mobileAppLabourAttendance: false,
      modulePermissions: {'sales-order.edit'},
      hasModulePermissions: true,
    );
    _controller.orders = [
      _order(
        id: 'edit-only',
        status: 'Draft',
        mode: SalesOrderController.modeTonage,
        lines: const [
          SalesOrderLine(
            itemId: 'item-1',
            quantity: 10,
            actualQuantity: 10,
            salePrice: 25,
          ),
        ],
      ),
    ];
    await _pumpSavedOrders(tester);
    await tester.tap(find.byTooltip('Edit Sales Order'));
    await tester.pumpAndSettle();

    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('invalid order does not open approval confirmation', (
    tester,
  ) async {
    _controller.orders = [
      _order(
        id: 'invalid-approval',
        status: 'Draft',
        mode: SalesOrderController.modeTonage,
        lines: const [
          SalesOrderLine(
            itemId: 'item-1',
            quantity: 0,
            actualQuantity: 0,
            salePrice: 25,
          ),
        ],
      ),
    ];
    await _pumpSavedOrders(tester);
    await tester.tap(find.byTooltip('Edit Sales Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Approve Sales Order?'), findsNothing);
    expect(_controller.approveCount, 0);
  });

  testWidgets('approval actions fit on a narrow phone layout', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _controller.orders = [
      _order(
        id: 'small-screen',
        status: 'Draft',
        mode: SalesOrderController.modeTonage,
        lines: const [
          SalesOrderLine(
            itemId: 'item-1',
            quantity: 10,
            actualQuantity: 10,
            salePrice: 25,
          ),
        ],
      ),
    ];
    await _pumpSavedOrders(tester);
    await tester.tap(find.byTooltip('Edit Sales Order'));
    await tester.pumpAndSettle();

    final layoutException = tester.takeException();
    expect(layoutException, isNull);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
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
            salePrice: 45,
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
