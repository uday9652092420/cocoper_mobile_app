import 'package:dio/dio.dart';

import 'api_service.dart';

class StatementsReportService {
  Future<List<dynamic>> fetchList(String endpoint) async {
    final Response<dynamic>? response = await ApiService.get(endpoint);
    if (response == null) {
      throw Exception('No response received while loading $endpoint.');
    }
    final statusCode = response.statusCode;
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw Exception(_responseMessage(response.data, endpoint));
    }

    dynamic body = response.data;
    if (body is Map) {
      if (body['success'] == false) {
        throw Exception(_responseMessage(body, endpoint));
      }
      body = body['data'] ?? body['items'] ?? body['results'];
    }
    if (body is! List) {
      throw FormatException('Unexpected list response from $endpoint.');
    }
    return body;
  }

  static String _responseMessage(dynamic body, String endpoint) {
    if (body is Map) {
      final message = body['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
      final error = body['error']?.toString().trim();
      if (error != null && error.isNotEmpty) return error;
    }
    return 'Unable to load $endpoint.';
  }
}
