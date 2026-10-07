import 'package:get/get.dart';

import '../../controllers/salesorders/sales_order_controller.dart';

class SalesOrderBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SalesOrderController>()) {
      Get.put(
        SalesOrderController(),
        permanent: true,
      );
    }
  }
}
