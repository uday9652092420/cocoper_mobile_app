import 'package:cocoper_mobile/app/services/endpoints.dart';
import 'package:cocoper_mobile/app/services/profit_loss_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Response<dynamic> _response(String path, dynamic data, {int status = 200}) =>
    Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
      data: data,
    );

void main() {
  test('requests all Web P&L sources and ISO stock snapshot date parameters',
      () async {
    final calls = <({String endpoint, Map<String, dynamic>? query})>[];
    final responses = <String, dynamic>{
      EndPoints.directSales: <dynamic>[],
      EndPoints.purchaseInvoices: <dynamic>[],
      EndPoints.cashBankExpenses: {'success': true, 'data': <dynamic>[]},
      EndPoints.profitLossStockSnapshot: {
        'success': true,
        'data': {
          'openingUnits': 0,
          'openingAmount': 0,
          'closingUnits': 0,
          'closingAmount': 0,
        },
      },
    };
    final service = ProfitLossService(
      get: (endpoint, {queryParameters}) async {
        calls.add((endpoint: endpoint, query: queryParameters));
        return _response(endpoint, responses[endpoint]);
      },
    );

    final statement = await service.load(
      fromDate: DateTime(2025, 5, 1),
      toDate: DateTime(2025, 5, 31),
    );

    expect(
      calls.map((call) => call.endpoint).toSet(),
      {
        EndPoints.directSales,
        EndPoints.purchaseInvoices,
        EndPoints.cashBankExpenses,
        EndPoints.profitLossStockSnapshot,
      },
    );
    final stockCall = calls.singleWhere(
      (call) => call.endpoint == EndPoints.profitLossStockSnapshot,
    );
    expect(stockCall.query, {'fromDate': '2025-05-01', 'toDate': '2025-05-31'});
    expect(statement.hasData, isFalse);
  });

  test('does not call the API for an invalid date range', () async {
    var callCount = 0;
    final service = ProfitLossService(
      get: (endpoint, {queryParameters}) async {
        callCount++;
        return _response(endpoint, const []);
      },
    );

    await expectLater(
      service.load(
        fromDate: DateTime(2025, 5, 2),
        toDate: DateTime(2025, 5, 1),
      ),
      throwsArgumentError,
    );
    expect(callCount, 0);
  });

  test('surfaces failed requests instead of returning zero totals', () async {
    final service = ProfitLossService(
      get: (endpoint, {queryParameters}) async => _response(
        endpoint,
        {'success': false, 'message': 'P&L permission required'},
        status: 403,
      ),
    );

    await expectLater(
      service.load(
        fromDate: DateTime(2025, 5, 1),
        toDate: DateTime(2025, 5, 31),
      ),
      throwsA(isA<Exception>()),
    );
  });
}
