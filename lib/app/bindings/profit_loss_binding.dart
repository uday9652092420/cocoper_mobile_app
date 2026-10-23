import 'package:get/get.dart';

import '../controllers/profit_loss_controller.dart';
import '../services/profit_loss_service.dart';

class ProfitLossBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(
      ProfitLossController(service: ProfitLossService()),
    );
  }
}
