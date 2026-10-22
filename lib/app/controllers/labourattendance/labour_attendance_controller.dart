import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../helpers/secure_store.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/labour_attendance.dart';
import '../../routes/app_routes.dart';
import '../../services/labour_attendance_service.dart';
import '../../services/mobile_app_permissions.dart';

class LabourAttendanceController extends GetxController
    with WidgetsBindingObserver {
  LabourAttendanceController({
    LabourAttendanceRepository? repository,
  }) : _repository = repository ?? LabourAttendanceService();

  final LabourAttendanceRepository _repository;
  final today = Rxn<LabourAttendanceToday>();
  final errorMessage = RxnString();
  final isLoading = false.obs;
  final isProcessing = false.obs;
  final hasLoaded = false.obs;
  final hasAttendancePermission = true.obs;

  bool get canCheckIn =>
      today.value?.attendance == null &&
      hasAttendancePermission.value &&
      !isProcessing.value;

  bool get canCheckOut =>
      today.value?.attendance?.isWorking == true &&
      hasAttendancePermission.value &&
      !isProcessing.value;

  String get status {
    final record = today.value?.attendance;
    if (record == null) return 'Not Checked In';
    return record.isWorking ? 'Checked In' : 'Completed';
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    unawaited(loadToday());
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(loadToday());
    }
  }

  Future<void> loadToday({
    bool showLoading = true,
    bool allowWhileProcessing = false,
  }) async {
    if (isLoading.value || (isProcessing.value && !allowWhileProcessing)) {
      return;
    }
    isLoading.value = showLoading;
    errorMessage.value = null;
    try {
      today.value = await _repository.getToday();
      hasAttendancePermission.value = true;
    } on LabourAttendanceException catch (error) {
      errorMessage.value = error.message;
      if (error.statusCode == 401) {
        await _handleExpiredSession();
      } else if (error.statusCode == 403) {
        hasAttendancePermission.value = false;
      }
    } catch (error) {
      errorMessage.value =
          'Attendance could not be loaded (${error.runtimeType}). Retry to check the server state.';
    } finally {
      isLoading.value = false;
      hasLoaded.value = true;
    }
  }

  Future<void> checkIn() => _perform(
        operation: _repository.checkIn,
        actionName: 'check in',
      );

  Future<void> checkOut() async {
    final record = today.value?.attendance;
    if (record == null || !record.isWorking || isProcessing.value) return;
    await _perform(
      operation: () => _repository.checkOut(branchId: record.branchId),
      actionName: 'check out',
    );
  }

  Future<void> _perform({
    required Future<LabourAttendanceActionResult> Function() operation,
    required String actionName,
  }) async {
    if (isProcessing.value || today.value == null) return;
    isProcessing.value = true;
    errorMessage.value = null;
    try {
      final result = await operation();
      today.value = today.value!.withAttendance(
        result.attendance,
        result.serverTimestamp,
      );
      await loadToday(showLoading: false, allowWhileProcessing: true);
    } on LabourAttendanceException catch (error) {
      errorMessage.value = error.message;
      if (error.statusCode == 401) {
        await _handleExpiredSession();
      } else if (error.statusCode == 403) {
        hasAttendancePermission.value = false;
      } else {
        await _refreshAfterFailedAction();
      }
    } catch (error) {
      errorMessage.value =
          'Unable to $actionName (${error.runtimeType}). Refresh before trying again.';
      await _refreshAfterFailedAction();
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> _refreshAfterFailedAction() async {
    try {
      today.value = await _repository.getToday();
      hasAttendancePermission.value = true;
    } on LabourAttendanceException catch (error) {
      errorMessage.value =
          '${errorMessage.value}\nCurrent attendance could not be verified: ${error.message}';
      if (error.statusCode == 401) {
        await _handleExpiredSession();
      } else if (error.statusCode == 403) {
        hasAttendancePermission.value = false;
      }
    } catch (error) {
      errorMessage.value =
          '${errorMessage.value}\nCurrent attendance could not be verified (${error.runtimeType}).';
    }
  }

  Future<void> _handleExpiredSession() async {
    await FlutterSecureStore().deleteAllData();
    for (final key in [
      SharedPrefsHelper.userId,
      SharedPrefsHelper.username,
      SharedPrefsHelper.fullName,
      SharedPrefsHelper.userRole,
      SharedPrefsHelper.organizationId,
      SharedPrefsHelper.organizationName,
      SharedPrefsHelper.selectedBranchId,
    ]) {
      await SharedPrefsHelper.remove(key);
    }
    MobileAppPermissions.clear();
    Get.offAllNamed<void>(Routes.loginPage);
    Get.snackbar(
      'Session expired',
      'Please sign in again to continue.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
