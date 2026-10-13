import 'package:get/get.dart';

import '../../controllers/bagpurchase/bag_purchase_controller.dart';

class BagPurchaseBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<BagPurchaseController>()) {
      Get.lazyPut<BagPurchaseController>(BagPurchaseController.new);
    }
  }
}
