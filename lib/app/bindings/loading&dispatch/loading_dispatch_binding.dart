import 'package:get/get.dart';

import '../../controllers/loading&dispatch/loading_dispatch_controller.dart';

class LoadingDispatchBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<LoadingDispatchController>()) {
      Get.put(LoadingDispatchController(), permanent: true);
    }
  }
}
