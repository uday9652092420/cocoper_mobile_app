import 'package:cocoper_mobile/app/bindings/auth/login_binding.dart';
import 'package:cocoper_mobile/app/bindings/dashboard/dashboard_bindings.dart';
import 'package:cocoper_mobile/app/views/auth/login_page_view.dart';
import 'package:cocoper_mobile/app/views/dashboard/dashboard_view.dart';
import 'package:get/get.dart';

import 'app_routes.dart';

class AppPages {
  static const initialPage = Routes.loginPage;

  static final routes = <GetPage>[
    // ============================================================
    // LOGIN
    // ============================================================

    GetPage(
      name: Routes.loginPage,
      page: () => const LoginPageView(),
      binding: LoginBinding(),
    ),

    // ============================================================
    // DASHBOARD
    // ============================================================

    GetPage(
      name: Routes.dashboard,
      page: () => DashboardView(),
      binding: DashboardBindings(),
    ),
  ];
}
