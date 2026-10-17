import 'package:get/get.dart';

import '../../controllers/cash&bankexpenses/cash_bank_expenses_controller.dart';

class CashBankExpensesBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CashBankExpensesController>()) {
      Get.put(CashBankExpensesController(), permanent: true);
    }
  }
}
