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
  var lastToastMessage = '';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsHelper.init();
  });

  setUp(() async {
    await SharedPrefsHelper.clearAll();
    lastToastMessage = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, (call) async {
      final arguments = call.arguments;
      if (arguments is Map) {
        lastToastMessage = arguments['msg']?.toString() ?? '';
      }
      return true;
    });
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
      baseCost: 12,
      salePrice: 20,
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
            'sourcePOId': 'purchase-order-1',
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
            'sourcePOId': 'purchase-order-1',
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
    expect(requestBody?['sourcePOId'], 'purchase-order-1');
    expect(requestBody?.containsKey('sourcePoId'), isFalse);
    expect(requestBody?['poNumber'], 'COP-01');
    expect(requestBody?['branchId'], 'branch-1');
    expect(requestBody?['totalAmount'], 200);
    expect(requestBody?.containsKey('organizationId'), isFalse);
    expect(requestBody?['lines'], hasLength(1));
    final requestLine = (requestBody?['lines'] as List).single as Map;
    expect(requestLine['saleCost'], 20);
    expect(requestLine.containsKey('salePrice'), isFalse);
    expect(requestLine['baseCost'], 12);
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

  test('confirms the backend direct Sales Order response without a list read',
      () async {
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async => response(201, {
        'id': 'sales-order-direct',
        'soNumber': 'COP-SO-01',
        'sourcePOId': 'purchase-order-1',
        'poNumber': 'COP-01',
      }),
      getRequest: (endpoint) async => response(503, {'message': 'unavailable'}),
    );

    expect(await convert(controller), isTrue);
    expect(controller.lastCreatedSalesOrderId, 'sales-order-direct');
    expect(controller.lastCreatedSalesOrderReference, 'COP-SO-01');
    expect(
      controller.salesOrders.single.sourcePoId,
      'purchase-order-1',
    );
  });

  test('accepts HTTP 200 only when the source link can be confirmed', () async {
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async => response(200, {
        'id': 'sales-order-200',
        'soNumber': 'COP-SO-01',
        'sourcePOId': 'purchase-order-1',
      }),
      getRequest: (endpoint) async => response(503, {'message': 'unavailable'}),
    );

    expect(await convert(controller), isTrue);
    expect(controller.lastCreatedSalesOrderId, 'sales-order-200');
  });

  test('confirmed create succeeds when the subsequent list refresh fails',
      () async {
    var postCount = 0;
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async {
        postCount++;
        expect(endpoint, EndPoints.salesOrders);
        expect((body as Map)['lines'].single['saleCost'], 20);
        return response(201, {
          'success': true,
          'message': 'Sales Order created',
        });
      },
      getRequest: (endpoint) async =>
          response(503, {'message': 'list unavailable'}),
    );

    final saved = await controller.createSalesOrder(
      soNumber: 'SO-NEW',
      date: '2026-10-26',
      customerId: 'customer-1',
      remarks: '',
      mode: SalesOrderController.modeTonage,
      sourcePoId: '',
      poNumber: '',
      lines: lines,
    );

    expect(saved, isTrue);
    expect(postCount, 1);
    expect(controller.hasListError.value, isTrue);
    expect(lastToastMessage, contains('saved successfully'));
  });

  test('ambiguous create failure warns against resubmitting', () async {
    var postCount = 0;
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async {
        postCount++;
        return response(500, {'message': 'Unexpected server error'});
      },
    );

    final saved = await controller.createSalesOrder(
      soNumber: 'SO-AMBIGUOUS',
      date: '2026-10-26',
      customerId: 'customer-1',
      remarks: '',
      mode: SalesOrderController.modeTonage,
      sourcePoId: '',
      poNumber: '',
      lines: lines,
    );

    expect(saved, isFalse);
    expect(postCount, 1);
    expect(lastToastMessage, contains('Unexpected server error'));
    expect(lastToastMessage, contains('do not resubmit yet'));
  });

  test('does not confirm conversion when the saved PO link is missing',
      () async {
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async => response(201, {
        'success': true,
        'data': {
          'id': 'sales-order-1',
          'soNumber': 'COP-SO-01',
        },
      }),
      getRequest: (endpoint) async => response(200, <dynamic>[]),
    );

    expect(await convert(controller), isFalse);
    expect(controller.lastCreatedSalesOrderId, isNull);
    expect(
      controller.isPurchaseOrderConversionBlocked('purchase-order-1'),
      isTrue,
    );
    expect(lastToastMessage, contains('link could not be confirmed'));
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

  test('accepts verified HTTP 200 and 201 creation responses', () {
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
      isTrue,
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

  test('finds an existing Sales Order using the backend sourcePOId field',
      () async {
    final controller = SalesOrderController(
      getRequest: (endpoint) async => response(200, [
        {
          'id': 'sales-order-existing',
          'soNumber': 'COP-SO-01',
          'sourcePOId': 'purchase-order-1',
        },
      ]),
    );

    expect(await controller.loadSalesOrders(), isTrue);
    expect(
      controller.salesOrderForPurchaseOrder('purchase-order-1')?.id,
      'sales-order-existing',
    );
    expect(controller.isPurchaseOrderConversionBlocked('purchase-order-1'),
        isTrue);
  });

  test(
      'uses the successful response and preserves the conversion link when list refresh is empty',
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

    expect(await convert(controller), isTrue);
    expect(controller.lastCreatedSalesOrderId, 'sales-order-1');
    expect(controller.lastCreatedSalesOrderReference, 'COP-SO-01');
    expect(controller.isPurchaseOrderConversionBlocked('purchase-order-1'),
        isTrue);
    var retryPostCount = 0;
    final restoredController = SalesOrderController(
      postRequest: (endpoint, body) async {
        retryPostCount++;
        return response(201, {'success': true});
      },
      getRequest: (endpoint) async => response(200, <dynamic>[]),
    );
    expect(await convert(restoredController), isFalse);
    expect(retryPostCount, 0);
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
    expect(secondPostCount, 1);
  });

  test('lost response is reconciled against the linked Sales Order list',
      () async {
    var postCount = 0;
    var getCount = 0;
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async {
        postCount++;
        if (postCount == 1) return null;
        return response(201, {
          'success': true,
          'data': {
            'id': 'sales-order-1',
            'soNumber': 'COP-SO-01',
            'sourcePoId': 'purchase-order-1',
          },
        });
      },
      getRequest: (endpoint) async {
        getCount++;
        return response(
          200,
          [
            {
              'id': 'sales-order-1',
              'soNumber': 'COP-SO-01',
              'sourcePOId': 'purchase-order-1',
            },
          ],
        );
      },
    );

    expect(await convert(controller), isTrue);
    expect(postCount, 1);
    expect(getCount, 1);
    expect(controller.lastCreatedSalesOrderId, 'sales-order-1');
    expect(controller.lastCreatedSalesOrderReference, 'COP-SO-01');
    expect(controller.isPurchaseOrderConversionBlocked('purchase-order-1'),
        isTrue);
  });

  test('a conflict shows the server reason and blocks another conversion',
      () async {
    var postCount = 0;
    var getCount = 0;
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async {
        postCount++;
        return response(409, {'message': 'Purchase Order is not approved'});
      },
      getRequest: (endpoint) async {
        getCount++;
        return response(200, <dynamic>[]);
      },
    );

    expect(await convert(controller), isFalse);
    expect(getCount, 1);
    expect(lastToastMessage,
        'Conversion rejected: Purchase Order is not approved');
    expect(controller.conversionReferences, isEmpty);
    expect(postCount, 1);
  });

  test('a conflict with a linked Sales Order names the existing order',
      () async {
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async =>
          response(409, {'message': 'Purchase Order already converted'}),
      getRequest: (endpoint) async => response(200, [
        {
          'id': 'sales-order-1',
          'soNumber': 'COP-SO-01',
          'sourcePoId': 'purchase-order-1',
          'poNumber': 'COP-01',
        },
      ]),
    );

    expect(await convert(controller), isFalse);
    expect(controller.conversionReferences['purchase-order-1'], 'COP-SO-01');
    expect(
      lastToastMessage,
      'This Purchase Order is already converted to Sales Order COP-SO-01.',
    );
  });

  test(
      'duplicate conversion response records the linked order and exposes it for navigation',
      () async {
    var postCount = 0;
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async {
        postCount++;
        return response(409, {
          'status': 'error',
          'code': 'PURCHASE_ORDER_ALREADY_CONVERTED',
          'message':
              'This purchase order has already been converted to a sales order.',
          'details': {
            'sourcePOId': 'purchase-order-1',
            'salesOrder': {
              'id': 'sales-order-existing',
              'soNumber': 'COP-SO-01',
              'sourcePOId': 'purchase-order-1',
              'poNumber': 'COP-01',
              'status': 'Draft',
              'lines': [
                {'itemId': 'item-1', 'quantity': 10, 'saleAmount': 200},
              ],
            },
          },
        });
      },
      getRequest: (endpoint) async => response(200, <dynamic>[]),
    );

    expect(await convert(controller), isFalse);
    expect(controller.lastExistingSalesOrderId, 'sales-order-existing');
    expect(controller.lastExistingSalesOrderReference, 'COP-SO-01');
    expect(controller.salesOrders.single.id, 'sales-order-existing');
    expect(controller.salesOrders.single.lines.single.saleAmount, 200);
    expect(controller.isPurchaseOrderConversionBlocked('purchase-order-1'),
        isTrue);
    expect(
      (await controller.fetchSalesOrderById('sales-order-existing'))?.soNumber,
      'COP-SO-01',
    );
    expect(await convert(controller), isFalse);
    expect(postCount, 1);
  });

  test('successful conversion uses response ID even if the list refresh fails',
      () async {
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async => response(201, {
        'id': 'sales-order-created',
        'soNumber': 'COP-SO-01',
        'sourcePOId': 'purchase-order-1',
        'poNumber': 'COP-01',
        'status': 'Draft',
        'lines': [
          {'itemId': 'item-1', 'quantity': 10, 'saleAmount': 200},
        ],
      }),
      getRequest: (endpoint) async =>
          response(503, {'message': 'Temporarily unavailable'}),
    );

    expect(await convert(controller), isTrue, reason: lastToastMessage);
    expect(controller.lastCreatedSalesOrderId, 'sales-order-created');
    expect(controller.lastCreatedSalesOrderReference, 'COP-SO-01');
    expect(controller.salesOrders.single.id, 'sales-order-created');
    expect(controller.isPurchaseOrderConversionBlocked('purchase-order-1'),
        isTrue);
  });

  test('confirmed absence after a lost response allows a controlled retry',
      () async {
    var postCount = 0;
    var getCount = 0;
    final controller = SalesOrderController(
      postRequest: (endpoint, body) async {
        postCount++;
        if (postCount == 1) return null;
        return response(201, {
          'id': 'sales-order-created',
          'soNumber': 'COP-SO-01',
          'sourcePOId': 'purchase-order-1',
        });
      },
      getRequest: (endpoint) async {
        getCount++;
        return response(200, <dynamic>[]);
      },
    );

    expect(await convert(controller), isFalse);
    expect(controller.isPurchaseOrderConversionBlocked('purchase-order-1'),
        isFalse);
    expect(lastToastMessage, contains('You may retry'));
    expect(await convert(controller), isTrue);
    expect(postCount, 2);
    expect(getCount, 2);
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
