import 'package:get/get.dart';

import '../../controllers/customerreceipt/customer_receipt_controller.dart';

class CustomerReceiptBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CustomerReceiptController>()) {
      Get.put(CustomerReceiptController(), permanent: true);
    }
  }
}
