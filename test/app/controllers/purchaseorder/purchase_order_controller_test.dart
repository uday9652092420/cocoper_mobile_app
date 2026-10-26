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
}
