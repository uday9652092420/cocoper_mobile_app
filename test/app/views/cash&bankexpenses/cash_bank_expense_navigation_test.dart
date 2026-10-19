import 'package:cocoper_mobile/app/controllers/cash&bankexpenses/cash_bank_expenses_controller.dart';
import 'package:cocoper_mobile/app/controllers/dashboard/dashboard_controller.dart';
import 'package:cocoper_mobile/app/models/cash_bank_expense_model.dart';
import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/views/cash&bankexpenses/savedcash&bankexpenses_view.dart';
import 'package:cocoper_mobile/app/views/cash&bankexpenses/viewcash&bankexpenses_view.dart';
import 'package:cocoper_mobile/app/views/dashboard/operations_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _expense = CashBankExpense(
  id: 'expense-1',
  organizationId: 'org-1',
  branchId: 'branch-1',
  branch: 'Main Branch',
  date: '2026-10-17',
  paymentMode: 'Bank',
  transactionType: 'Expenses',
  amount: 1250.5,
  description: 'Office supplies',
  hasAttachmentField: true,
  hasValidAttachmentData: true,
);

const _expenseWithAttachment = CashBankExpense(
  id: 'expense-1',
  organizationId: 'org-1',
  branchId: 'branch-1',
  branch: 'Main Branch',
  date: '2026-10-17',
  paymentMode: 'Bank',
  transactionType: 'Expenses',
  amount: 1250.5,
  description: 'Office supplies',
  attachments: [
    CashBankExpenseAttachment(
      name: 'receipt.pdf',
      mimeType: 'application/pdf',
      data: 'data:application/pdf;base64,AQID',
    ),
  ],
  hasAttachmentField: true,
  hasValidAttachmentData: true,
);

late _TestCashBankExpensesController _controller;

Future<void> _pumpOperations(WidgetTester tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: '/test_operations',
      getPages: [
        GetPage(name: '/test_operations', page: () => const OperationsView()),
        ...AppPages.routes,
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSavedList(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Cash & Bank'));
  await tester.tap(find.text('Cash & Bank'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(Get.currentRoute, Routes.savedCashBankExpenses);
}

void main() {
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'organizationId': 'org-1',
      'selectedBranchId': 'branch-1',
    });
    _controller = _TestCashBankExpensesController();
    Get.put<CashBankExpensesController>(_controller);
  });

  tearDown(Get.reset);

  testWidgets('Operations opens the registered Cash & Bank Expenses screen',
      (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/test_operations',
        getPages: [
          GetPage(name: '/test_operations', page: () => const OperationsView()),
          ...AppPages.routes,
        ],
      ),
    );

    await tester.ensureVisible(find.text('Cash & Bank'));
    await tester.tap(find.text('Cash & Bank'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.savedCashBankExpenses);
    expect(find.byType(SavedCashBankExpensesView), findsOneWidget);
    expect(find.text('Add New Cash & Bank Expense'), findsOneWidget);
    expect(find.text('No saved cash / bank expenses.'), findsOneWidget);
  });

  testWidgets('Add New opens the form and saves a valid expense', (
    tester,
  ) async {
    await _pumpOperations(tester);
    await _openSavedList(tester);
    await tester.tap(find.text('Add New Cash & Bank Expense'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.newCashBankExpense);
    expect(find.text('New Cash & Bank Expense'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    expect(_controller.createdExpense, isNull);

    await tester.enterText(find.byType(TextFormField).at(1), '1250.50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_controller.createdExpense?.amount, 1250.5);
    expect(_controller.createdExpense?.branchId, 'branch-1');
    expect(_controller.createdExpense?.paymentMode, 'Cash');
    expect(Get.currentRoute, Routes.savedCashBankExpenses);
  });

  testWidgets('Edit updates the selected record instead of creating one', (
    tester,
  ) async {
    _controller.expenses.assignAll([_expense]);
    await _pumpOperations(tester);
    await _openSavedList(tester);

    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.editCashBankExpense);
    expect(find.text('Edit Cash & Bank Expense'), findsOneWidget);
    final amountField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );
    expect(amountField.controller?.text, '1250.5');

    await tester.enterText(find.byType(TextFormField).at(1), '2000');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(_controller.updatedExpense?.id, 'expense-1');
    expect(_controller.updatedExpense?.amount, 2000);
    expect(_controller.createdExpense, isNull);
    expect(Get.currentRoute, Routes.savedCashBankExpenses);
  });

  testWidgets('View shows saved details without exposing edit controls', (
    tester,
  ) async {
    _controller.expenses.assignAll([_expense]);
    await _pumpOperations(tester);
    await _openSavedList(tester);
    await tester.ensureVisible(find.text('View'));
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.viewCashBankExpense);
    expect(find.byType(ViewCashBankExpenseView), findsOneWidget);
    expect(find.text('Main Branch'), findsOneWidget);
    expect(find.text('Office supplies'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNothing);
  });

  testWidgets('Draft delete action asks for confirmation and deletes', (
    tester,
  ) async {
    _controller.expenses.assignAll([_expense]);
    await _pumpOperations(tester);
    await _openSavedList(tester);
    await tester.ensureVisible(find.text('Delete'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete expense?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(_controller.deletedExpenseId, 'expense-1');
  });

  testWidgets('Draft approve action asks for confirmation and approves', (
    tester,
  ) async {
    _controller.expenses.assignAll([_expense]);
    await _pumpOperations(tester);
    await _openSavedList(tester);
    await tester.ensureVisible(find.text('Approve'));
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Approve expense?'), findsOneWidget);
    await tester.tap(find.text('Approve').last);
    await tester.pumpAndSettle();
    expect(_controller.approvedExpenseId, 'expense-1');
  });

  testWidgets('Edit can remove the last existing attachment', (tester) async {
    _controller.expenses.assignAll([_expenseWithAttachment]);
    await _pumpOperations(tester);
    await _openSavedList(tester);
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('receipt.pdf'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove receipt.pdf'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(_controller.updatedExpense?.id, 'expense-1');
    expect(_controller.updatedExpense?.attachments, isEmpty);
  });

  test('Dashboard starts on the Operations tab', () {
    expect(DashboardController().selectedIndex.value, 1);
  });
}

class _TestCashBankExpensesController extends CashBankExpensesController {
  _TestCashBankExpensesController() {
    branches.assignAll(const [
      CashBankBranch(
        id: 'branch-1',
        organizationId: 'org-1',
        name: 'Main Branch',
      ),
    ]);
  }

  CashBankExpense? createdExpense;
  CashBankExpense? updatedExpense;
  String? deletedExpenseId;
  String? approvedExpenseId;

  @override
  Future<void> loadExpenses({bool force = false}) async {}

  @override
  Future<void> loadBranches() async {}

  @override
  Future<CashBankExpense?> loadExpenseById(String id) async {
    final expense = expenses.firstWhere(
      (record) => record.id == id,
      orElse: () => _expense,
    );
    if (expense.id != id) return null;
    detail.value = expense;
    return expense;
  }

  @override
  Future<bool> createExpense(CashBankExpense expense) async {
    createdExpense = expense;
    return true;
  }

  @override
  Future<bool> updateExpense(CashBankExpense expense) async {
    updatedExpense = expense;
    return true;
  }

  @override
  Future<bool> deleteExpense(CashBankExpense expense) async {
    deletedExpenseId = expense.id;
    return true;
  }

  @override
  Future<bool> approveExpense(CashBankExpense expense) async {
    approvedExpenseId = expense.id;
    return true;
  }
}
