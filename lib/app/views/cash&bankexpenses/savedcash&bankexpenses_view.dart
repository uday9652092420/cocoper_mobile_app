// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/cash&bankexpenses/cash_bank_expenses_controller.dart';
import '../../models/cash_bank_expense_model.dart';
import '../../routes/app_routes.dart';

const _ink = Color(0xFF14342B);
const _muted = Color(0xFF5C6B66);
const _line = Color(0xFFE4EBE4);
const _green = Color(0xFF2D8135);

class SavedCashBankExpensesView extends StatefulWidget {
  const SavedCashBankExpensesView({super.key});

  @override
  State<SavedCashBankExpensesView> createState() =>
      _SavedCashBankExpensesViewState();
}

class _SavedCashBankExpensesViewState extends State<SavedCashBankExpensesView> {
  final CashBankExpensesController _controller =
      Get.find<CashBankExpensesController>();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.loadExpenses();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE9F3E6), Color(0xFFFDFEFC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _controller.refreshExpenses,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 20),
                      _newExpenseButton(),
                      const SizedBox(height: 16),
                      _searchBar(),
                      const SizedBox(height: 22),
                      _expenseList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _header() => Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Get.back<void>(),
            icon: const Icon(Icons.arrow_back_ios_new, color: _ink),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cash & Bank Expenses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Saved cash and bank transactions',
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _controller.refreshExpenses,
            icon: const Icon(Icons.refresh, color: _muted),
          ),
        ],
      );

  Widget _newExpenseButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await Get.toNamed<dynamic>(Routes.newCashBankExpense);
            await _controller.refreshExpenses();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.add_circle_outline, size: 20),
          label: const Text(
            'Add New Cash & Bank Expense',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      );

  Widget _searchBar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 19, color: _muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (value) => _controller.searchQuery.value = value,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search by branch, type, or description',
                  hintStyle: TextStyle(fontSize: 13.5, color: _muted),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            Obx(
              () => _controller.searchQuery.value.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        _controller.searchQuery.value = '';
                      },
                      icon: const Icon(Icons.close, size: 18, color: _muted),
                    ),
            ),
          ],
        ),
      );

  Widget _expenseList() => Obx(() {
        if (_controller.isLoadingList.value && _controller.expenses.isEmpty) {
          return _stateCard(
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator(color: _green)),
            ),
          );
        }
        if (_controller.hasListError.value) {
          return _stateCard(
            Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 38,
                  color: Color(0xFFB3261E),
                ),
                const SizedBox(height: 8),
                Text(_controller.listError.value, textAlign: TextAlign.center),
                TextButton(
                  onPressed: _controller.refreshExpenses,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final records = _controller.filteredExpenses;
        if (records.isEmpty) {
          final searched = _controller.searchQuery.value.isNotEmpty;
          return _stateCard(
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Icon(
                    searched ? Icons.search_off : Icons.savings_outlined,
                    size: 36,
                    color: _muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    searched
                        ? 'No expenses match your search.'
                        : 'No saved cash / bank expenses.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final expense in records) ...[
              _expenseCard(expense),
              const SizedBox(height: 10),
            ],
          ],
        );
      });

  Widget _expenseCard(CashBankExpense expense) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Get.toNamed<void>(
            Routes.viewCashBankExpense,
            arguments: expense.id,
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        expense.branch.isEmpty ? 'Branch' : expense.branch,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                    _status(expense.approved),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${expense.transactionType} · ${expense.paymentMode} · '
                  '${_displayDate(expense.date)}',
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
                const SizedBox(height: 5),
                Text(
                  '₹${NumberFormat('#,##0.##').format(expense.amount)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _green,
                  ),
                ),
                if (expense.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    expense.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _muted),
                  ),
                ],
                if (expense.attachments.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${expense.attachments.length} attachment(s)',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
                const Divider(height: 20, color: _line),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    TextButton.icon(
                      onPressed: () => Get.toNamed<void>(
                        Routes.viewCashBankExpense,
                        arguments: expense.id,
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View'),
                    ),
                    if (!expense.approved) ...[
                      TextButton.icon(
                        onPressed: () async {
                          final result = await Get.toNamed<dynamic>(
                            Routes.editCashBankExpense,
                            arguments: expense.id,
                          );
                          if (result == true) {
                            await _controller.refreshExpenses();
                          }
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                      TextButton.icon(
                        onPressed: () => _confirmApprove(expense),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Approve'),
                      ),
                      TextButton.icon(
                        onPressed: () => _confirmDelete(expense),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFB3261E),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _confirmApprove(CashBankExpense expense) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Approve expense?'),
        content: const Text(
          'Approved expenses cannot be edited or deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.approveExpense(expense);
  }

  Future<void> _confirmDelete(CashBankExpense expense) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.deleteExpense(expense);
  }

  Widget _status(bool approved) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: approved ? const Color(0xFFE7F3E4) : const Color(0xFFFDF2E2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          approved ? 'Approved' : 'Draft',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: approved ? _green : const Color(0xFF8A5B00),
          ),
        ),
      );

  Widget _stateCard(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );

  String _displayDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : DateFormat('dd/MM/yyyy').format(parsed);
  }
}
