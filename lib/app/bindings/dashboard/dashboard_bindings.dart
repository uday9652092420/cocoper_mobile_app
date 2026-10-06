import 'package:get/get.dart';

import '../../controllers/dashboard/dashboard_controller.dart';
import '../../controllers/dashboard/profile_controller.dart';

class DashboardBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DashboardController>(
      () => DashboardController(),
    );
    Get.lazyPut<ProfileController>(
      () => ProfileController(),
    );
  }
}
