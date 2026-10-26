import 'package:cocoper_mobile/app/controllers/salesorders/sales_order_controller.dart';
import 'package:cocoper_mobile/app/helpers/shared_preferences.dart';
import 'package:cocoper_mobile/app/models/sales_order_line.dart';
import 'package:cocoper_mobile/app/services/endpoints.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsHelper.init();
  });

  setUp(() async {
    await SharedPrefsHelper.clearAll();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, (_) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, null);
  });

  Response<dynamic> response(int statusCode, dynamic data) => Response<dynamic>(
        requestOptions: RequestOptions(path: '/sales-orders'),
        statusCode: statusCode,
        data: data,
      );

  const lines = [
    SalesOrderLine(
      itemId: 'item-1',
      quantity: 10,
      actualQuantity: 10,
      saleCost: 20,
      saleAmount: 200,
      amount: 200,
    ),
  ];

  Future<bool> convert(
    SalesOrderController controller,
  ) =>
      controller.createSalesOrder(
        soNumber: 'COP-SO-01',
        date: '2026-10-26',
        customerId: 'customer-1',
        remarks: 'Converted from COP-01',
        mode: SalesOrderController.modeTonage,
        sourcePoId: 'purchase-order-1',
        poNumber: 'COP-01',
        branchId: 'branch-1',
        lines: lines,
      );

  test('posts the PO reference, then refreshes and maps the Sales Order list',
      () async {
    final calls = <String>[];
    Map<String, dynamic>? requestBody;
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async {
        calls.add('POST $endpoint');
        requestBody = Map<String, dynamic>.from(body as Map);
        return response(201, {
          'success': true,
          'data': {
            'id': 'sales-order-1',
            'soNumber': 'COP-SO-01',
            'sourcePoId': 'purchase-order-1',
            'poNumber': 'COP-01',
          },
        });
      },
      getRequest: (endpoint) async {
        calls.add('GET $endpoint');
        return response(200, [
          {
            'id': 'sales-order-1',
            'soNumber': 'COP-SO-01',
            'sourcePoId': 'purchase-order-1',
            'poNumber': 'COP-01',
            'branchId': 'branch-1',
            'status': 'Draft',
            'lines': [
              {'itemId': 'item-1', 'quantity': 10},
            ],
          },
        ]);
      },
    );

    expect(await convert(controller), isTrue);

    expect(calls, [
      'POST ${EndPoints.salesOrders}',
      'GET ${EndPoints.salesOrders}',
    ]);
    expect(requestBody?['sourcePoId'], 'purchase-order-1');
    expect(requestBody?['poNumber'], 'COP-01');
    expect(requestBody?['branchId'], 'branch-1');
    expect(requestBody?.containsKey('organizationId'), isFalse);
    expect(requestBody?['lines'], hasLength(1));
    expect(controller.salesOrders.single.id, 'sales-order-1');
    expect(controller.salesOrders.single.sourcePoId, 'purchase-order-1');
    expect(controller.salesOrders.single.poNumber, 'COP-01');
    expect(controller.salesOrders.single.branchId, 'branch-1');
    expect(controller.lastCreatedSalesOrderId, 'sales-order-1');
    expect(controller.lastCreatedSalesOrderReference, 'COP-SO-01');
    expect(
      calls.where((call) => call.contains(EndPoints.purchaseOrders)),
      isEmpty,
    );
  });

  test('does not treat server rejection as conversion success; explicit retry',
      () async {
    var postCount = 0;
    var getCount = 0;
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async {
        postCount++;
        return response(
          postCount == 1 ? 200 : 201,
          postCount == 1
              ? {'success': false, 'message': 'Source PO is not approved'}
              : {
                  'success': true,
                  'data': {
                    'id': 'sales-order-1',
                    'soNumber': 'COP-SO-01',
                    'sourcePoId': 'purchase-order-1',
                  },
                },
        );
      },
      getRequest: (endpoint) async {
        getCount++;
        return response(200, [
          {
            'id': 'sales-order-1',
            'soNumber': 'COP-SO-01',
            'sourcePoId': 'purchase-order-1',
          },
        ]);
      },
    );

    expect(await convert(controller), isFalse);
    expect(getCount, 0);
    expect(controller.isSaving.value, isFalse);

    expect(await convert(controller), isTrue);
    expect(postCount, 2);
    expect(getCount, 1);
  });

  test('requires HTTP 201 for conversion but preserves generic create success',
      () {
    expect(
      SalesOrderController.isSuccessfulCreateResponse(
        response(201, {'success': true}),
        isPurchaseOrderConversion: true,
      ),
      isTrue,
    );
    expect(
      SalesOrderController.isSuccessfulCreateResponse(
        response(200, {'success': true}),
        isPurchaseOrderConversion: true,
      ),
      isFalse,
    );
    expect(
      SalesOrderController.isSuccessfulCreateResponse(
        response(200, {'success': true}),
      ),
      isTrue,
    );
  });

  test('prevents a second conversion when a linked Sales Order exists',
      () async {
    var postCount = 0;
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async {
        postCount++;
        return response(201, {
          'success': true,
          'data': {
            'id': 'sales-order-1',
            'soNumber': 'COP-SO-01',
            'sourcePoId': 'purchase-order-1',
          },
        });
      },
      getRequest: (endpoint) async => response(200, [
        {
          'id': 'sales-order-1',
          'soNumber': 'COP-SO-01',
          'sourcePoId': 'purchase-order-1',
          'poNumber': 'COP-01',
          'status': 'Draft',
        },
      ]),
    );

    expect(await convert(controller), isTrue);
    expect(controller.isPurchaseOrderConversionBlocked('purchase-order-1'),
        isTrue);
    expect(await convert(controller), isFalse);
    expect(postCount, 1);
    expect(
      controller.conversionReferences['purchase-order-1'],
      'COP-SO-01',
    );
  });

  test(
      'does not report success unless refreshed server list confirms the PO link',
      () async {
    var postCount = 0;
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async {
        postCount++;
        return response(201, {
          'success': true,
          'data': {
            'id': 'sales-order-1',
            'soNumber': 'COP-SO-01',
            'sourcePoId': 'purchase-order-1',
          },
        });
      },
      getRequest: (endpoint) async => response(200, <dynamic>[]),
    );

    expect(await convert(controller), isFalse);
    expect(controller.lastCreatedSalesOrderId, isNull);
    expect(controller.lastCreatedSalesOrderReference, isNull);
    expect(controller.isPurchaseOrderConversionBlocked('purchase-order-1'),
        isTrue);
    expect(await convert(controller), isFalse);
    expect(postCount, 1);
  });

  test('ambiguous conversion lock survives controller recreation', () async {
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async => null,
      getRequest: (endpoint) async => response(200, <dynamic>[]),
    );

    expect(await convert(controller), isFalse);

    var secondPostCount = 0;
    final restoredController = SalesOrderController(
      postRequest: (endpoint, body) async {
        secondPostCount++;
        return response(201, {'success': true});
      },
      getRequest: (endpoint) async => response(200, <dynamic>[]),
    );
    expect(await convert(restoredController), isFalse);
    expect(secondPostCount, 0);
  });

  test('a conflict refreshes Sales Orders and blocks another conversion',
      () async {
    var postCount = 0;
    var getCount = 0;
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async {
        postCount++;
        return response(409, {'message': 'Purchase Order already converted'});
      },
      getRequest: (endpoint) async {
        getCount++;
        return response(200, [
          {
            'id': 'sales-order-1',
            'soNumber': 'COP-SO-01',
            'sourcePoId': 'purchase-order-1',
            'poNumber': 'COP-01',
          },
        ]);
      },
    );

    expect(await convert(controller), isFalse);
    expect(getCount, 1);
    expect(controller.conversionReferences['purchase-order-1'], 'COP-SO-01');
    expect(await convert(controller), isFalse);
    expect(postCount, 1);
  });

  test('ambiguous network outcome is not retried by another save tap',
      () async {
    var postCount = 0;
    var getCount = 0;
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async {
        postCount++;
        return null;
      },
      getRequest: (endpoint) async {
        getCount++;
        return response(200, <dynamic>[]);
      },
    );

    expect(await convert(controller), isFalse);
    expect(controller.isPurchaseOrderConversionBlocked('purchase-order-1'),
        isTrue);
    expect(await convert(controller), isFalse);
    expect(postCount, 1);
    expect(getCount, 0);
  });

  test('maps authentication, missing PO and conflict statuses', () {
    expect(
      SalesOrderController.conversionErrorMessage(401),
      contains('session'),
    );
    expect(
      SalesOrderController.conversionErrorMessage(403),
      contains('authorized'),
    );
    expect(
      SalesOrderController.conversionErrorMessage(404),
      contains('not found'),
    );
    expect(
      SalesOrderController.conversionErrorMessage(409),
      contains('already been converted'),
    );
  });
}
