import 'dart:convert';

import 'package:get/get.dart';

import '../../helpers/flutter_toast.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/cash_bank_expense_model.dart';
import '../../repositories/cash_bank_expenses_repository.dart';
import '../../services/cash_bank_expenses_service.dart';

const _maxRequestBytes = 14 * 1024 * 1024;

class CashBankExpensesController extends GetxController {
  CashBankExpensesController({
    CashBankExpensesRepository? repository,
  }) : _repository = repository ?? CashBankExpensesRepository();

  final CashBankExpensesRepository _repository;
  final expenses = <CashBankExpense>[].obs;
  final branches = <CashBankBranch>[].obs;
  final searchQuery = ''.obs;
  final detail = Rxn<CashBankExpense>();
  final isLoadingList = false.obs;
  final isLoadingBranches = false.obs;
  final isLoadingDetail = false.obs;
  final isSaving = false.obs;
  final isMutating = false.obs;
  final hasListError = false.obs;
  final listError = ''.obs;
  final branchError = ''.obs;
  final detailError = ''.obs;
  String _organizationId = '';
  Future<void>? _listRequest;
  Future<void>? _branchRequest;

  List<CashBankExpense> get filteredExpenses {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return expenses.toList(growable: false);
    return expenses.where((expense) {
      return expense.branch.toLowerCase().contains(query) ||
          expense.paymentMode.toLowerCase().contains(query) ||
          expense.transactionType.toLowerCase().contains(query) ||
          expense.description.toLowerCase().contains(query) ||
          expense.date.toLowerCase().contains(query) ||
          expense.amount.toString().contains(query) ||
          expense.id.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  Future<void> loadExpenses({bool force = false}) async {
    final runningRequest = _listRequest;
    if (runningRequest != null) {
      if (!force) return runningRequest;
      await runningRequest;
    }
    final request = _performLoadExpenses();
    _listRequest = request;
    try {
      await request;
    } finally {
      if (identical(_listRequest, request)) _listRequest = null;
    }
  }

  Future<void> _performLoadExpenses() async {
    isLoadingList.value = true;
    hasListError.value = false;
    listError.value = '';
    try {
      expenses.assignAll(await _repository.fetchExpenses());
    } catch (error) {
      hasListError.value = true;
      listError.value = 'Unable to load cash / bank expenses: $error';
    } finally {
      isLoadingList.value = false;
    }
  }

  Future<void> refreshExpenses() => loadExpenses(force: true);

  Future<void> loadBranches() {
    final runningRequest = _branchRequest;
    if (runningRequest != null) return runningRequest;
    final request = _performLoadBranches();
    _branchRequest = request;
    return request.whenComplete(() {
      if (identical(_branchRequest, request)) _branchRequest = null;
    });
  }

  Future<void> _performLoadBranches() async {
    isLoadingBranches.value = true;
    branchError.value = '';
    try {
      _organizationId = await SharedPrefsHelper.getString(
        SharedPrefsHelper.organizationId,
      );
      if (_organizationId.trim().isEmpty) {
        throw const CashBankExpensesApiException(
          'Organization is unavailable. Please sign in again.',
        );
      }
      branches.assignAll(
        await _repository.fetchBranches(_organizationId),
      );
      if (branches.isEmpty) {
        throw const CashBankExpensesApiException(
          'No active branches are available for this organization.',
        );
      }
    } catch (error) {
      branchError.value = 'Unable to load branches: $error';
    } finally {
      isLoadingBranches.value = false;
    }
  }

  Future<CashBankExpense?> loadExpenseById(String id) async {
    detail.value = null;
    detailError.value = '';
    if (id.trim().isEmpty) {
      detailError.value = 'The expense ID is missing.';
      return null;
    }
    isLoadingDetail.value = true;
    try {
      final records = await _repository.fetchExpenses();
      expenses.assignAll(records);
      for (final expense in records) {
        if (expense.id == id) {
          if (!expense.hasAttachmentField || !expense.hasValidAttachmentData) {
            detailError.value = 'The expense response omitted attachment data.';
            return null;
          }
          detail.value = expense;
          return expense;
        }
      }
      detailError.value = 'Cash / bank expense not found.';
      return null;
    } catch (error) {
      detailError.value = 'Unable to load cash / bank expense: $error';
      return null;
    } finally {
      isLoadingDetail.value = false;
    }
  }

  Future<bool> createExpense(CashBankExpense expense) =>
      _save(expense, isEdit: false);

  Future<bool> updateExpense(CashBankExpense expense) =>
      _save(expense, isEdit: true);

  Future<bool> _save(
    CashBankExpense expense, {
    required bool isEdit,
  }) async {
    if (isSaving.value) return false;
    if (isEdit && expense.approved) {
      errorToast('Approved cash / bank expenses cannot be edited.');
      return false;
    }
    final validationError = validate(expense, isEdit: isEdit);
    if (validationError != null) {
      errorToast(validationError);
      return false;
    }
    if (isEdit &&
        (!expense.hasAttachmentField || !expense.hasValidAttachmentData)) {
      errorToast(
        'Existing attachment data is unavailable. This update is blocked to '
        'prevent file loss.',
      );
      return false;
    }
    final requestBytes =
        utf8.encode(jsonEncode(expense.toRequestJson())).length;
    if (requestBytes > _maxRequestBytes) {
      errorToast('Attachments exceed the 14 MB request size limit.');
      return false;
    }

    isSaving.value = true;
    try {
      if (isEdit) {
        await _repository.updateExpense(expense);
      } else {
        await _repository.createExpense(expense);
      }
      await loadExpenses(force: true);
      if (hasListError.value) {
        errorToast(
          'The expense was saved, but its list could not be refreshed: '
          '${listError.value}',
        );
      } else {
        successToast(
          isEdit
              ? 'Cash / bank expense updated successfully.'
              : 'Cash / bank expense saved successfully.',
        );
      }
      return true;
    } catch (error) {
      errorToast(
        'Unable to ${isEdit ? 'update' : 'save'} cash / bank expense: $error',
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> approveExpense(CashBankExpense expense) =>
      _mutate(expense, approve: true);

  Future<bool> deleteExpense(CashBankExpense expense) =>
      _mutate(expense, approve: false);

  Future<bool> _mutate(
    CashBankExpense expense, {
    required bool approve,
  }) async {
    if (isMutating.value || expense.id.isEmpty || expense.approved) {
      return false;
    }
    isMutating.value = true;
    try {
      if (approve) {
        await _repository.approveExpense(expense.id);
      } else {
        await _repository.deleteExpense(expense.id);
      }
      await loadExpenses(force: true);
      if (hasListError.value) {
        errorToast(
          '${approve ? 'Action succeeded' : 'Delete succeeded'}, but the '
          'expense list could not be refreshed: ${listError.value}',
        );
      } else {
        successToast(
          approve
              ? 'Cash / bank expense approved.'
              : 'Cash / bank expense deleted.',
        );
      }
      return true;
    } catch (error) {
      errorToast(
        'Unable to ${approve ? 'approve' : 'delete'} cash / bank expense: '
        '$error',
      );
      return false;
    } finally {
      isMutating.value = false;
    }
  }

  static String? validate(
    CashBankExpense expense, {
    required bool isEdit,
  }) {
    if (isEdit && expense.id.trim().isEmpty) {
      return 'The expense ID is missing.';
    }
    if (expense.branchId.trim().isEmpty) return 'Select a branch.';
    final date = DateTime.tryParse(expense.date);
    if (date == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expense.date) ||
        date.toIso8601String().substring(0, 10) != expense.date) {
      return 'Enter a valid expense date.';
    }
    if (!const {'Cash', 'Bank', 'UPI'}.contains(expense.paymentMode)) {
      return 'Select a supported payment mode.';
    }
    if (!const {'Expenses', 'Income'}.contains(expense.transactionType)) {
      return 'Select a transaction type.';
    }
    if (!expense.amount.isFinite || expense.amount <= 0) {
      return 'Enter an amount greater than zero.';
    }
    if (expense.attachments.length > 5) {
      return 'You can attach up to 5 files.';
    }
    for (final attachment in expense.attachments) {
      if (!const {
            'image/png',
            'image/jpeg',
            'application/pdf',
          }.contains(attachment.mimeType) ||
          attachment.name.isEmpty ||
          !attachment.data.startsWith('data:')) {
        return 'The attachment data is invalid.';
      }
    }
    return null;
  }
}
