import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all statement report destinations are registered once', () {
    final routeNames = AppPages.routes.map((route) => route.name).toList();
    const reportRoutes = [
      Routes.purchaseRegisterReport,
      Routes.salesRegisterReport,
      Routes.supplierStatementReport,
      Routes.customerStatementReport,
      Routes.pendingDispatchReport,
    ];

    for (final route in reportRoutes) {
      expect(routeNames.where((name) => name == route), hasLength(1));
    }
  });
}
