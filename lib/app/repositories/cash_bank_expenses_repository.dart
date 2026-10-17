import '../models/cash_bank_expense_model.dart';
import '../services/cash_bank_expenses_service.dart';

class CashBankExpensesRepository {
  CashBankExpensesRepository({
    CashBankExpensesService? service,
  }) : _service = service ?? CashBankExpensesService();

  final CashBankExpensesService _service;

  Future<List<CashBankExpense>> fetchExpenses() async {
    final response = await _service.fetchExpenses();
    CashBankExpensesService.requireSuccessful(
      response,
      'Unable to load cash / bank expenses.',
    );
    return CashBankExpensesService.decodeExpenseList(response!.data);
  }

  Future<List<CashBankBranch>> fetchBranches(String organizationId) async {
    final response = await _service.fetchBranches();
    CashBankExpensesService.requireSuccessful(
      response,
      'Unable to load branches.',
    );
    return CashBankExpensesService.decodeBranches(
      response!.data,
      organizationId: organizationId,
    );
  }

  Future<void> createExpense(CashBankExpense expense) async {
    final response = await _service.createExpense(expense.toRequestJson());
    CashBankExpensesService.requireSuccessful(
      response,
      'Unable to save cash / bank expense.',
    );
  }

  Future<void> updateExpense(CashBankExpense expense) async {
    final response = await _service.updateExpense(
      expense.id,
      expense.toRequestJson(),
    );
    CashBankExpensesService.requireSuccessful(
      response,
      'Unable to update cash / bank expense.',
    );
  }

  Future<void> approveExpense(String id) async {
    final response = await _service.approveExpense(id);
    CashBankExpensesService.requireSuccessful(
      response,
      'Unable to approve cash / bank expense.',
    );
  }

  Future<void> deleteExpense(String id) async {
    final response = await _service.deleteExpense(id);
    CashBankExpensesService.requireSuccessful(
      response,
      'Unable to delete cash / bank expense.',
    );
  }
}
