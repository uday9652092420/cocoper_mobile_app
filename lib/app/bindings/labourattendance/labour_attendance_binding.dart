import 'package:get/get.dart';

import '../../controllers/labourattendance/labour_attendance_controller.dart';

class LabourAttendanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LabourAttendanceController>(
      () => LabourAttendanceController(),
    );
  }
}
