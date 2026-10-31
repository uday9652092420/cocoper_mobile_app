import 'dart:async';

import 'package:cocoper_mobile/app/controllers/salesorders/sales_order_controller.dart';
import 'package:cocoper_mobile/app/helpers/shared_preferences.dart';
import 'package:cocoper_mobile/app/models/sales_order.dart';
import 'package:cocoper_mobile/app/models/sales_order_line.dart';
import 'package:cocoper_mobile/app/services/mobile_app_permissions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SalesOrderLine _validLine({
  String id = '',
  String mode = SalesOrderController.modeTonage,
  double quantity = 10,
  double discount = 0,
  double salePrice = 25,
}) {
  final actualQuantity = SalesOrderController.calculateActualQuantity(
    mode: mode,
    quantity: quantity,
    discount: discount,
    piecesPercentage: 0,
  );
  final saleAmount =
      SalesOrderController.calculateSaleAmount(salePrice, actualQuantity);
  return SalesOrderLine(
    id: id,
    itemId: 'item-1',
    quantity: quantity,
    discount: discount,
    pieces: 5,
    baseCost: SalesOrderController.calculateBaseCost(saleAmount, 5),
    actualQuantity: actualQuantity,
    salePrice: salePrice,
    saleAmount: saleAmount,
    amount: saleAmount,
  );
}

Response<dynamic> _response(String path, int statusCode, dynamic data) =>
    Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      data: data,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final toastMessages = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(toastChannel, (call) async {
    final arguments = call.arguments;
    if (arguments is Map && arguments['msg'] is String) {
      toastMessages.add(arguments['msg'] as String);
    }
    return true;
  });

  group('Sales Order edit validation', () {
    setUp(() {
      MobileAppPermissions.current = const MobileAppPermissions(
        mobileAppLogin: true,
        mobileAppLabourAttendance: false,
        modulePermissions: {'sales-order.edit', 'sales-order.approve'},
        hasModulePermissions: true,
      );
    });

    tearDown(() {
      MobileAppPermissions.current = null;
    });

    String? validate({
      String date = '2026-10-16',
      String mode = SalesOrderController.modeTonage,
      List<SalesOrderLine>? lines,
    }) {
      return SalesOrderController.validateSalesOrder(
        soNumber: 'SO-10',
        date: date,
        customerId: 'customer-1',
        mode: mode,
        lines: lines ?? [_validLine()],
      );
    }

    test('accepts valid editable Sales Order data', () {
      expect(validate(), isNull);
    });

    test('rejects missing mandatory fields and invalid dates', () {
      expect(
        SalesOrderController.validateSalesOrder(
          soNumber: '',
          date: '2026-10-16',
          customerId: 'customer-1',
          mode: SalesOrderController.modeTonage,
          lines: [_validLine()],
        ),
        isNotNull,
      );
      expect(validate(date: '2026-02-30'), isNotNull);
      expect(
        validate(mode: SalesOrderController.modeTonagePercentage),
        isNotNull,
      );
      expect(validate(lines: const []), isNotNull);
    });

    test('rejects non-positive quantities or prices', () {
      expect(validate(lines: [_validLine(quantity: 0)]), isNotNull);
      expect(validate(lines: [_validLine(salePrice: 0)]), isNotNull);
      expect(
        validate(
          mode: SalesOrderController.modeLessing,
          lines: [
            _validLine(
              mode: SalesOrderController.modeLessing,
              discount: 100,
            ),
          ],
        ),
        isNotNull,
      );
    });

    test('only Draft is editable; unknown statuses fail closed', () {
      expect(
        SalesOrderController.canEditSalesOrder(
          const SalesOrder(status: ' Draft '),
        ),
        isTrue,
      );
      expect(
        SalesOrderController.canEditSalesOrder(
          const SalesOrder(status: 'Approved'),
        ),
        isFalse,
      );
      expect(
        SalesOrderController.canEditSalesOrder(
          const SalesOrder(status: 'Awaiting Review'),
        ),
        isFalse,
      );
    });

    test('total falls back to legacy amount when saleAmount is absent', () {
      expect(
        SalesOrderController.calculateTotalAmount(
          const [SalesOrderLine(amount: 42)],
        ),
        42,
      );
    });

    test('Sale Price drives amount and profit calculations', () {
      final saleAmount = SalesOrderController.calculateSaleAmount(12.5, 8.125);

      expect(saleAmount, 101.56);
      expect(
        SalesOrderController.calculateProfit(saleAmount, 80),
        closeTo(21.56, 0.000001),
      );
    });

    test(
        'update rechecks latest server status and never updates changed status',
        () async {
      var refreshCount = 0;
      final controller = SalesOrderController(
        getRequest: (endpoint) async {
          refreshCount++;
          return _response(endpoint, 200, {
            'id': 'so-1',
            'status': 'Approved',
          });
        },
      );

      final updated = await controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );

      expect(updated, isFalse);
      expect(refreshCount, 1);
      expect(controller.isSaving.value, isFalse);
    });

    test('update rejects invalid values before refreshing or submitting',
        () async {
      var refreshCount = 0;
      final controller = SalesOrderController(
        getRequest: (endpoint) async {
          refreshCount++;
          return _response(endpoint, 200, {
            'id': 'so-1',
            'status': 'Draft',
          });
        },
      );

      final updated = await controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine(quantity: 0)],
      );

      expect(updated, isFalse);
      expect(refreshCount, 0);
      expect(controller.isSaving.value, isFalse);
    });

    test('duplicate update attempts are prevented while refresh is pending',
        () async {
      final pendingOrder = Completer<Response<dynamic>?>();
      var refreshCount = 0;
      final controller = SalesOrderController(
        getRequest: (endpoint) {
          refreshCount++;
          return pendingOrder.future;
        },
      );
      final firstRequest = controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );
      await Future<void>.delayed(Duration.zero);

      final duplicateRequest = await controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );
      pendingOrder.complete(_response('/sales-orders/so-1', 200, {
        'id': 'so-1',
        'status': 'Approved',
      }));

      expect(duplicateRequest, isFalse);
      expect(await firstRequest, isFalse);
      expect(refreshCount, 1);
      expect(controller.isSaving.value, isFalse);
    });

    test('confirmed update sends fields without status and stays Draft',
        () async {
      toastMessages.clear();
      SharedPreferences.setMockInitialValues({});
      await SharedPrefsHelper.init();
      final line = _validLine(id: 'SOL-1');
      final savedOrder = <String, dynamic>{
        'id': 'so-1',
        'soNumber': 'SO-1',
        'organizationId': 'organization-1',
        'branchId': 'branch-1',
        'date': '2026-10-16T00:00:00.000Z',
        'customerId': 'customer-1',
        'remarks': 'Updated remarks',
        'status': 'Draft',
        'mode': SalesOrderController.modeTonage,
        'sourcePOId': 'po-1',
        'poNumber': 'PO-1',
        'totalAmount': 250,
        'lines': [line.toJson()],
      };
      final getPaths = <String>[];
      String? putPath;
      Map<String, dynamic>? putBody;
      final controller = SalesOrderController(
        getRequest: (endpoint) async {
          getPaths.add(endpoint);
          if (endpoint.endsWith('/so-1')) {
            return _response(endpoint, 200, savedOrder);
          }
          return _response(endpoint, 500, {'message': 'refresh unavailable'});
        },
        putRequest: (endpoint, body) async {
          putPath = endpoint;
          putBody = body;
          return _response(endpoint, 200, savedOrder);
        },
      );

      final updated = await controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: 'Updated remarks',
        mode: SalesOrderController.modeTonage,
        lines: [line],
      );

      expect(updated, isTrue);
      expect(putPath, 'sales-orders/so-1');
      expect(putBody, isNotNull);
      expect(putBody!.containsKey('status'), isFalse);
      expect(putBody!['organizationId'], 'organization-1');
      expect(putBody!.containsKey('branchId'), isFalse);
      expect(putBody!['sourcePOId'], 'po-1');
      expect(putBody!['totalAmount'], 250);
      final savedLine = (putBody!['lines'] as List).single as Map;
      expect(savedLine['id'], 'SOL-1');
      expect(savedLine['saleCost'], line.salePrice);
      expect(savedLine.containsKey('salePrice'), isFalse);
      expect(getPaths, hasLength(2));
      expect(controller.salesOrders.single.status, 'Draft');
      expect(controller.hasListError.value, isTrue);
      expect(
        toastMessages,
        contains(
          'Sales Order saved successfully. The list could not be refreshed.',
        ),
      );
    });

    test('success response without a detail DTO is not treated as a save error',
        () async {
      toastMessages.clear();
      var getCount = 0;
      final latestOrder = <String, dynamic>{
        'id': 'so-1',
        'soNumber': 'SO-1',
        'organizationId': 'organization-1',
        'date': '2026-10-16',
        'customerId': 'customer-1',
        'status': 'Draft',
        'mode': SalesOrderController.modeTonage,
      };
      final controller = SalesOrderController(
        getRequest: (endpoint) async {
          getCount++;
          return getCount == 1
              ? _response(endpoint, 200, latestOrder)
              : _response(endpoint, 503, {'message': 'refresh unavailable'});
        },
        putRequest: (endpoint, body) async => _response(endpoint, 200, {
          'success': true,
          'message': 'Sales Order updated',
        }),
      );

      final updated = await controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );

      expect(updated, isTrue);
      expect(getCount, 2);
      expect(controller.hasListError.value, isTrue);
      expect(
        toastMessages,
        contains(
          'Sales Order saved successfully. The list could not be refreshed.',
        ),
      );
      expect(
        toastMessages
            .any((message) => message.contains('Something went wrong')),
        isFalse,
      );
    });

    test('update blocks when the organization identifier is missing', () async {
      SharedPreferences.setMockInitialValues({});
      await SharedPrefsHelper.init();
      toastMessages.clear();
      var putCount = 0;
      final controller = SalesOrderController(
        getRequest: (endpoint) async => _response(endpoint, 200, {
          'id': 'so-1',
          'soNumber': 'SO-1',
          'date': '2026-10-16',
          'customerId': 'customer-1',
          'status': 'Draft',
          'mode': SalesOrderController.modeTonage,
        }),
        putRequest: (endpoint, body) async {
          putCount++;
          return _response(endpoint, 200, {'id': 'so-1'});
        },
      );

      final updated = await controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );

      expect(updated, isFalse);
      expect(putCount, 0);
      expect(
        toastMessages,
        contains(
          'The Sales Order organization identifier is invalid. '
          'Refresh the selected organization.',
        ),
      );
    });

    test('update uses selected organization without requiring a branch',
        () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsHelper.organizationId: 'selected-organization',
      });
      await SharedPrefsHelper.init();
      Map<String, dynamic>? putBody;
      final controller = SalesOrderController(
        getRequest: (endpoint) async => _response(
          endpoint,
          200,
          endpoint.endsWith('/so-1')
              ? {
                  'id': 'so-1',
                  'soNumber': 'SO-1',
                  'date': '2026-10-16',
                  'customerId': 'customer-1',
                  'status': 'Draft',
                  'mode': SalesOrderController.modeTonage,
                }
              : <dynamic>[],
        ),
        putRequest: (endpoint, body) async {
          putBody = body;
          return _response(endpoint, 200, {'success': true});
        },
      );

      final saved = await controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );

      expect(saved, isTrue);
      expect(putBody?['organizationId'], 'selected-organization');
      expect(putBody?.containsKey('branchId'), isFalse);
    });

    test(
        'update preserves identifiers from the loaded order when detail omits them',
        () async {
      SharedPreferences.setMockInitialValues({});
      await SharedPrefsHelper.init();
      var getCount = 0;
      Map<String, dynamic>? putBody;
      final controller = SalesOrderController(
        getRequest: (endpoint) async {
          getCount++;
          if (getCount == 1) {
            return _response(endpoint, 200, {
              'id': 'so-1',
              'soNumber': 'SO-1',
              'date': '2026-10-16',
              'customerId': 'customer-1',
              'status': 'Draft',
              'mode': SalesOrderController.modeTonage,
            });
          }
          return _response(endpoint, 200, <dynamic>[]);
        },
        putRequest: (endpoint, body) async {
          putBody = body;
          return _response(endpoint, 200, {'success': true});
        },
      );

      final saved = await controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        organizationId: 'persisted-organization',
        branchId: 'persisted-branch',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );

      expect(saved, isTrue);
      expect(putBody?['organizationId'], 'persisted-organization');
      expect(putBody?.containsKey('branchId'), isFalse);
    });

    test('failed update does not report success or change local status',
        () async {
      SharedPreferences.setMockInitialValues({});
      await SharedPrefsHelper.init();
      final line = _validLine();
      final controller = SalesOrderController(
        getRequest: (endpoint) async => _response(endpoint, 200, {
          'id': 'so-1',
          'soNumber': 'SO-1',
          'date': '2026-10-16',
          'customerId': 'customer-1',
          'status': 'Draft',
          'mode': SalesOrderController.modeTonage,
          'lines': [line.toJson()],
        }),
        putRequest: (endpoint, body) async =>
            _response(endpoint, 422, {'message': 'Invalid line item'}),
      );

      final updated = await controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [line],
      );

      expect(updated, isFalse);
      expect(controller.salesOrders, isEmpty);
      expect(controller.isSaving.value, isFalse);
    });

    test('delete uses existing endpoint after verifying latest Draft status',
        () async {
      SharedPreferences.setMockInitialValues({});
      await SharedPrefsHelper.init();
      MobileAppPermissions.current = const MobileAppPermissions(
        mobileAppLogin: true,
        mobileAppLabourAttendance: false,
        modulePermissions: {'sales-order.delete'},
        hasModulePermissions: true,
      );
      final getPaths = <String>[];
      final deletePaths = <String>[];
      final draft = <String, dynamic>{
        'id': 'so-1',
        'soNumber': 'SO-1',
        'organizationId': 'organization-1',
        'branchId': 'branch-1',
        'date': '2026-10-16',
        'customerId': 'customer-1',
        'status': 'Draft',
        'mode': SalesOrderController.modeTonage,
      };
      final controller = SalesOrderController(
        getRequest: (endpoint) async {
          getPaths.add(endpoint);
          if (endpoint == 'sales-orders/so-1') {
            return _response(endpoint, 200, draft);
          }
          return _response(endpoint, 200, <dynamic>[]);
        },
        deleteRequest: (endpoint) async {
          deletePaths.add(endpoint);
          return _response(endpoint, 200, {'success': true});
        },
      );

      final deleted = await controller.deleteSalesOrder('so-1');

      expect(deleted, isTrue);
      expect(getPaths, ['sales-orders/so-1', 'sales-orders']);
      expect(deletePaths, ['sales-orders/so-1']);
      expect(controller.salesOrders, isEmpty);
      expect(controller.hasListError.value, isFalse);
    });

    test('delete blocks when latest Sales Order is no longer Draft', () async {
      var deleteCount = 0;
      final controller = SalesOrderController(
        getRequest: (endpoint) async => _response(endpoint, 200, {
          'id': 'so-1',
          'soNumber': 'SO-1',
          'status': 'Approved',
        }),
        deleteRequest: (endpoint) async {
          deleteCount++;
          return _response(endpoint, 200, {'success': true});
        },
      );

      final deleted = await controller.deleteSalesOrder('so-1');

      expect(deleted, isFalse);
      expect(deleteCount, 0);
    });

    test('approval uses existing PUT endpoint and verifies Approved status',
        () async {
      SharedPreferences.setMockInitialValues({});
      await SharedPrefsHelper.init();
      final line = _validLine();
      final getPaths = <String>[];
      Map<String, dynamic>? putBody;
      final draft = <String, dynamic>{
        'id': 'so-1',
        'soNumber': 'SO-1',
        'organizationId': 'organization-1',
        'branchId': 'branch-1',
        'date': '2026-10-16',
        'customerId': 'customer-1',
        'status': 'Draft',
        'mode': SalesOrderController.modeTonage,
      };
      final approvedOrder = <String, dynamic>{
        ...draft,
        'status': 'Approved',
        'lines': [line.toJson()],
      };
      final controller = SalesOrderController(
        getRequest: (endpoint) async {
          getPaths.add(endpoint);
          if (endpoint.endsWith('/so-1')) {
            return _response(endpoint, 200, draft);
          }
          return _response(endpoint, 200, [approvedOrder]);
        },
        putRequest: (endpoint, body) async {
          putBody = body;
          expect(endpoint, 'sales-orders/so-1');
          return _response(endpoint, 200, approvedOrder);
        },
      );

      final approved = await controller.approveSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [line],
      );

      expect(approved, isTrue);
      expect(putBody?['status'], 'Approved');
      expect(putBody?['organizationId'], 'organization-1');
      expect(putBody?.containsKey('branchId'), isFalse);
      expect(putBody?['soNumber'], 'SO-1');
      expect(getPaths, ['sales-orders/so-1', 'sales-orders']);
      expect(controller.salesOrders.single.status, 'Approved');
      expect(controller.isSaving.value, isFalse);
      expect(controller.isApproving.value, isFalse);
    });

    test('approval fails closed when permission is missing', () async {
      MobileAppPermissions.current = const MobileAppPermissions(
        mobileAppLogin: true,
        mobileAppLabourAttendance: false,
        modulePermissions: {'sales-order.edit'},
        hasModulePermissions: true,
      );
      var requestCount = 0;
      final controller = SalesOrderController(
        getRequest: (endpoint) async {
          requestCount++;
          return _response(endpoint, 200, <String, dynamic>{});
        },
        putRequest: (endpoint, body) async {
          requestCount++;
          return _response(endpoint, 200, <String, dynamic>{});
        },
      );

      final approved = await controller.approveSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );

      expect(approved, isFalse);
      expect(requestCount, 0);
      expect(toastMessages.last, contains('permission to approve'));
    });

    test('approval does not mark locally Approved without server confirmation',
        () async {
      final draft = <String, dynamic>{
        'id': 'so-1',
        'soNumber': 'SO-1',
        'date': '2026-10-16',
        'customerId': 'customer-1',
        'status': 'Draft',
        'mode': SalesOrderController.modeTonage,
      };
      final controller = SalesOrderController(
        getRequest: (endpoint) async => _response(endpoint, 200, draft),
        putRequest: (endpoint, body) async => _response(endpoint, 200, draft),
      );

      final approved = await controller.approveSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );

      expect(approved, isFalse);
      expect(controller.salesOrders, isEmpty);
      expect(controller.isSaving.value, isFalse);
    });

    test('duplicate approval submissions share one in-flight request',
        () async {
      SharedPreferences.setMockInitialValues({});
      await SharedPrefsHelper.init();
      final pendingOrder = Completer<Response<dynamic>?>();
      var preflightCount = 0;
      var putCount = 0;
      final controller = SalesOrderController(
        getRequest: (endpoint) {
          if (endpoint.endsWith('/so-1')) {
            preflightCount++;
            return pendingOrder.future;
          }
          return Future.value(_response(endpoint, 200, <dynamic>[]));
        },
        putRequest: (endpoint, body) async {
          putCount++;
          return _response(endpoint, 200, {
            'id': 'so-1',
            'soNumber': 'SO-1',
            'date': '2026-10-16',
            'customerId': 'customer-1',
            'status': 'Approved',
            'mode': SalesOrderController.modeTonage,
          });
        },
      );
      final firstRequest = controller.approveSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );
      await Future<void>.delayed(Duration.zero);

      final duplicateRequest = await controller.approveSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );
      pendingOrder.complete(_response('sales-orders/so-1', 200, {
        'id': 'so-1',
        'soNumber': 'SO-1',
        'organizationId': 'organization-1',
        'branchId': 'branch-1',
        'date': '2026-10-16',
        'customerId': 'customer-1',
        'status': 'Draft',
      }));

      expect(duplicateRequest, isFalse);
      expect(await firstRequest, isTrue);
      expect(preflightCount, 1);
      expect(putCount, 1);
      expect(controller.isSaving.value, isFalse);
    });
  });

  group('Sales Order create response handling', () {
    test('accepts successful create responses', () {
      final response = Response<dynamic>(
        requestOptions: RequestOptions(path: '/sales-orders'),
        statusCode: 201,
        data: {'success': true},
      );

      expect(
        SalesOrderController.isSuccessfulCreateResponse(response),
        isTrue,
      );
    });

    test('rejects failed HTTP and success-false responses', () {
      Response<dynamic> response({
        required int statusCode,
        dynamic data,
      }) =>
          Response<dynamic>(
            requestOptions: RequestOptions(path: '/sales-orders'),
            statusCode: statusCode,
            data: data,
          );

      expect(
        SalesOrderController.isSuccessfulCreateResponse(
          response(statusCode: 200, data: {'success': false}),
        ),
        isFalse,
      );
      expect(
        SalesOrderController.isSuccessfulCreateResponse(
          response(statusCode: 422, data: {'message': 'Invalid PO'}),
        ),
        isFalse,
      );
      expect(
        SalesOrderController.isSuccessfulCreateResponse(null),
        isFalse,
      );
    });
  });
}
