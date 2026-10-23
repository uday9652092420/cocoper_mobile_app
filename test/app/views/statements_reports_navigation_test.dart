import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/views/dashboard/statements_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('Statements list includes the Profit & Loss report', (
    tester,
  ) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: StatementsView()),
      ),
    );

    expect(find.text('Profit & Loss Statement'), findsOneWidget);
    expect(find.text('Review income, expenses and net profit'), findsOneWidget);
  });

  testWidgets('tapping Profit & Loss opens its registered report route', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: StatementsView()),
        getPages: [
          GetPage(
            name: Routes.profitLossStatementReport,
            page: () => const Scaffold(
              body: Center(child: Text('P&L destination')),
            ),
          ),
        ],
      ),
    );

    final card = find.text('Profit & Loss Statement');
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('P&L destination'), findsOneWidget);
  });

  test('all statement report destinations are registered once', () {
    final routeNames = AppPages.routes.map((route) => route.name).toList();
    const reportRoutes = [
      Routes.purchaseRegisterReport,
      Routes.salesRegisterReport,
      Routes.supplierStatementReport,
      Routes.customerStatementReport,
      Routes.pendingDispatchReport,
      Routes.profitLossStatementReport,
    ];

    for (final route in reportRoutes) {
      expect(routeNames.where((name) => name == route), hasLength(1));
    }
  });
}
