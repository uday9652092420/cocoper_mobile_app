import 'package:get/get.dart';

import '../../controllers/supplierpayments/supplier_payment_controller.dart';

class SupplierPaymentBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SupplierPaymentController>()) {
      Get.put(SupplierPaymentController(), permanent: true);
    }
  }
}
