import 'package:dio/dio.dart';

import '../helpers/form_validations_helper.dart';
import '../models/bag_purchase.dart';
import '../models/loading_dispatch.dart';
import '../models/lookup_option.dart';
import '../repositories/loading_dispatch_repository.dart';

class LoadingDispatchService {
  LoadingDispatchService({
    LoadingDispatchRepository? repository,
  }) : _repository = repository ?? LoadingDispatchRepository();

  final LoadingDispatchRepository _repository;

  Future<List<LoadingDispatch>> fetchDispatches() async {
    final response = await _repository.fetchDispatches();
    _requireSuccess(response, 'Unable to load dispatches.');
    final rows = _extractRows(response!.data);
    if (rows == null) {
      throw const LoadingDispatchException(
        'The server returned an invalid dispatch list.',
      );
    }
    final records = <LoadingDispatch>[];
    for (final row in rows) {
      if (row is! Map) {
        throw const LoadingDispatchException(
          'The server returned an invalid dispatch record.',
        );
      }
      final dispatch = LoadingDispatch.fromJson(
        Map<String, dynamic>.from(row),
      );
      if (dispatch.id.isEmpty) {
        throw const LoadingDispatchException(
          'The server returned an incomplete dispatch record.',
        );
      }
      records.add(dispatch);
    }
    return records;
  }

  Future<List<LookupOption>> fetchCustomers() async {
    final response = await _repository.fetchCustomers();
    _requireSuccess(response, 'Unable to load customers.');
    return _decodeOptions(response!.data, 'customer');
  }

  Future<List<LookupOption>> fetchBranches() async {
    final response = await _repository.fetchBranches();
    _requireSuccess(response, 'Unable to load branches.');
    final rows = _extractRows(response!.data);
    if (rows == null) {
      throw const LoadingDispatchException(
        'The server returned an invalid branch list.',
      );
    }
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) {
          final status = row['status']?.toString().trim();
          return status == null ||
              status.isEmpty ||
              status.toUpperCase() == 'ACTIVE';
        })
        .map(LookupOption.fromDynamic)
        .where((option) => option.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<LookupOption>> fetchItems() async {
    final response = await _repository.fetchItems();
    _requireSuccess(response, 'Unable to load items.');
    return _decodeOptions(response!.data, 'item');
  }

  Future<List<BagPurchaseLookup>> fetchGunnyBags() async {
    final response = await _repository.fetchGunnyBags();
    _requireSuccess(response, 'Unable to load gunny bag options.');
    final options = BagPurchaseLookup.decodeGunnyBagResponse(response!.data);
    if (options == null) {
      throw const LoadingDispatchException(
        'The server returned an invalid gunny bag list.',
      );
    }
    return options;
  }

  Future<void> saveDispatch(LoadingDispatch dispatch) async {
    final error = validate(dispatch);
    if (error != null) throw LoadingDispatchException(error);
    final response = await _repository.saveDispatch(dispatch.toRequestJson());
    _requireSuccess(response, 'Unable to save dispatch.');
  }

  Future<void> deleteDispatch(String id) async {
    if (id.trim().isEmpty) {
      throw const LoadingDispatchException(
        'The dispatch ID is missing; it cannot be deleted.',
      );
    }
    final response = await _repository.deleteDispatch(id);
    _requireSuccess(response, 'Unable to delete dispatch.');
  }

  static String? validate(LoadingDispatch dispatch) {
    if (dispatch.customerId.trim().isEmpty) return 'Select a customer.';
    if (dispatch.lorryNumber.trim().isEmpty) return 'Enter a lorry number.';
    if (dispatch.driverName.trim().isEmpty) return 'Enter the driver name.';
    final mobile = dispatch.driverMobile.trim();
    if (!ValidationUtils.isValidPhoneNumber(mobile)) {
      return 'Enter a valid driver mobile number.';
    }
    if (dispatch.lines.isEmpty) return 'Add at least one loading line.';
    for (var index = 0; index < dispatch.lines.length; index++) {
      final line = dispatch.lines[index];
      final prefix = 'Loading line ${index + 1}: ';
      if (line.branchId.trim().isEmpty) {
        return '${prefix}select a branch.';
      }
      final date = DateTime.tryParse(line.date);
      if (date == null ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(line.date) ||
          date.toIso8601String().substring(0, 10) != line.date) {
        return '${prefix}select a valid date.';
      }
      if (line.itemId.trim().isEmpty) return '${prefix}select an item.';
      if (line.bharthi.trim().isEmpty) {
        return '${prefix}select Gunny Bag (Bharthi).';
      }
      if (!line.quantity.isFinite || line.quantity <= 0) {
        return '${prefix}enter a quantity greater than zero.';
      }
    }
    return null;
  }

  static List<LookupOption> _decodeOptions(dynamic data, String label) {
    final rows = _extractRows(data);
    if (rows == null) {
      throw LoadingDispatchException(
        'The server returned an invalid $label list.',
      );
    }
    return rows
        .map(LookupOption.fromDynamic)
        .where((option) => option.id.isNotEmpty)
        .toList(growable: false);
  }

  static List<dynamic>? _extractRows(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) {
      return data['data'] as List<dynamic>;
    }
    return null;
  }

  static void _requireSuccess(
    Response<dynamic>? response,
    String fallback,
  ) {
    final status = response?.statusCode;
    if (response == null || status == null) {
      throw LoadingDispatchException(
        '$fallback No response was received; check the network connection '
        'and retry.',
      );
    }
    if (status == 401) {
      throw LoadingDispatchException(
        '$fallback Authentication failed (HTTP 401). Sign in again and retry.',
      );
    }
    if (status == 403) {
      throw LoadingDispatchException(
        '$fallback Access denied (HTTP 403). Check your organization access.',
      );
    }
    final body = response.data;
    final message = body is Map
        ? (body['message'] ?? body['error'])?.toString().trim()
        : null;
    final requestId =
        body is Map ? body['requestId']?.toString().trim() : null;
    final requestReference = requestId == null || requestId.isEmpty
        ? ''
        : ' Request ID: $requestId.';
    if (status >= 500) {
      throw LoadingDispatchException(
        message != null && message.isNotEmpty
            ? '$fallback The server returned HTTP $status: $message'
                '$requestReference'
            : '$fallback The server returned HTTP $status.'
                ' Please retry later.$requestReference',
      );
    }
    if (status < 200 ||
        status >= 300 ||
        (response.data is Map && response.data['success'] == false)) {
      throw LoadingDispatchException(
        message != null && message.isNotEmpty
            ? '$fallback $message (HTTP $status).$requestReference'
            : '$fallback Request failed with HTTP $status.'
                '$requestReference',
      );
    }
  }
}

class LoadingDispatchException implements Exception {
  const LoadingDispatchException(this.message);

  final String message;

  @override
  String toString() => message;
}
