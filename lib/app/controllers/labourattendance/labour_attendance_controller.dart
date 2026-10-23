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
  final isStateVerified = false.obs;
  String? _unreconciledAttendanceId;

  bool get canCheckIn =>
      today.value?.attendance == null &&
      hasAttendancePermission.value &&
      isStateVerified.value &&
      !isLoading.value &&
      !isProcessing.value;

  bool get canCheckOut =>
      today.value?.attendance?.isWorking == true &&
      hasAttendancePermission.value &&
      isStateVerified.value &&
      !isLoading.value &&
      !isProcessing.value;

  String get status => today.value?.status ?? 'Not Checked In';

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

  Future<void> loadToday({bool showLoading = true}) async {
    if (isLoading.value || isProcessing.value) {
      return;
    }
    isLoading.value = showLoading;
    errorMessage.value = null;
    try {
      final refreshed = await _repository.getToday();
      if (_unreconciledAttendanceId != null) {
        if (refreshed.attendance?.id == _unreconciledAttendanceId) {
          _unreconciledAttendanceId = null;
        } else if (refreshed.lastAttendance?.id == _unreconciledAttendanceId) {
          today.value = refreshed;
          errorMessage.value =
              'The saved attendance is visible in history, but the server has not confirmed today’s attendance status. Refresh before trying again.';
          isStateVerified.value = false;
          return;
        } else {
          throw const LabourAttendanceException(
            'A saved attendance record is still missing from the latest history response.',
          );
        }
      }
      today.value = refreshed;
      hasAttendancePermission.value = true;
      isStateVerified.value = true;
    } on LabourAttendanceException catch (error) {
      errorMessage.value = error.message;
      isStateVerified.value = false;
      if (error.statusCode == 401) {
        await _handleExpiredSession();
      } else if (error.statusCode == 403) {
        hasAttendancePermission.value = false;
      }
    } catch (error) {
      errorMessage.value =
          'Attendance could not be loaded (${error.runtimeType}). Retry to check the server state.';
      isStateVerified.value = false;
    } finally {
      isLoading.value = false;
      hasLoaded.value = true;
    }
  }

  Future<void> checkIn() async {
    if (!canCheckIn) return;
    await _perform(
      operation: _repository.checkIn,
      actionName: 'check in',
    );
  }

  Future<void> checkOut() async {
    final record = today.value?.attendance;
    if (record == null || !record.isWorking || isProcessing.value) return;
    await _perform(
      operation: () => _repository.checkOut(
        attendanceId: record.id,
        branchId: record.branchId,
      ),
      actionName: 'check out',
    );
  }

  Future<void> _perform({
    required Future<LabourAttendanceActionResult> Function() operation,
    required String actionName,
  }) async {
    if (isProcessing.value ||
        today.value == null ||
        !isStateVerified.value ||
        !hasAttendancePermission.value) {
      return;
    }
    isProcessing.value = true;
    errorMessage.value = null;
    try {
      final result = await operation();
      today.value = today.value!.withAttendance(
        result.attendance,
        result.serverTimestamp,
      );
      await _reconcileAfterSuccessfulAction(result.attendance);
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
      isStateVerified.value = true;
    } on LabourAttendanceException catch (error) {
      errorMessage.value =
          '${errorMessage.value}\nCurrent attendance could not be verified: ${error.message}';
      if (error.statusCode == 401) {
        await _handleExpiredSession();
      } else if (error.statusCode == 403) {
        hasAttendancePermission.value = false;
      }
      isStateVerified.value = false;
    } catch (error) {
      errorMessage.value =
          '${errorMessage.value}\nCurrent attendance could not be verified (${error.runtimeType}).';
      isStateVerified.value = false;
    }
  }

  Future<void> _reconcileAfterSuccessfulAction(
    LabourAttendanceRecord savedAttendance,
  ) async {
    _unreconciledAttendanceId = savedAttendance.id;
    try {
      final refreshed = await _repository.getToday();
      if (refreshed.attendance?.id == savedAttendance.id) {
        _unreconciledAttendanceId = null;
        today.value = refreshed;
        hasAttendancePermission.value = true;
        isStateVerified.value = true;
        return;
      }
      if (refreshed.lastAttendance?.id == savedAttendance.id) {
        today.value = refreshed;
        errorMessage.value =
            'The saved attendance is visible in history, but the server has not confirmed today’s attendance status. Refresh before trying again.';
        isStateVerified.value = false;
        return;
      } else {
        errorMessage.value =
            'The attendance action was saved, but today’s status could not be reconciled. Refresh before trying again.';
        isStateVerified.value = false;
        return;
      }
    } on LabourAttendanceException catch (error) {
      errorMessage.value =
          'The attendance action was saved, but the latest status could not be verified: ${error.message}';
      if (error.statusCode == 401) {
        await _handleExpiredSession();
      } else if (error.statusCode == 403) {
        hasAttendancePermission.value = false;
      }
      isStateVerified.value = false;
    } catch (error) {
      errorMessage.value =
          'The attendance action was saved, but the latest status could not be verified (${error.runtimeType}).';
      isStateVerified.value = false;
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
