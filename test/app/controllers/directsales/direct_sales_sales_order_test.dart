import 'dart:async';

import 'package:cocoper_mobile/app/controllers/directsales/direct_sales_controller.dart';
import 'package:cocoper_mobile/app/helpers/shared_preferences.dart';
import 'package:cocoper_mobile/app/models/direct_sale.dart';
import 'package:cocoper_mobile/app/models/lookup_option.dart';
import 'package:cocoper_mobile/app/services/endpoints.dart';
import 'package:cocoper_mobile/app/views/directsales/new_direct_sale_view.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      SharedPrefsHelper.organizationId: 'org-1',
      SharedPrefsHelper.selectedBranchId: 'branch-1',
    });
    await SharedPrefsHelper.init();
  });

  tearDown(Get.reset);

  group('Direct Sales customer Sales Orders', () {
    test('does not request orders before a customer is selected', () {
      var requests = 0;
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) async {
          requests++;
          return _response(endpoint, <dynamic>[]);
        },
      );

      expect(requests, 0);
      expect(controller.salesOrdersForCustomer, isEmpty);
      expect(controller.salesOrdersCustomerId.value, isEmpty);
    });

    test('fetches organization-scoped orders and filters Customer A and B',
        () async {
      final calls = <_RequestCall>[];
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) async {
          calls.add(_RequestCall(endpoint, queryParameters, headers));
          return _response(endpoint, [
            _order(
              id: 'a-1',
              number: 'SO-A1',
              customerId: 'customer-a',
              organizationId: 'org-1',
            ),
            _order(
              id: 'b-1',
              number: 'SO-B1',
              customerId: 'customer-b',
              organizationId: 'org-1',
            ),
            _order(
              id: 'foreign-org',
              number: 'SO-FOREIGN',
              customerId: 'customer-a',
              organizationId: 'org-2',
            ),
          ]);
        },
      );

      await controller.loadSalesOrdersForCustomer(
        'customer-a',
        branchId: 'branch-1',
      );
      expect(
        controller.salesOrdersForCustomer.map((order) => order.soNumber),
        ['SO-A1'],
      );

      await controller.loadSalesOrdersForCustomer(
        'customer-b',
        branchId: 'branch-1',
      );
      expect(
        controller.salesOrdersForCustomer.map((order) => order.soNumber),
        ['SO-B1'],
      );
      expect(calls, hasLength(2));
      expect(calls.first.endpoint, EndPoints.salesOrders);
      expect(calls.first.queryParameters, isNull);
      expect(calls.first.headers, {'x-branch-id': 'branch-1'});

      await controller.loadSalesOrdersForCustomer(
        'customer-a',
        branchId: 'branch-1',
      );
      expect(calls, hasLength(2));
      expect(controller.salesOrdersForCustomer.single.soNumber, 'SO-A1');
    });

    test('uses the verified customer ID mappings', () async {
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) async =>
            _response(endpoint, [
          _order(
            id: 'direct',
            number: 'SO-DIRECT',
            customerId: 'customer-a',
            organizationId: 'org-1',
          ),
          {
            'id': 'snake',
            'so_number': 'SO-SNAKE',
            'customer_id': 'customer-a',
            'organization_id': 'org-1',
          },
          {
            'id': 'nested',
            'soNumber': 'SO-NESTED',
            'customer': {'id': 'customer-a'},
            'organizationId': 'org-1',
          },
        ]),
      );

      await controller.loadSalesOrdersForCustomer('customer-a');

      expect(
        controller.salesOrdersForCustomer.map((order) => order.soNumber),
        ['SO-DIRECT', 'SO-SNAKE', 'SO-NESTED'],
      );
    });

    test('shows an empty result without error', () async {
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) async =>
            _response(endpoint, <dynamic>[]),
      );

      await controller.loadSalesOrdersForCustomer('customer-a');

      expect(controller.salesOrdersForCustomer, isEmpty);
      expect(controller.hasSalesOrdersError.value, isFalse);
      expect(controller.isLoadingSalesOrders.value, isFalse);
    });

    test('reports authentication failure and supports retry', () async {
      var requests = 0;
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) async {
          requests++;
          return requests == 1
              ? _response(endpoint, {'message': 'Unauthorized'}, status: 401)
              : _response(endpoint, [
                  _order(
                    id: 'a-1',
                    number: 'SO-A1',
                    customerId: 'customer-a',
                    organizationId: 'org-1',
                  ),
                ]);
        },
      );

      await controller.loadSalesOrdersForCustomer('customer-a');
      expect(controller.hasSalesOrdersError.value, isTrue);
      expect(
          controller.salesOrdersError.value, contains('session has expired'));

      await controller.loadSalesOrdersForCustomer(
        'customer-a',
        forceRefresh: true,
      );
      expect(controller.hasSalesOrdersError.value, isFalse);
      expect(controller.salesOrdersForCustomer.single.id, 'a-1');
      expect(requests, 2);
    });

    test('reports network errors with a retryable message', () async {
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) async {
          throw DioException(
            requestOptions: RequestOptions(path: endpoint),
            type: DioExceptionType.connectionError,
          );
        },
      );

      await controller.loadSalesOrdersForCustomer('customer-a');

      expect(controller.hasSalesOrdersError.value, isTrue);
      expect(
          controller.salesOrdersError.value, contains('Check your connection'));
      expect(controller.isLoadingSalesOrders.value, isFalse);
    });

    test('keeps loading until response and ignores an older customer response',
        () async {
      final firstResponse = Completer<Response<dynamic>?>();
      var requestCount = 0;
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) {
          requestCount++;
          if (requestCount == 1) return firstResponse.future;
          return Future.value(_response(endpoint, [
            _order(
              id: 'b-1',
              number: 'SO-B1',
              customerId: 'customer-b',
              organizationId: 'org-1',
            ),
          ]));
        },
      );

      final oldRequest = controller.loadSalesOrdersForCustomer('customer-a');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isLoadingSalesOrders.value, isTrue);

      await controller.loadSalesOrdersForCustomer('customer-b');
      expect(controller.salesOrdersForCustomer.single.soNumber, 'SO-B1');

      firstResponse.complete(_response(EndPoints.salesOrders, [
        _order(
          id: 'a-1',
          number: 'SO-A1',
          customerId: 'customer-a',
          organizationId: 'org-1',
        ),
      ]));
      await oldRequest;

      expect(controller.salesOrdersCustomerId.value, 'customer-b');
      expect(controller.salesOrdersForCustomer.single.soNumber, 'SO-B1');
      expect(controller.isLoadingSalesOrders.value, isFalse);
    });

    test('loads and validates multi-line Sales Order details', () async {
      final calls = <_RequestCall>[];
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) async {
          calls.add(_RequestCall(endpoint, queryParameters, headers));
          if (endpoint == '${EndPoints.salesOrders}/a-1') {
            return _response(endpoint, {
              ..._order(
                id: 'a-1',
                number: 'SO-A1',
                customerId: 'customer-a',
                organizationId: 'org-1',
              ),
              'lines': [
                _line(itemId: 'item-1', quantity: 2.5, saleCost: 150),
                _line(itemId: 'item-1', quantity: 4, saleCost: 200),
              ],
            });
          }
          return _response(endpoint, [
            _order(
              id: 'a-1',
              number: 'SO-A1',
              customerId: 'customer-a',
              organizationId: 'org-1',
            ),
          ]);
        },
      );

      await controller.loadSalesOrdersForCustomer(
        'customer-a',
        branchId: 'branch-1',
      );
      final details = await controller.loadSalesOrderDetails(
        salesOrderId: 'a-1',
        customerId: 'customer-a',
        branchId: 'branch-1',
      );

      expect(details?.lines, hasLength(2));
      expect(details?.lines.first.quantity, 2.5);
      expect(details?.lines.last.saleCost, 200);
      expect(calls.last.endpoint, '${EndPoints.salesOrders}/a-1');
      expect(calls.last.headers, {'x-branch-id': 'branch-1'});
      expect(controller.isLoadingSalesOrderDetails.value, isFalse);
      expect(controller.salesOrderDetailsError.value, isEmpty);
    });

    test('submits the selected Sales Order number in the Direct Sale payload',
        () async {
      const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(toastChannel, (_) async => true);
      Map<String, dynamic>? submittedBody;
      final controller = _TestDirectSalesController(
        createRequest: (endpoint, body) async {
          expect(endpoint, EndPoints.directSales);
          submittedBody = Map<String, dynamic>.from(body as Map);
          return _response(endpoint, {'success': true}, status: 201);
        },
      );
      controller.lastCreatedDirectSaleNo.value = 'DS-TEST';

      final created = await controller.createDirectSale(
        customerId: 'customer-a',
        branchId: 'branch-1',
        invoiceDate: '2026-10-28',
        mode: 'tonage',
        lines: const [
          DirectSaleLine(
            itemId: 'item-1',
            quantity: 2,
            actualQuantity: 2,
            salesPrice: 10,
            salesAmount: 20,
          ),
        ],
        gunnyBags: const [],
        additionalCharges: 0,
        loadingCharges: 0,
        salesOrderNo: 'SO-A1',
      );

      expect(created, isTrue);
      expect(submittedBody?['salesOrderNo'], 'SO-A1');
      expect(submittedBody?['customerId'], 'customer-a');
      expect(submittedBody?['branchId'], 'branch-1');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(toastChannel, null);
    });

    test('surfaces detail errors and retries the same selected order',
        () async {
      var detailRequests = 0;
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) async {
          if (endpoint == '${EndPoints.salesOrders}/a-1') {
            detailRequests++;
            return detailRequests == 1
                ? _response(endpoint, {'message': 'Service unavailable'},
                    status: 503)
                : _response(endpoint, {
                    ..._order(
                      id: 'a-1',
                      number: 'SO-A1',
                      customerId: 'customer-a',
                      organizationId: 'org-1',
                    ),
                    'lines': [
                      _line(itemId: 'item-1', quantity: 2, saleCost: 10),
                    ],
                  });
          }
          return _response(endpoint, [
            _order(
              id: 'a-1',
              number: 'SO-A1',
              customerId: 'customer-a',
              organizationId: 'org-1',
            ),
          ]);
        },
      );
      await controller.loadSalesOrdersForCustomer('customer-a');

      expect(
        await controller.loadSalesOrderDetails(
          salesOrderId: 'a-1',
          customerId: 'customer-a',
        ),
        isNull,
      );
      expect(controller.salesOrderDetailsError.value,
          contains('Service unavailable'));

      final retriedDetails = await controller.loadSalesOrderDetails(
        salesOrderId: 'a-1',
        customerId: 'customer-a',
        forceRefresh: true,
      );
      expect(retriedDetails?.id, 'a-1');
      expect(controller.salesOrderDetailsError.value, isEmpty);
      expect(detailRequests, 2);
    });

    test('rejects details for a different customer', () async {
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) async {
          if (endpoint == EndPoints.salesOrders) {
            return _response(endpoint, [
              _order(
                id: 'a-1',
                number: 'SO-A1',
                customerId: 'customer-a',
                organizationId: 'org-1',
              ),
            ]);
          }
          return _response(
            endpoint,
            _order(
              id: 'a-1',
              number: 'SO-A1',
              customerId: 'customer-b',
              organizationId: 'org-1',
            ),
          );
        },
      );
      await controller.loadSalesOrdersForCustomer('customer-a');

      final details = await controller.loadSalesOrderDetails(
        salesOrderId: 'a-1',
        customerId: 'customer-a',
      );

      expect(details, isNull);
      expect(controller.selectedSalesOrderDetails.value, isNull);
      expect(
          controller.salesOrderDetailsError.value, contains('does not belong'));
    });

    test('ignores stale Sales Order detail responses', () async {
      final firstResponse = Completer<Response<dynamic>?>();
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) {
          if (endpoint == EndPoints.salesOrders) {
            return Future.value(_response(endpoint, [
              _order(
                id: 'a-1',
                number: 'SO-A1',
                customerId: 'customer-a',
                organizationId: 'org-1',
              ),
              _order(
                id: 'b-1',
                number: 'SO-B1',
                customerId: 'customer-a',
                organizationId: 'org-1',
              ),
            ]));
          }
          if (endpoint == '${EndPoints.salesOrders}/a-1') {
            return firstResponse.future;
          }
          return Future.value(_response(endpoint, {
            ..._order(
              id: 'b-1',
              number: 'SO-B1',
              customerId: 'customer-a',
              organizationId: 'org-1',
            ),
            'lines': [_line(itemId: 'item-1', quantity: 3, saleCost: 80)],
          }));
        },
      );
      await controller.loadSalesOrdersForCustomer('customer-a');

      final staleRequest = controller.loadSalesOrderDetails(
        salesOrderId: 'a-1',
        customerId: 'customer-a',
      );
      await Future<void>.delayed(Duration.zero);
      controller.clearSelectedSalesOrderDetails();
      final currentDetails = await controller.loadSalesOrderDetails(
        salesOrderId: 'b-1',
        customerId: 'customer-a',
      );
      firstResponse.complete(_response('${EndPoints.salesOrders}/a-1', {
        ..._order(
          id: 'a-1',
          number: 'SO-A1',
          customerId: 'customer-a',
          organizationId: 'org-1',
        ),
        'lines': [_line(itemId: 'item-1', quantity: 7, saleCost: 150)],
      }));
      await staleRequest;

      expect(currentDetails?.id, 'b-1');
      expect(controller.selectedSalesOrderDetails.value?.id, 'b-1');
      expect(
          controller.selectedSalesOrderDetails.value?.lines.single.quantity, 3);
    });

    testWidgets('selection populates and replaces every Direct Sales line',
        (tester) async {
      Map<String, dynamic>? submittedBody;
      final controller = _TestDirectSalesController(
        createRequest: (endpoint, body) async {
          expect(endpoint, EndPoints.directSales);
          submittedBody = Map<String, dynamic>.from(body as Map);
          return _response(endpoint, {'success': true}, status: 201);
        },
        request: (endpoint, {queryParameters, headers}) async {
          if (endpoint == '${EndPoints.salesOrders}/a-1') {
            return _response(endpoint, {
              ..._order(
                id: 'a-1',
                number: 'SO-A1',
                customerId: 'customer-a',
                organizationId: 'org-1',
              ),
              'lines': [
                _line(itemId: 'item-1', quantity: 2.5, saleCost: 150),
                _line(itemId: 'item-1', quantity: 4, saleCost: 200),
              ],
            });
          }
          if (endpoint == '${EndPoints.salesOrders}/b-1') {
            return _response(endpoint, {
              ..._order(
                id: 'b-1',
                number: 'SO-B1',
                customerId: 'customer-a',
                organizationId: 'org-1',
              ),
              'lines': [_line(itemId: 'item-1', quantity: 9, saleCost: 50)],
            });
          }
          return _response(endpoint, [
            _order(
              id: 'a-1',
              number: 'SO-A1',
              customerId: 'customer-a',
              organizationId: 'org-1',
            ),
            _order(
              id: 'b-1',
              number: 'SO-B1',
              customerId: 'customer-a',
              organizationId: 'org-1',
            ),
          ]);
        },
      );
      Get.put<DirectSalesController>(controller);
      await tester.pumpWidget(
        const GetMaterialApp(home: NewDirectSaleView()),
      );
      await tester.pumpAndSettle();
      await _selectCustomer(tester, 'Customer A');
      await _selectSalesOrder(tester, 'SO-A1');

      expect(controller.selectedSalesOrderDetails.value?.lines, hasLength(2));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('sales-order-line-quantity-0')),
            )
            .controller!
            .text,
        '2.5',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('sales-order-line-price-1')),
            )
            .controller!
            .text,
        '200.0',
      );
      expect(find.text('₹375'), findsOneWidget);
      expect(find.text('₹800'), findsOneWidget);

      await _selectSalesOrder(tester, 'SO-B1');

      expect(controller.selectedSalesOrderDetails.value?.id, 'b-1');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('sales-order-line-quantity-0')),
            )
            .controller!
            .text,
        '9.0',
      );
      expect(
        find.byKey(const ValueKey('sales-order-line-quantity-1')),
        findsNothing,
      );
      expect(find.text('₹450'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Save Sales'),
      );
      await tester.pumpAndSettle();

      expect(submittedBody?['salesOrderNo'], 'SO-B1');
      expect(submittedBody?['lines'], hasLength(1));
      expect(submittedBody?['lines'].first['quantity'], 9);
      expect(submittedBody?['gunnyBags'], isEmpty);
    });

    testWidgets('keeps manual entry available without an order',
        (tester) async {
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) async =>
            _response(endpoint, <dynamic>[]),
      );
      Get.put<DirectSalesController>(controller);
      await tester.pumpWidget(
        const GetMaterialApp(home: NewDirectSaleView()),
      );
      await tester.pumpAndSettle();

      expect(controller.selectedSalesOrderDetails.value, isNull);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('sales-order-line-quantity-0')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Save Sales'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('customer change preserves unlinked manual entry',
        (tester) async {
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) async =>
            _response(endpoint, <dynamic>[]),
      );
      Get.put<DirectSalesController>(controller);
      await tester.pumpWidget(
        const GetMaterialApp(home: NewDirectSaleView()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('sales-order-line-quantity-0')),
        '3.25',
      );
      await _selectCustomer(tester, 'Customer A');
      await _selectCustomer(tester, 'Customer B');

      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('sales-order-line-quantity-0')),
            )
            .controller!
            .text,
        '3.25',
      );
      expect(controller.selectedSalesOrderDetails.value, isNull);
    });

    testWidgets('customer change clears selection and displays new orders',
        (tester) async {
      var requests = 0;
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) async {
          requests++;
          return _response(endpoint, [
            _order(
              id: 'a-1',
              number: 'SO-A1',
              customerId: 'customer-a',
              organizationId: 'org-1',
            ),
            _order(
              id: 'b-1',
              number: 'SO-B1',
              customerId: 'customer-b',
              organizationId: 'org-1',
            ),
          ]);
        },
      );
      Get.put<DirectSalesController>(controller);
      await tester.pumpWidget(
        const GetMaterialApp(home: NewDirectSaleView()),
      );
      await tester.pumpAndSettle();

      expect(controller.salesOrdersCustomerId.value, isEmpty);
      expect(requests, 0);
      await _selectCustomer(tester, 'Customer A');
      expect(controller.salesOrdersForCustomer.single.soNumber, 'SO-A1');
      await _selectSalesOrder(tester, 'SO-A1');

      var ordersDropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const ValueKey('sales-order-customer-a-branch-1')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(ordersDropdown.value, 'a-1');

      await _selectCustomer(tester, 'Customer B');
      expect(controller.salesOrdersForCustomer.single.soNumber, 'SO-B1');
      ordersDropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const ValueKey('sales-order-customer-b-branch-1')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(ordersDropdown.value, isNull);
      expect(ordersDropdown.items!.map((item) => item.value), ['b-1']);
    });

    testWidgets('shows an error and retry control after an API failure',
        (tester) async {
      var requests = 0;
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) async {
          requests++;
          return requests == 1
              ? _response(endpoint, {'message': 'Service unavailable'},
                  status: 503)
              : _response(endpoint, [
                  _order(
                    id: 'a-1',
                    number: 'SO-A1',
                    customerId: 'customer-a',
                    organizationId: 'org-1',
                  ),
                ]);
        },
      );
      Get.put<DirectSalesController>(controller);
      await tester.pumpWidget(
        const GetMaterialApp(home: NewDirectSaleView()),
      );
      await tester.pumpAndSettle();

      await _selectCustomer(tester, 'Customer A');
      expect(find.textContaining('Service unavailable'), findsOneWidget);
      expect(find.byTooltip('Retry loading Sales Orders'), findsOneWidget);

      await tester.tap(find.byTooltip('Retry loading Sales Orders'));
      await tester.pumpAndSettle();
      expect(controller.salesOrdersForCustomer.single.soNumber, 'SO-A1');
      expect(requests, 2);
    });

    testWidgets('shows loading state during the Sales Order request',
        (tester) async {
      final response = Completer<Response<dynamic>?>();
      final controller = _TestDirectSalesController(
        request: (endpoint, {queryParameters, headers}) => response.future,
      );
      Get.put<DirectSalesController>(controller);
      await tester.pumpWidget(
        const GetMaterialApp(home: NewDirectSaleView()),
      );
      await tester.pumpAndSettle();

      await _selectCustomer(tester, 'Customer A', settle: false);
      await tester.pump();
      expect(find.text('Loading Sales Orders...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      response.complete(_response(EndPoints.salesOrders, <dynamic>[]));
      await tester.pumpAndSettle();
      expect(find.text('No Sales Orders found'), findsOneWidget);
    });
  });
}

class _TestDirectSalesController extends DirectSalesController {
  _TestDirectSalesController({
    DirectSalesOrderGetRequest? request,
    DirectSalesCreateRequest? createRequest,
  }) : super(
          salesOrderGetRequest: request,
          directSalesCreateRequest: createRequest,
        ) {
    items.assignAll(const [LookupOption(id: 'item-1', label: 'Item One')]);
  }

  @override
  Future<void> loadCreateLookups() async {
    customers.assignAll(const [
      LookupOption(id: 'customer-a', label: 'Customer A'),
      LookupOption(id: 'customer-b', label: 'Customer B'),
    ]);
    branches.assignAll(const [
      LookupOption(id: 'branch-1', label: 'Branch One'),
    ]);
    items.assignAll(const [
      LookupOption(id: 'item-1', label: 'Item One'),
    ]);
    gunnyBagTypes.clear();
    hasLookupError.value = false;
    isLoadingLookups.value = false;
  }

  @override
  Future<String> generateDirectSaleNumber() async => 'DSO-01';
}

class _RequestCall {
  const _RequestCall(this.endpoint, this.queryParameters, this.headers);

  final String endpoint;
  final Map<String, dynamic>? queryParameters;
  final Map<String, String>? headers;
}

Response<dynamic> _response(
  String endpoint,
  dynamic data, {
  int status = 200,
}) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: endpoint),
    statusCode: status,
    data: data,
  );
}

Map<String, dynamic> _order({
  required String id,
  required String number,
  required String customerId,
  required String organizationId,
}) {
  return {
    'id': id,
    'soNumber': number,
    'date': '2026-10-27',
    'customerId': customerId,
    'organizationId': organizationId,
    'branchId': 'branch-1',
    'status': 'Draft',
    'mode': 'tonage',
    'lines': [_line(itemId: 'item-1', quantity: 1, saleCost: 10)],
  };
}

Map<String, dynamic> _line({
  required String itemId,
  required double quantity,
  required double saleCost,
}) {
  return {
    'itemId': itemId,
    'quantity': quantity,
    'discount': 0,
    'piecesPercentage': 0,
    'pieces': 0,
    'actualQuantity': quantity,
    'saleCost': saleCost,
    'saleAmount': quantity * saleCost,
  };
}

Future<void> _selectCustomer(
  WidgetTester tester,
  String customer, {
  bool settle = true,
}) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('customer-selector')),
  );
  await tester.tap(find.byKey(const ValueKey('customer-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(customer).last);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _selectSalesOrder(WidgetTester tester, String number) async {
  await tester.tap(
    find.byKey(const ValueKey('sales-order-customer-a-branch-1')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(number).last);
  await tester.pumpAndSettle();
}
