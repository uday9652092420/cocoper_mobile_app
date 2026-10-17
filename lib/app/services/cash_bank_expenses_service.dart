import 'package:dio/dio.dart';

import '../models/cash_bank_expense_model.dart';
import 'api_service.dart';
import 'endpoints.dart';

class CashBankExpensesService {
  Future<Response<dynamic>?> fetchExpenses() =>
      ApiService.get(EndPoints.cashBankExpenses);

  Future<Response<dynamic>?> fetchBranches() =>
      ApiService.get(EndPoints.branches);

  Future<Response<dynamic>?> createExpense(Map<String, dynamic> payload) =>
      ApiService.post(EndPoints.cashBankExpenses, payload);

  Future<Response<dynamic>?> updateExpense(
    String id,
    Map<String, dynamic> payload,
  ) =>
      ApiService.put(EndPoints.cashBankExpense(id), payload);

  Future<Response<dynamic>?> approveExpense(String id) =>
      ApiService.post(EndPoints.cashBankExpenseApproval(id), null);

  Future<Response<dynamic>?> deleteExpense(String id) =>
      ApiService.delete(EndPoints.cashBankExpense(id));

  static List<CashBankExpense> decodeExpenseList(dynamic body) {
    if (body is! Map || body['success'] != true || body['data'] is! List) {
      throw const CashBankExpensesApiException(
        'The server returned an invalid cash / bank expense list.',
      );
    }
    final result = <CashBankExpense>[];
    for (final row in body['data'] as List) {
      if (row is! Map) {
        throw const CashBankExpensesApiException(
          'The server returned an invalid expense record.',
        );
      }
      final expense = CashBankExpense.fromJson(
        Map<String, dynamic>.from(row),
      );
      if (expense.id.isEmpty ||
          expense.organizationId.isEmpty ||
          expense.branchId.isEmpty ||
          expense.date.isEmpty ||
          expense.paymentMode.isEmpty ||
          expense.transactionType.isEmpty ||
          !expense.amount.isFinite) {
        throw const CashBankExpensesApiException(
          'The server returned an incomplete expense record.',
        );
      }
      result.add(expense);
    }
    return result;
  }

  static List<CashBankBranch> decodeBranches(
    dynamic body, {
    required String organizationId,
  }) {
    if (body is! List) {
      throw const CashBankExpensesApiException(
        'The server returned an invalid branch list.',
      );
    }
    final result = <CashBankBranch>[];
    for (final row in body) {
      if (row is! Map) {
        throw const CashBankExpensesApiException(
          'The server returned an invalid branch record.',
        );
      }
      final branch = CashBankBranch.fromJson(
        Map<String, dynamic>.from(row),
      );
      if (branch.id.isEmpty ||
          branch.name.isEmpty ||
          branch.organizationId != organizationId ||
          (branch.status.isNotEmpty &&
              branch.status.toUpperCase() != 'ACTIVE')) {
        continue;
      }
      result.add(branch);
    }
    return result;
  }

  static void requireSuccessful(
    Response<dynamic>? response,
    String fallback,
  ) {
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
      throw CashBankExpensesApiException(
        message != null && message.isNotEmpty
            ? message
            : '$fallback${status == null ? '' : ' (HTTP $status)'}',
      );
    }
  }
}

class CashBankExpensesApiException implements Exception {
  final String message;

  const CashBankExpensesApiException(this.message);

  @override
  String toString() => message;
}
