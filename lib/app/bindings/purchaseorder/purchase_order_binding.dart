import 'package:get/get.dart';

import '../../controllers/purchaseorder/purchase_order_controller.dart';

class PurchaseOrderBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<PurchaseOrderController>()) {
      Get.put(
        PurchaseOrderController(),
        permanent: true,
      );
    }
  }
}
