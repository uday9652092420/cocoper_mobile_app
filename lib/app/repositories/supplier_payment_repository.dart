import 'package:dio/dio.dart';

import '../models/lookup_option.dart';
import '../models/purchase_invoice.dart';
import '../models/supplier_payment.dart';
import '../services/api_service.dart';
import '../services/endpoints.dart';

class SupplierPaymentRepository {
  Future<List<SupplierPayment>> fetchSupplierPayments() async {
    final response = await ApiService.get(EndPoints.supplierPayments);
    _requireSuccess(response, 'Unable to load supplier payments.');
    return _decodePaymentList(response!.data);
  }

  Future<List<LookupOption>> fetchSuppliers() async {
    final response = await ApiService.get(EndPoints.suppliers);
    _requireSuccess(response, 'Unable to load suppliers.');
    final data = _envelopeList(response!.data);
    return data
        .map(LookupOption.fromDynamic)
        .where((supplier) => supplier.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<PurchaseInvoice>> fetchPurchaseInvoices() async {
    final response = await ApiService.get(EndPoints.purchaseInvoices);
    _requireSuccess(response, 'Unable to load purchase invoices.');
    final raw = response!.data;
    if (raw is! List) {
      throw const SupplierPaymentApiException(
        'The purchase invoice response did not contain a list.',
      );
    }
    return _mapRows(raw).map(PurchaseInvoice.fromJson).toList(growable: false);
  }

  Future<String> fetchNextPaymentNumber() async {
    final response = await ApiService.get(EndPoints.nextSupplierPaymentNumber);
    _requireSuccess(response, 'Unable to generate a supplier payment number.');
    final body = response!.data;
    final value = body is Map && body['success'] == true ? body['data'] : null;
    if (value is! String || value.trim().isEmpty) {
      throw const SupplierPaymentApiException(
        'The server did not return a supplier payment number.',
      );
    }
    return value.trim();
  }

  Future<Response<dynamic>?> createSupplierPayment(
    Map<String, dynamic> body,
  ) =>
      ApiService.post(EndPoints.supplierPayments, body);

  Future<Response<dynamic>?> updateSupplierPayment(
    String id,
    Map<String, dynamic> body,
  ) =>
      ApiService.put(EndPoints.supplierPayment(id), body);

  static bool isSuccessfulResponse(Response<dynamic>? response) =>
      response != null &&
      (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) &&
      !(response.data is Map && response.data['success'] == false);

  static String responseMessage(dynamic body, String fallback) {
    if (body is Map) {
      final value = body['message'] ?? body['error'];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  static List<SupplierPayment> _decodePaymentList(dynamic body) =>
      _envelopeList(body).map(SupplierPayment.fromJson).toList(growable: false);

  static List<Map<String, dynamic>> _envelopeList(dynamic body) {
    if (body is Map && body['success'] == true && body['data'] is List) {
      return _mapRows(body['data'] as List);
    }
    throw const SupplierPaymentApiException(
      'The server returned an invalid supplier payment response.',
    );
  }

  static List<Map<String, dynamic>> _mapRows(List<dynamic> rows) {
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row is! Map) {
        throw const SupplierPaymentApiException(
          'The server returned an invalid supplier payment record.',
        );
      }
      result.add(Map<String, dynamic>.from(row));
    }
    return result;
  }

  static void _requireSuccess(Response<dynamic>? response, String fallback) {
    final status = response?.statusCode;
    if (response == null ||
        status == null ||
        status < 200 ||
        status >= 300 ||
        (response.data is Map && response.data['success'] == false)) {
      final body = response?.data;
      final message = body is Map
          ? (body['message'] ?? body['error'])?.toString().trim()
          : null;
      throw SupplierPaymentApiException(
        message != null && message.isNotEmpty
            ? message
            : '$fallback${status == null ? '' : ' (HTTP $status)'}',
      );
    }
  }
}

class SupplierPaymentApiException implements Exception {
  final String message;

  const SupplierPaymentApiException(this.message);

  @override
  String toString() => message;
}
