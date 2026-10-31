import 'dart:async';

import 'package:cocoper_mobile/app/controllers/purchaseorder/purchase_order_controller.dart';
import 'package:cocoper_mobile/app/helpers/shared_preferences.dart';
import 'package:cocoper_mobile/app/models/purchase_order_line.dart';
import 'package:cocoper_mobile/app/services/endpoints.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsHelper.init();
    await SharedPrefsHelper.setString(
      SharedPrefsHelper.organizationId,
      'org-1',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, (_) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, null);
  });

  Response<dynamic> response({
    required int statusCode,
    dynamic data,
  }) =>
      Response<dynamic>(
        requestOptions: RequestOptions(path: '/purchase-orders'),
        statusCode: statusCode,
        data: data,
      );

  test('accepts successful purchase-order create responses', () {
    expect(
      PurchaseOrderController.isSuccessfulSaveResponse(
        response(statusCode: 201, data: {'success': true}),
      ),
      isTrue,
    );
    expect(
      PurchaseOrderController.isSuccessfulSaveResponse(
        response(statusCode: 200, data: {'id': 'po-1'}),
      ),
      isTrue,
    );
  });

  test('rejects unsuccessful status and success-false response bodies', () {
    expect(
      PurchaseOrderController.isSuccessfulSaveResponse(
        response(statusCode: 200, data: {'success': false}),
      ),
      isFalse,
    );
    expect(
      PurchaseOrderController.isSuccessfulSaveResponse(
        response(statusCode: 400, data: {'success': false}),
      ),
      isFalse,
    );
    expect(
      PurchaseOrderController.isSuccessfulSaveResponse(null),
      isFalse,
    );
  });

  test('matches Web Purchase Order whole-unit amount rounding', () {
    expect(
      PurchaseOrderController.calculatePurchaseAmount(25.25, 4),
      101,
    );
    expect(
      PurchaseOrderController.calculatePurchaseAmount(25.125, 4),
      101,
    );
  });

  test('loads only branches assigned to the authenticated user', () async {
    final controller = PurchaseOrderController(
      getRequest: (endpoint) async {
        if (endpoint == EndPoints.suppliers) {
          return response(
            statusCode: 200,
            data: {
              'success': true,
              'data': <dynamic>[
                {'id': 'supplier-1', 'supplier_name': 'Supplier One'},
              ],
            },
          );
        }
        if (endpoint == EndPoints.items) {
          return response(
            statusCode: 200,
            data: <dynamic>[
              {'id': 'item-1', 'item_name': 'Coconut'},
            ],
          );
        }
        if (endpoint == EndPoints.mobileBootstrap) {
          return response(
            statusCode: 200,
            data: {
              'success': true,
              'branches': <dynamic>[
                {'id': 'assigned-branch', 'branch_name': 'Assigned Branch'},
              ],
            },
          );
        }
        return null;
      },
    );

    await controller.loadLookups();

    expect(
      controller.branches.map((branch) => branch.id),
      ['assigned-branch'],
    );
  });

  test('creates a PO in organization scope and refreshes the saved list',
      () async {
    final requests = <String>[];
    Map<String, dynamic>? sentBody;
    final controller = PurchaseOrderController(
      postRequest: (endpoint, body) async {
        requests.add('POST $endpoint');
        sentBody = Map<String, dynamic>.from(body as Map);
        return response(statusCode: 201, data: {'success': true});
      },
      getRequest: (endpoint) async {
        requests.add('GET $endpoint');
        if (endpoint == '${EndPoints.purchaseOrders}/po-1') {
          return response(
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'id': 'po-1',
                'poNumber': 'COP-01',
                'organizationId': 'org-1',
                'branchId': 'branch-1',
                'supplierId': 'supplier-1',
                'status': 'Draft',
                'lines': [
                  {'itemId': 'item-1', 'quantity': 10},
                ],
              },
            },
          );
        }
        return response(
          statusCode: 200,
          data: [
            {
              'id': 'po-1',
              'poNumber': 'COP-01',
              'organizationId': 'org-1',
              'branchId': 'branch-1',
              'supplierId': 'supplier-1',
              'status': 'Draft',
              'lines': [
                {'itemId': 'item-1', 'quantity': 10},
              ],
            },
          ],
        );
      },
    );

    final saved = await controller.createPurchaseOrder(
      poNumber: 'COP-01',
      supplierId: 'supplier-1',
      branchId: 'branch-1',
      date: '2026-10-26',
      mode: 'tonage',
      remarks: 'PO note',
      lines: const [
        PurchaseOrderLine(itemId: 'item-1', quantity: 10),
      ],
    );

    expect(saved, isTrue);
    expect(requests, [
      'POST ${EndPoints.purchaseOrders}',
      'GET ${EndPoints.purchaseOrders}'
    ]);
    expect(sentBody?['organizationId'], 'org-1');
    expect(sentBody?['branchId'], 'branch-1');
    expect(sentBody?['supplierId'], 'supplier-1');
    expect(sentBody?['date'], '2026-10-26');
    expect(sentBody?['status'], 'Draft');
    expect(controller.purchaseOrders.single.id, 'po-1');
    expect(controller.purchaseOrders.single.lines.single.itemId, 'item-1');

    final loaded = await controller.fetchPurchaseOrderById('po-1');
    expect(requests.last, 'GET ${EndPoints.purchaseOrders}/po-1');
    expect(loaded?.id, 'po-1');
    expect(loaded?.organizationId, 'org-1');
  });

  test('does not report explicit server rejection as saved and permits retry',
      () async {
    var postCount = 0;
    var getCount = 0;
    final controller = PurchaseOrderController(
      postRequest: (endpoint, body) async {
        postCount++;
        return response(
          statusCode: 200,
          data: postCount == 1
              ? {'success': false, 'message': 'Invalid purchase order'}
              : {'success': true},
        );
      },
      getRequest: (endpoint) async {
        getCount++;
        return response(statusCode: 200, data: <dynamic>[]);
      },
    );

    Future<bool> create() => controller.createPurchaseOrder(
          poNumber: 'COP-01',
          supplierId: 'supplier-1',
          branchId: 'branch-1',
          date: '2026-10-26',
          mode: 'tonage',
          remarks: '',
          lines: const [PurchaseOrderLine(itemId: 'item-1', quantity: 10)],
        );

    expect(await create(), isFalse);
    expect(getCount, 0);
    expect(controller.isSaving.value, isFalse);

    expect(await create(), isTrue);
    expect(postCount, 2);
    expect(getCount, 1);
  });

  test('save and approval use independent PUT payloads', () async {
    final requests = <({String endpoint, Map<String, dynamic> body})>[];
    var listReadCount = 0;
    final controller = PurchaseOrderController(
      putRequest: (endpoint, body) async {
        requests
            .add((endpoint: endpoint, body: Map<String, dynamic>.from(body)));
        return response(statusCode: 200, data: {'success': true});
      },
      getRequest: (endpoint) async {
        listReadCount++;
        return response(
          statusCode: 200,
          data: [
            {
              'id': 'po-1',
              'poNumber': 'TPO-01',
              'organizationId': 'org-1',
              'supplierId': 'supplier-1',
              'branchId': 'branch-1',
              'status': listReadCount == 1 ? 'Draft' : 'Approved',
              'lines': [
                {'id': 'line-1', 'itemId': 'item-1', 'quantity': 10},
              ],
            },
          ],
        );
      },
    );

    final saved = await controller.updatePurchaseOrder(
      id: 'po-1',
      poNumber: 'TPO-01',
      supplierId: 'supplier-1',
      branchId: 'branch-1',
      date: '2026-10-26',
      mode: 'tonage',
      remarks: '',
      lines: const [
        PurchaseOrderLine(
          id: 'line-1',
          itemId: 'item-1',
          quantity: 10,
          purchaseCost: 25,
          purchaseAmount: 250,
          amount: 250,
        ),
      ],
    );

    expect(saved, isTrue);
    expect(requests, hasLength(1));
    expect(requests.first.endpoint, '${EndPoints.purchaseOrders}/po-1');
    expect(requests.first.body.containsKey('status'), isFalse);
    expect(requests.first.body['poNumber'], 'TPO-01');
    expect(requests.first.body['organizationId'], 'org-1');
    expect(requests.first.body['supplierId'], 'supplier-1');
    expect(requests.first.body['branchId'], 'branch-1');
    expect(requests.first.body['remarks'], '');
    expect((requests.first.body['lines'] as List).single['id'], 'line-1');
    expect(controller.purchaseOrders.single.status, 'Draft');

    final approved = await controller.approvePurchaseOrder('po-1');

    expect(approved, isTrue);
    expect(requests, hasLength(2));
    expect(requests.last.endpoint, '${EndPoints.purchaseOrders}/po-1');
    expect(requests.last.body, const {'status': 'Approved'});
    expect(controller.purchaseOrders.single.status, 'Approved');
  });

  test('prevents duplicate approval requests while one is in progress',
      () async {
    final pendingResponse = Completer<Response<dynamic>?>();
    var putCount = 0;
    final controller = PurchaseOrderController(
      putRequest: (endpoint, body) {
        putCount++;
        return pendingResponse.future;
      },
      getRequest: (endpoint) async =>
          response(statusCode: 200, data: <dynamic>[]),
    );

    final firstApproval = controller.approvePurchaseOrder('po-1');
    expect(controller.isSaving.value, isTrue);
    expect(await controller.approvePurchaseOrder('po-1'), isFalse);
    expect(putCount, 1);

    pendingResponse.complete(
      response(statusCode: 200, data: {'success': true}),
    );
    expect(await firstApproval, isTrue);
    expect(controller.isSaving.value, isFalse);
  });

  test('prevents duplicate save requests while one is in progress', () async {
    final pendingResponse = Completer<Response<dynamic>?>();
    var putCount = 0;
    final controller = PurchaseOrderController(
      putRequest: (endpoint, body) {
        putCount++;
        return pendingResponse.future;
      },
      getRequest: (endpoint) async =>
          response(statusCode: 200, data: <dynamic>[]),
    );

    Future<bool> save() => controller.updatePurchaseOrder(
          id: 'po-1',
          poNumber: 'TPO-01',
          supplierId: 'supplier-1',
          branchId: 'branch-1',
          date: '2026-10-26',
          mode: 'tonage',
          remarks: '',
          lines: const [PurchaseOrderLine(itemId: 'item-1', quantity: 1)],
        );

    final firstSave = save();
    await Future<void>.delayed(Duration.zero);
    expect(controller.isSaving.value, isTrue);
    expect(await save(), isFalse);
    expect(putCount, 1);

    pendingResponse.complete(
      response(statusCode: 200, data: {'success': true}),
    );
    expect(await firstSave, isTrue);
    expect(controller.isSaving.value, isFalse);
  });
}
