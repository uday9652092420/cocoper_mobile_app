import 'package:dio/dio.dart';

import '../models/profit_loss_statement.dart';
import 'api_service.dart';
import 'endpoints.dart';

typedef ProfitLossGet = Future<Response<dynamic>?> Function(
  String endpoint, {
  Map<String, dynamic>? queryParameters,
});

class ProfitLossService {
  ProfitLossService({ProfitLossGet? get}) : _get = get ?? _getFromApi;

  final ProfitLossGet _get;

  Future<ProfitLossStatement> load({
    required DateTime fromDate,
    required DateTime toDate,
    String? organizationId,
  }) async {
    if (_day(toDate).isBefore(_day(fromDate))) {
      throw ArgumentError('To Date must be on or after From Date.');
    }

    final from = _formatDate(fromDate);
    final to = _formatDate(toDate);
    final responses = await Future.wait([
      _get(EndPoints.directSales),
      _get(EndPoints.purchaseInvoices),
      _get(EndPoints.cashBankExpenses),
      _get(
        EndPoints.profitLossStockSnapshot,
        queryParameters: {'fromDate': from, 'toDate': to},
      ),
    ]);

    final sales = _listData(responses[0], EndPoints.directSales);
    final purchases = _listData(responses[1], EndPoints.purchaseInvoices);
    final cashBankEntries =
        _listData(responses[2], EndPoints.cashBankExpenses);
    final stockSnapshot =
        _mapData(responses[3], EndPoints.profitLossStockSnapshot);

    return ProfitLossStatement.fromRecords(
      sales: sales,
      purchases: purchases,
      cashBankEntries: cashBankEntries,
      stockSnapshot: stockSnapshot,
      fromDate: fromDate,
      toDate: toDate,
      organizationId: organizationId,
    );
  }

  static Future<Response<dynamic>?> _getFromApi(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) =>
      ApiService.get(endpoint, queryParameters: queryParameters);

  static List<dynamic> _listData(
    Response<dynamic>? response,
    String endpoint,
  ) {
    final body = _body(response, endpoint);
    dynamic data = body;
    if (data is Map) {
      if (data['success'] == false) throw _responseException(data, endpoint);
      data = data['data'] ?? data['items'] ?? data['results'];
    }
    if (data is! List) {
      throw FormatException('Unexpected list response from $endpoint.');
    }
    return data;
  }

  static Map<String, dynamic> _mapData(
    Response<dynamic>? response,
    String endpoint,
  ) {
    final body = _body(response, endpoint);
    dynamic data = body;
    if (data is Map) {
      if (data['success'] == false) throw _responseException(data, endpoint);
      if (data.containsKey('success') && data.containsKey('data')) {
        data = data['data'];
      }
    }
    if (data is! Map) {
      throw FormatException('Unexpected object response from $endpoint.');
    }
    return Map<String, dynamic>.from(data);
  }

  static dynamic _body(Response<dynamic>? response, String endpoint) {
    if (response == null) {
      throw Exception('No response received while loading $endpoint.');
    }
    final statusCode = response.statusCode;
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw _responseException(response.data, endpoint);
    }
    return response.data;
  }

  static Exception _responseException(dynamic body, String endpoint) {
    if (body is Map) {
      final message = body['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return Exception(message);
      final error = body['error']?.toString().trim();
      if (error != null && error.isNotEmpty) return Exception(error);
    }
    return Exception('Unable to load $endpoint.');
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
