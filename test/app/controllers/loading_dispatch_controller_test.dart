import 'package:dio/dio.dart';
import 'package:cocoper_mobile/app/models/loading_dispatch.dart';
import 'package:cocoper_mobile/app/repositories/loading_dispatch_repository.dart';
import 'package:cocoper_mobile/app/services/loading_dispatch_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validDispatch = LoadingDispatch(
    customerId: 'customer-id',
    lorryNumber: 'TN-01-AB-1234',
    driverName: 'Driver One',
    driverMobile: '9876543210',
    dispatchDate: '2026-10-17',
    dispatchStatus: 'Draft',
    lines: [
      LoadingDispatchLine(
        branchId: 'branch-id',
        date: '2026-10-17',
        itemId: 'item-id',
        bharthi: 'Standard',
        quantity: 10,
        pendingQuantity: 10,
      ),
    ],
  );

  test('validates complete draft dispatch with one or more loading lines', () {
    expect(LoadingDispatchService.validate(validDispatch), isNull);
    expect(
        validDispatch.toRequestJson().containsKey('dispatchNumber'), isFalse);
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(lines: const []),
      ),
      'Add at least one loading line.',
    );
  });

  test('rejects invalid header and loading line values', () {
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(customerId: ''),
      ),
      'Select a customer.',
    );
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(driverMobile: '98765-43210'),
      ),
      'Enter a valid driver mobile number.',
    );
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(lorryNumber: ''),
      ),
      'Enter a lorry number.',
    );
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(driverName: ''),
      ),
      'Enter the driver name.',
    );
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(
          lines: const [
            LoadingDispatchLine(
              date: '2026-10-17',
              itemId: 'item-id',
              bharthi: 'Standard',
              quantity: 10,
            ),
          ],
        ),
      ),
      'Loading line 1: select a branch.',
    );
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(
          lines: const [
            LoadingDispatchLine(
              branchId: 'branch-id',
              date: '2026-10-17',
              bharthi: 'Standard',
              quantity: 10,
            ),
          ],
        ),
      ),
      'Loading line 1: select an item.',
    );
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(
          lines: const [
            LoadingDispatchLine(
              branchId: 'branch-id',
              date: '2026-10-17',
              itemId: 'item-id',
              quantity: 10,
            ),
          ],
        ),
      ),
      'Loading line 1: select Gunny Bag (Bharthi).',
    );
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(
          lines: const [
            LoadingDispatchLine(
              branchId: 'branch-id',
              date: '2026-02-30',
              itemId: 'item-id',
              bharthi: 'Standard',
              quantity: 10,
            ),
          ],
        ),
      ),
      'Loading line 1: select a valid date.',
    );
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(
          lines: const [
            LoadingDispatchLine(
              branchId: 'branch-id',
              date: '2026-10-17',
              itemId: 'item-id',
              bharthi: 'Standard',
              quantity: 0,
            ),
          ],
        ),
      ),
      'Loading line 1: enter a quantity greater than zero.',
    );
  });

  test('create and edit requests share the verified save contract', () async {
    final repository = _FakeLoadingDispatchRepository();
    final service = LoadingDispatchService(repository: repository);

    await service.saveDispatch(validDispatch);
    expect(
      repository.savedPayloads.single,
      {
        'customerId': 'customer-id',
        'lorryNumber': 'TN-01-AB-1234',
        'driverName': 'Driver One',
        'driverMobile': '9876543210',
        'dispatchStatus': 'Draft',
        'dispatchDate': '2026-10-17',
        'invoiceGenerated': false,
        'lines': [
          {
            'branchId': 'branch-id',
            'date': '2026-10-17',
            'itemId': 'item-id',
            'bharthi': 'Standard',
            'quantity': 10.0,
            'loadedQuantity': 0.0,
            'pendingQuantity': 10.0,
          },
        ],
      },
    );

    await service.saveDispatch(
      validDispatch.copyWith(
        id: 'dispatch-1',
        dispatchNumber: 'DSP-2026-1',
      ),
    );
    expect(repository.savedPayloads.last['id'], 'dispatch-1');
    expect(
      repository.savedPayloads.last.containsKey('dispatchNumber'),
      isFalse,
    );
    expect(repository.savedPayloads.last['lines'], isA<List<dynamic>>());
  });

  test('serializes the reported quantity as a JSON number', () async {
    final repository = _FakeLoadingDispatchRepository();
    final service = LoadingDispatchService(repository: repository);
    final dispatch = LoadingDispatch(
      customerId: validDispatch.customerId,
      lorryNumber: validDispatch.lorryNumber,
      driverName: validDispatch.driverName,
      driverMobile: validDispatch.driverMobile,
      dispatchDate: '2026-10-19',
      dispatchStatus: 'Draft',
      lines: [
        LoadingDispatchLine(
          branchId: 'branch-id',
          date: '2026-10-19',
          itemId: 'item-id',
          bharthi: 'Gone Bag',
          quantity: 5000,
          pendingQuantity: 5000,
        ),
      ],
    );

    await service.saveDispatch(dispatch);

    final lines = repository.savedPayloads.single['lines'] as List<dynamic>;
    final line = lines.single as Map<String, dynamic>;
    expect(line['quantity'], 5000.0);
    expect(line['bharthi'], 'Gone Bag');
  });

  test('fetches dispatches and deletes by the selected database ID', () async {
    final repository = _FakeLoadingDispatchRepository()
      ..dispatchResponse = {
        'success': true,
        'data': [
          {
            'id': 'dispatch-1',
            'dispatchNumber': 'DSP-2026-1',
            'customerId': 'customer-id',
            'lines': <dynamic>[],
          },
        ],
      };
    final service = LoadingDispatchService(repository: repository);

    final dispatches = await service.fetchDispatches();
    expect(dispatches.single.id, 'dispatch-1');

    await service.deleteDispatch(dispatches.single.id);
    expect(repository.deletedIds, ['dispatch-1']);
  });

  test('loads Bharthi choices from the gunny bag master lookup', () async {
    final repository = _FakeLoadingDispatchRepository()
      ..gunnyBagResponse = {
        'success': true,
        'data': [
          {
            'bag_type_id': 'bag-1',
            'bag_name': 'Jute Bag',
            'bag_code': 'JB-01',
            'rate_per_bag': '20',
          },
        ],
      };
    final service = LoadingDispatchService(repository: repository);

    final options = await service.fetchGunnyBags();

    expect(options, hasLength(1));
    expect(options.single.id, 'bag-1');
    expect(options.single.name, 'Jute Bag');
    expect(options.single.label, 'Jute Bag (JB-01)');
  });

  test('distinguishes empty gunny bag master from malformed response',
      () async {
    final repository = _FakeLoadingDispatchRepository()
      ..gunnyBagResponse = {'success': true, 'data': <dynamic>[]};
    final service = LoadingDispatchService(repository: repository);

    expect(await service.fetchGunnyBags(), isEmpty);

    repository.gunnyBagResponse = {'success': true, 'data': 'unexpected'};
    await expectLater(
      service.fetchGunnyBags(),
      throwsA(
        isA<LoadingDispatchException>().having(
          (error) => error.message,
          'message',
          contains('invalid gunny bag list'),
        ),
      ),
    );
  });

  test('reports authentication errors for protected lookups', () async {
    final repository = _FakeLoadingDispatchRepository()
      ..gunnyBagStatusCode = 401;
    final service = LoadingDispatchService(repository: repository);

    await expectLater(
      service.fetchGunnyBags(),
      throwsA(
        isA<LoadingDispatchException>().having(
          (error) => error.message,
          'message',
          contains('Authentication failed'),
        ),
      ),
    );
  });

  test('distinguishes network and server failures for lookups', () async {
    final repository = _FakeLoadingDispatchRepository()
      ..gunnyBagNoResponse = true;
    final service = LoadingDispatchService(repository: repository);

    await expectLater(
      service.fetchGunnyBags(),
      throwsA(
        isA<LoadingDispatchException>().having(
          (error) => error.message,
          'message',
          contains('check the network connection'),
        ),
      ),
    );

    repository
      ..gunnyBagNoResponse = false
      ..gunnyBagStatusCode = 503;
    await expectLater(
      service.fetchGunnyBags(),
      throwsA(
        isA<LoadingDispatchException>().having(
          (error) => error.message,
          'message',
          contains('server returned HTTP 503'),
        ),
      ),
    );
  });

  test('preserves backend message when dispatch save returns HTTP 500',
      () async {
    final repository = _FakeLoadingDispatchRepository()
      ..saveStatusCode = 500
      ..saveResponse = {
        'success': false,
        'message': 'dispatch_number violates not-null constraint',
        'requestId': 'request-123',
      };
    final service = LoadingDispatchService(repository: repository);

    await expectLater(
      service.saveDispatch(validDispatch),
      throwsA(
        isA<LoadingDispatchException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('HTTP 500'),
            contains('dispatch_number violates not-null constraint'),
            contains('request-123'),
          ),
        ),
      ),
    );
  });
}

extension on LoadingDispatch {
  LoadingDispatch copyWith({
    String? id,
    String? dispatchNumber,
    String? customerId,
    String? lorryNumber,
    String? driverName,
    String? driverMobile,
    List<LoadingDispatchLine>? lines,
  }) =>
      LoadingDispatch(
        id: id ?? this.id,
        dispatchNumber: dispatchNumber ?? this.dispatchNumber,
        customerId: customerId ?? this.customerId,
        lorryNumber: lorryNumber ?? this.lorryNumber,
        driverName: driverName ?? this.driverName,
        driverMobile: driverMobile ?? this.driverMobile,
        dispatchDate: dispatchDate,
        dispatchStatus: dispatchStatus,
        invoiceGenerated: invoiceGenerated,
        lines: lines ?? this.lines,
      );
}

class _FakeLoadingDispatchRepository extends LoadingDispatchRepository {
  final savedPayloads = <Map<String, dynamic>>[];
  final deletedIds = <String>[];
  dynamic dispatchResponse = const <dynamic>[];
  dynamic gunnyBagResponse = const <dynamic>[];
  int gunnyBagStatusCode = 200;
  bool gunnyBagNoResponse = false;
  int saveStatusCode = 200;
  dynamic saveResponse = const {'success': true};

  Response<dynamic> _response(dynamic data, {int statusCode = 200}) =>
      Response<dynamic>(
        requestOptions: RequestOptions(path: '/'),
        statusCode: statusCode,
        data: data,
      );

  @override
  Future<Response<dynamic>?> fetchDispatches() async =>
      _response(dispatchResponse);

  @override
  Future<Response<dynamic>?> fetchGunnyBags() async => gunnyBagNoResponse
      ? null
      : _response(gunnyBagResponse, statusCode: gunnyBagStatusCode);

  @override
  Future<Response<dynamic>?> saveDispatch(
    Map<String, dynamic> payload,
  ) async {
    savedPayloads.add(payload);
    return _response(saveResponse, statusCode: saveStatusCode);
  }

  @override
  Future<Response<dynamic>?> deleteDispatch(String id) async {
    deletedIds.add(id);
    return _response({'success': true});
  }
}
