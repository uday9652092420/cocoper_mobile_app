import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/labourattendance/labour_attendance_controller.dart';
import '../../helpers/secure_store.dart';
import '../../helpers/shared_preferences.dart';
import '../../routes/app_routes.dart';
import '../../services/mobile_app_permissions.dart';
import '../../theme/app_theme.dart';

class LabourAttendanceDashboardView extends StatelessWidget {
  const LabourAttendanceDashboardView({super.key});

  Future<String?> _loadEmployeeName() async {
    final fullName = await SharedPrefsHelper.getString(
      SharedPrefsHelper.fullName,
    );
    return fullName.trim().isEmpty ? null : fullName.trim();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;

    final languageCode = await SharedPrefsHelper.getString(
      SharedPrefsHelper.languageCode,
      defaultValue: 'en',
    );
    final countryCode = await SharedPrefsHelper.getString(
      SharedPrefsHelper.countryCode,
      defaultValue: 'US',
    );
    await FlutterSecureStore().deleteAllData();
    await SharedPrefsHelper.clearAll();
    await SharedPrefsHelper.setString(
      SharedPrefsHelper.languageCode,
      languageCode,
    );
    await SharedPrefsHelper.setString(
      SharedPrefsHelper.countryCode,
      countryCode,
    );
    MobileAppPermissions.clear();
    Get.offAllNamed<void>(Routes.loginPage);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LabourAttendanceController>();
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.pageBackground,
        ),
        child: SafeArea(
          child: FutureBuilder<String?>(
            future: _loadEmployeeName(),
            builder: (context, snapshot) {
              final name = snapshot.data;
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    sliver: SliverList.list(
                      children: [
                        Row(
                          children: [
                            ClipOval(
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Image.asset(
                                  'assets/cocoper-icon.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const CircleAvatar(
                                    backgroundColor: AppColors.primaryLight,
                                    child: Text(
                                      'C',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'COPPER',
                                    style: TextStyle(
                                      color: AppColors.textDefaultLight,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    'All coconut operations',
                                    style: TextStyle(
                                      color: AppColors.textLightGrayLight,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _confirmLogout(context),
                              icon: const Icon(Icons.logout),
                              label: const Text('Logout'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF9E2A24),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Labour Attendance',
                          style: TextStyle(
                            color: AppColors.textDefaultLight,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          snapshot.hasError
                              ? 'Employee details could not be loaded.'
                              : snapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? 'Loading employee details...'
                                  : name == null
                                      ? 'Employee name unavailable'
                                      : 'Hello, $name',
                          style: const TextStyle(
                            color: AppColors.textLightGrayLight,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildAttendanceCard(controller),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(LabourAttendanceController controller) {
    return Obx(() {
      final today = controller.today.value;
      if (controller.isLoading.value && today == null) {
        return const _LoadingCard();
      }
      if (today == null) {
        return _UnavailableCard(
          message: controller.errorMessage.value ??
              "Today's attendance could not be loaded.",
          onRetry: () => controller.loadToday(),
          isLoading: controller.isLoading.value,
        );
      }

      final record = today.attendance;
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLightGrayLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Today's attendance",
                    style: TextStyle(
                      color: AppColors.textDefaultLight,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusLabel(status: controller.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('EEE, MMM d, yyyy').format(today.attendanceDate),
              style: const TextStyle(
                color: AppColors.textLightGrayLight,
                fontSize: 14,
              ),
            ),
            if (today.branchGeofence?.enabled == true) ...[
              const SizedBox(height: 8),
              Text(
                'GPS required within ${today.branchGeofence!.radiusMeters} m of this branch.',
                style: const TextStyle(
                  color: AppColors.textLightGrayLight,
                  fontSize: 12,
                ),
              ),
            ],
            if (record == null && today.lastAttendance != null) ...[
              const SizedBox(height: 18),
              Text(
                'Previous attendance · ${DateFormat('EEE, MMM d, yyyy').format(today.lastAttendance!.attendanceDate)}',
                style: const TextStyle(
                  color: AppColors.textLightGrayLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _AttendanceTime(
                label: 'Check-in',
                value:
                    DateFormat('h:mm a').format(today.lastAttendance!.inTime),
                icon: Icons.login,
              ),
              if (today.lastAttendance!.outTime != null) ...[
                const SizedBox(height: 12),
                _AttendanceTime(
                  label: 'Check-out',
                  value: DateFormat('h:mm a')
                      .format(today.lastAttendance!.outTime!),
                  icon: Icons.logout,
                ),
                const SizedBox(height: 12),
                _AttendanceTime(
                  label: 'Working hours',
                  value:
                      '${today.lastAttendance!.displayedWorkingHours.toStringAsFixed(2)} hrs',
                  icon: Icons.schedule,
                ),
              ],
            ],
            if (record != null) ...[
              const SizedBox(height: 20),
              _AttendanceTime(
                label: 'Check-in',
                value: DateFormat('h:mm a').format(record.inTime),
                icon: Icons.login,
              ),
              if (record.outTime != null) ...[
                const SizedBox(height: 12),
                _AttendanceTime(
                  label: 'Check-out',
                  value: DateFormat('h:mm a').format(record.outTime!),
                  icon: Icons.logout,
                ),
                const SizedBox(height: 12),
                _AttendanceTime(
                  label: 'Working hours',
                  value:
                      '${record.displayedWorkingHours.toStringAsFixed(2)} hrs',
                  icon: Icons.schedule,
                ),
              ],
            ],
            if (controller.errorMessage.value != null) ...[
              const SizedBox(height: 16),
              _InlineError(message: controller.errorMessage.value!),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    controller.canCheckIn && !controller.isProcessing.value
                        ? controller.checkIn
                        : null,
                icon: controller.isProcessing.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login),
                label: const Text('Check-In'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    controller.canCheckOut && !controller.isProcessing.value
                        ? controller.checkOut
                        : null,
                icon: const Icon(Icons.logout),
                label: const Text('Check-Out'),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _AttendanceTime extends StatelessWidget {
  const _AttendanceTime({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.primaryLight),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textLightGrayLight),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textDefaultLight,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text("Loading today's attendance..."),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({
    required this.message,
    required this.onRetry,
    required this.isLoading,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8D39D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off_outlined, color: Color(0xFF8B6508)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Attendance unavailable',
                  style: TextStyle(
                    color: AppColors.textDefaultLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textLightGrayLight,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: isLoading ? null : onRetry,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.login),
              label: const Text('Check-In'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.logout),
              label: const Text('Check-Out'),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Punch actions stay disabled until today's status is verified.",
            style: TextStyle(
              color: AppColors.textLightGrayLight,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF9E2A24)),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Checked In' => const Color(0xFF1B7A46),
      'Completed' => AppColors.primaryLight,
      _ => const Color(0xFF80620B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
