import 'package:dio/dio.dart';

import '../models/finance_journal.dart';
import 'api_service.dart';
import 'endpoints.dart';

typedef FinanceGetRequest = Future<Response<dynamic>?> Function(
  String endpoint, {
  Map<String, dynamic>? queryParameters,
});
typedef FinancePostRequest = Future<Response<dynamic>?> Function(
  String endpoint,
  dynamic body,
);
typedef FinancePutRequest = Future<Response<dynamic>?> Function(
  String endpoint,
  Map<String, dynamic> body,
);
typedef FinanceDeleteRequest = Future<Response<dynamic>?> Function(
  String endpoint,
);

class FinanceJournalService {
  FinanceJournalService({
    FinanceGetRequest? get,
    FinancePostRequest? post,
    FinancePutRequest? put,
    FinanceDeleteRequest? delete,
  })  : _get = get ?? ApiService.get,
        _post = post ?? ApiService.post,
        _put = put ?? ApiService.put,
        _delete = delete ?? _defaultDelete;

  final FinanceGetRequest _get;
  final FinancePostRequest _post;
  final FinancePutRequest _put;
  final FinanceDeleteRequest _delete;

  static Future<Response<dynamic>?> _defaultDelete(String endpoint) =>
      ApiService.delete(endpoint);

  Future<List<FinanceJournal>> fetchJournals({
    required String sourceType,
    String? branchId,
  }) async {
    final response = await _get(
      EndPoints.financeJournals,
      queryParameters: <String, dynamic>{
        'sourceType': sourceType,
        if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      },
    );
    final data = _requireData(response, 'Unable to load journal entries.');
    if (data is! List) {
      throw const FinanceJournalApiException(
        'The server returned an invalid journal list.',
      );
    }
    return data.map((row) {
      if (row is! Map) {
        throw const FinanceJournalApiException(
          'The server returned an invalid journal record.',
        );
      }
      final journal = FinanceJournal.fromJson(
        Map<String, dynamic>.from(row),
      );
      if (journal.id.isEmpty ||
          journal.date.isEmpty ||
          journal.status.isEmpty) {
        throw const FinanceJournalApiException(
          'The server returned an incomplete journal record.',
        );
      }
      return journal;
    }).toList(growable: false);
  }

  Future<FinanceJournal> fetchJournal(String id) async {
    final response = await _get(EndPoints.financeJournal(id));
    final data = _requireData(response, 'Unable to load journal entry.');
    if (data is! Map) {
      throw const FinanceJournalApiException(
        'The server returned an invalid journal entry.',
      );
    }
    final journal = FinanceJournal.fromJson(Map<String, dynamic>.from(data));
    if (journal.id.isEmpty || journal.lines.isEmpty) {
      throw const FinanceJournalApiException(
        'The server returned an incomplete journal entry.',
      );
    }
    return journal;
  }

  Future<List<FinanceAccount>> fetchAccounts() async {
    final response = await _get(EndPoints.financeAccounts);
    final data = _requireData(response, 'Unable to load accounts.');
    if (data is! List) {
      throw const FinanceJournalApiException(
        'The server returned an invalid account list.',
      );
    }
    return data.map((row) {
      if (row is! Map) {
        throw const FinanceJournalApiException(
          'The server returned an invalid account record.',
        );
      }
      return FinanceAccount.fromJson(Map<String, dynamic>.from(row));
    }).toList(growable: false);
  }

  Future<List<FinanceBankAccount>> fetchBankAccounts() async {
    final response = await _get(EndPoints.financeBankAccounts);
    final data = _requireData(response, 'Unable to load cash accounts.');
    if (data is! List) {
      throw const FinanceJournalApiException(
        'The server returned an invalid bank account list.',
      );
    }
    return data.map((row) {
      if (row is! Map) {
        throw const FinanceJournalApiException(
          'The server returned an invalid bank account record.',
        );
      }
      return FinanceBankAccount.fromJson(Map<String, dynamic>.from(row));
    }).toList(growable: false);
  }

  Future<({List<FinanceBranch> branches, String defaultBranchId})>
      fetchBranches() async {
    final response = await _get(EndPoints.mobileBootstrap);
    final data = _requireData(response, 'Unable to load assigned branches.');
    if (data is! Map || data['branches'] is! List) {
      throw const FinanceJournalApiException(
        'The server returned an invalid branch list.',
      );
    }
    final branches = (data['branches'] as List).map((row) {
      if (row is! Map) {
        throw const FinanceJournalApiException(
          'The server returned an invalid branch record.',
        );
      }
      return FinanceBranch.fromJson(Map<String, dynamic>.from(row));
    }).toList(growable: false);
    return (
      branches: branches,
      defaultBranchId: data['default_branch_id']?.toString().trim() ?? '',
    );
  }

  Future<void> createJournal(Map<String, dynamic> payload) async {
    final response = await _post(EndPoints.financeJournals, payload);
    _requireData(response, 'Unable to save journal entry.');
  }

  Future<void> updateJournal(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _put(EndPoints.financeJournal(id), payload);
    _requireData(response, 'Unable to update journal entry.');
  }

  Future<void> postJournal(
    String id, {
    bool confirmBudgetExceeded = false,
  }) async {
    final response = await _post(
      EndPoints.financeJournalPost(id),
      confirmBudgetExceeded
          ? <String, dynamic>{'confirmBudgetExceeded': true}
          : null,
    );
    _requireData(response, 'Unable to post journal entry.');
  }

  Future<void> reverseJournal(String id) async {
    final response =
        await _post(EndPoints.financeJournalReverse(id), <String, dynamic>{});
    _requireData(response, 'Unable to reverse journal entry.');
  }

  Future<void> deleteJournal(String id) async {
    final response = await _delete(EndPoints.financeJournal(id));
    _requireData(response, 'Unable to delete journal entry.');
  }

  dynamic _requireData(Response<dynamic>? response, String fallback) {
    final status = response?.statusCode;
    final body = response?.data;
    final failedStatus = status == null || status < 200 || status >= 300;
    if (response == null ||
        failedStatus ||
        (body is Map && body['success'] == false)) {
      throw FinanceJournalApiException(
        _errorMessage(body, fallback, status),
        code: _errorCode(body),
        details: body is Map ? body['details'] : null,
        statusCode: status,
      );
    }
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  String _errorMessage(dynamic body, String fallback, int? status) {
    if (status == 401) {
      return 'Your session has expired. Please sign in again.';
    }
    if (body is Map) {
      final error = body['error'];
      final message =
          body['message'] ?? (error is Map ? error['message'] : error);
      if (message is String && message.trim().isNotEmpty) return message.trim();
    }
    return '$fallback${status == null ? '' : ' (HTTP $status)'}';
  }

  String? _errorCode(dynamic body) {
    if (body is! Map) return null;
    final error = body['error'];
    final value = body['code'] ?? (error is Map ? error['code'] : null);
    return value?.toString();
  }
}

class FinanceJournalApiException implements Exception {
  const FinanceJournalApiException(
    this.message, {
    this.code,
    this.details,
    this.statusCode,
  });

  final String message;
  final String? code;
  final dynamic details;
  final int? statusCode;

  @override
  String toString() => message;
}
