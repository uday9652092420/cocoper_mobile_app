import 'package:get/get.dart';

import '../../controllers/purchaseinvoice/purchase_invoice_controller.dart';

class PurchaseInvoiceBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<PurchaseInvoiceController>()) {
      Get.put(
        PurchaseInvoiceController(),
        permanent: true,
      );
    }
  }
}
