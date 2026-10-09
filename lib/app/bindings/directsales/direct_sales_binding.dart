import 'package:get/get.dart';

import '../../controllers/directsales/direct_sales_controller.dart';

class DirectSalesBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<DirectSalesController>()) {
      Get.put(DirectSalesController());
    }
  }
}
