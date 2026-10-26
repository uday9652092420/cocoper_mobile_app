import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../helpers/secure_store.dart';
import '../helpers/shared_preferences.dart';
import '../routes/app_routes.dart';
import '../services/api_service.dart';
import '../services/endpoints.dart';
import '../services/mobile_app_permissions.dart';

class SplashScreenController extends GetxController {
  bool _hasStarted = false;

  Future<void> startTimer(BuildContext context) async {
    if (_hasStarted) {
      return;
    }
    _hasStarted = true;

    await Future<void>.delayed(const Duration(seconds: 1));
    String? token;
    try {
      token = await FlutterSecureStore().getSingleValue(
        SharedPrefsHelper.accessToken,
      );
    } catch (error) {
      _log('session_restore token_read_error=${error.runtimeType}');
      await _navigateToLogin();
      return;
    }
    if (token == null || token.trim().isEmpty) {
      await _navigateToLogin();
      return;
    }

    await _restoreSession();
  }

  Future<void> _restoreSession() async {
    _log(
      'session_restore request '
      'endpoint=${ApiService.dio.options.baseUrl}${EndPoints.mobileBootstrap}',
    );
    try {
      final response = await ApiService.get(EndPoints.mobileBootstrap);
      if (response == null) {
        _log('session_restore result=unavailable http_status=none');
        await _navigateToLogin(
          message: 'Could not verify your session. Please sign in again.',
          clearStoredSession: false,
        );
        return;
      }

      final body = response.data;
      _logPermissionResponse(
        endpoint: response.requestOptions.uri.toString(),
        statusCode: response.statusCode,
        body: body,
      );
      final successful =
          response.statusCode == 200 && body is Map && body['success'] == true;
      _log(
        'session_restore http_status=${response.statusCode} '
        'bootstrap_success=$successful',
      );
      if (!successful) {
        final denied = response.statusCode == 401 || response.statusCode == 403;
        await _navigateToLogin(
          message: denied
              ? 'Your session is no longer authorized. Please sign in again.'
              : 'Could not verify your permissions. Please try again.',
          clearStoredSession: denied,
        );
        return;
      }

      final bootstrap = Map<String, dynamic>.from(body);
      final user = _asMap(bootstrap['user']);
      final permissions = MobileAppPermissions.fromBootstrapResponse(bootstrap);
      _log(
        'session_restore user_parsed=${user != null} '
        'userIdPresent=${user?['id'] != null} '
        'mobileLogin=${permissions?.mobileAppLogin} '
        'attendance=${permissions?.mobileAppLabourAttendance}',
      );

      if (permissions == null) {
        await _navigateToLogin(
          message: 'The server did not return your authenticated user. '
              'Please sign in again.',
          clearStoredSession: false,
        );
        return;
      }
      if (permissions.mobileAppLogin == false &&
          !permissions.canUseLabourAttendance) {
        await _navigateToLogin(
          message: 'Your account is not authorized to use the mobile app.',
          clearStoredSession: true,
        );
        return;
      }

      await _storeRestoredIdentity(bootstrap, user);
      await _storeDefaultAttendanceBranch(bootstrap);
      MobileAppPermissions.beginSession(permissions);
      final destination =
          permissions.destination == MobileAppDestination.labourAttendance
              ? Routes.labourAttendance
              : Routes.dashboard;
      _log('session_restore navigation destination=$destination');
      Get.offAllNamed<void>(destination);
    } catch (error) {
      _log('session_restore error=${error.runtimeType}');
      await _navigateToLogin(
        message: 'Could not verify your session. Please sign in again.',
        clearStoredSession: false,
      );
    }
  }

  Future<void> _storeRestoredIdentity(
    Map<String, dynamic> bootstrap,
    Map<String, dynamic>? user,
  ) async {
    await _clearStoredIdentity();
    if (user != null) {
      await _storeIfPresent(SharedPrefsHelper.userId, user['id']);
      await _storeIfPresent(SharedPrefsHelper.username, user['username']);
      await _storeIfPresent(SharedPrefsHelper.fullName, user['full_name']);
      await _storeIfPresent(SharedPrefsHelper.userRole, user['role']);
    }

    final organization = _asMap(bootstrap['organization']);
    final userOrganizationId = _normalizedValue(user?['organization_id']);
    final bootstrapOrganizationId = _normalizedValue(organization?['id']);
    if (userOrganizationId != null &&
        bootstrapOrganizationId != null &&
        userOrganizationId != bootstrapOrganizationId) {
      throw const FormatException(
        'Bootstrap user and organization scopes do not match.',
      );
    }
    await _storeIfPresent(
      SharedPrefsHelper.organizationId,
      userOrganizationId ?? bootstrapOrganizationId,
    );
    if (organization != null) {
      await _storeIfPresent(
        SharedPrefsHelper.organizationName,
        organization['organization_name'],
      );
    }
  }

  Future<void> _storeDefaultAttendanceBranch(
    Map<String, dynamic> bootstrap,
  ) async {
    final defaultBranchId = bootstrap['default_branch_id']?.toString().trim();
    final rawBranches = bootstrap['branches'];
    final assignedBranchIds = rawBranches is List
        ? rawBranches
            .map(_asMap)
            .whereType<Map<String, dynamic>>()
            .map((branch) => branch['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
        : <String>{};
    if (defaultBranchId != null &&
        defaultBranchId.isNotEmpty &&
        assignedBranchIds.contains(defaultBranchId)) {
      await SharedPrefsHelper.setString(
        SharedPrefsHelper.selectedBranchId,
        defaultBranchId,
      );
    } else {
      await SharedPrefsHelper.remove(SharedPrefsHelper.selectedBranchId);
    }
  }

  Future<void> _storeIfPresent(String key, dynamic value) async {
    final text = _normalizedValue(value);
    if (text != null) {
      await SharedPrefsHelper.setString(key, text);
    }
  }

  String? _normalizedValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }

  Future<void> _navigateToLogin({
    String? message,
    bool clearStoredSession = false,
  }) async {
    MobileAppPermissions.clear();
    if (clearStoredSession) {
      await FlutterSecureStore().deleteAllData();
      await _clearStoredIdentity();
    }
    _log('session_restore navigation destination=${Routes.loginPage}');
    Get.offAllNamed<void>(Routes.loginPage);
    if (message != null) {
      Get.snackbar(
        'Session verification',
        message,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  Future<void> _clearStoredIdentity() async {
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
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  void _logPermissionResponse({
    required String endpoint,
    required int? statusCode,
    required dynamic body,
  }) {
    final uri = Uri.tryParse(endpoint);
    final safeEndpoint = uri == null
        ? endpoint.split('?').first
        : uri.replace(query: '', fragment: '').toString();
    final responseMap = _asMap(body);
    final dataMap = _asMap(responseMap?['data']);
    final resultMap = _asMap(responseMap?['result']);
    final organization = _asMap(responseMap?['organization']);
    final branches = responseMap?['branches'];
    final firstBranch =
        branches is List && branches.isNotEmpty ? _asMap(branches.first) : null;
    final candidates = <String, Map<String, dynamic>?>{
      'user': _asMap(responseMap?['user']),
      'data.user': _asMap(dataMap?['user']),
      'result.user': _asMap(resultMap?['user']),
    };
    final candidateDetails = candidates.entries.map((entry) {
      final user = entry.value;
      final loginValue = user?['mobile_app_login'];
      final attendanceValue = user?['mobile_app_labour_attendance'];
      return '${entry.key}='
          'found:${user != null},'
          'keys:${user?.keys.toList() ?? const []},'
          'mobile_app_login:${_diagnosticField(user, 'mobile_app_login', loginValue)},'
          'mobile_app_labour_attendance:'
          '${_diagnosticField(user, 'mobile_app_labour_attendance', attendanceValue)}';
    }).join(' ');

    _log(
      'bootstrap_response endpoint=$safeEndpoint http_status=$statusCode '
      'json_object=${responseMap != null} '
      'top_level_keys=${responseMap?.keys.toList() ?? const []} '
      'data_keys=${dataMap?.keys.toList() ?? const []} '
      'result_keys=${resultMap?.keys.toList() ?? const []} '
      'organization_keys=${organization?.keys.toList() ?? const []} '
      'branch_count=${branches is List ? branches.length : 'none'} '
      'branch_keys=${firstBranch?.keys.toList() ?? const []} '
      'permission_field_occurrences='
      '${_permissionFieldOccurrences(responseMap)} '
      'permission_candidates={$candidateDetails}',
    );
  }

  List<String> _permissionFieldOccurrences(
    dynamic value, {
    String path = r'$',
    int depth = 0,
  }) {
    if (value is! Map || depth > 5) {
      return const [];
    }
    const fields = {
      'mobile_app_login',
      'mobile_app_labour_attendance',
    };
    final occurrences = <String>[];
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final fieldPath = '$path.$key';
      if (fields.contains(key)) {
        occurrences.add('$fieldPath=${entry.value}');
      } else if (entry.value is Map) {
        occurrences.addAll(
          _permissionFieldOccurrences(
            entry.value,
            path: fieldPath,
            depth: depth + 1,
          ),
        );
      }
    }
    return occurrences;
  }

  String _diagnosticField(
    Map<String, dynamic>? user,
    String key,
    dynamic value,
  ) {
    if (user == null || !user.containsKey(key)) {
      return 'found:false,value:missing';
    }
    return 'found:true,value:$value,type:${value.runtimeType}';
  }

  void _log(String message) {
    if (!ApiService.isProduction) {
      debugPrint('[auth] $message');
    }
  }
}
