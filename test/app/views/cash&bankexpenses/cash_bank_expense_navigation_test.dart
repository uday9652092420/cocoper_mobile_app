import 'package:cocoper_mobile/app/controllers/cash&bankexpenses/cash_bank_expenses_controller.dart';
import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/views/cash&bankexpenses/savedcash&bankexpenses_view.dart';
import 'package:cocoper_mobile/app/views/dashboard/operations_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('Operations opens the registered Cash & Bank Expenses screen',
      (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestCashBankExpenseBinding(),
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
}

class _TestCashBankExpenseBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<CashBankExpensesController>(_TestCashBankExpensesController());
  }
}

class _TestCashBankExpensesController extends CashBankExpensesController {
  @override
  Future<void> loadExpenses({bool force = false}) async {}
}
