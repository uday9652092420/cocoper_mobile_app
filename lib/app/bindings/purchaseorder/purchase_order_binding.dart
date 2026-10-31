import 'package:get/get.dart';

import '../../controllers/purchaseorder/purchase_order_controller.dart';
import '../../controllers/salesorders/sales_order_controller.dart';

class PurchaseOrderBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<PurchaseOrderController>()) {
      Get.put(
        PurchaseOrderController(),
        permanent: true,
      );
    }
    if (!Get.isRegistered<SalesOrderController>()) {
      Get.put(
        SalesOrderController(),
        permanent: true,
      );
    }
  }
}
