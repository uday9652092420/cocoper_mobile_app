import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../helpers/console_print.dart';
import '../routes/app_routes.dart';

enum MobileAppDestination {
  normalDashboard,
  labourAttendance,
  denied,
  permissionConfigurationUnavailable,
}

enum MobilePermissionReconciliationStatus {
  verified,
  denied,
  loginIncomplete,
  bootstrapIncomplete,
  mismatch,
}

class MobilePermissionReconciliation {
  const MobilePermissionReconciliation({
    required this.status,
    this.permissions,
  });

  final MobilePermissionReconciliationStatus status;
  final MobileAppPermissions? permissions;
}

class MobileAppPermissions {
  const MobileAppPermissions({
    required this.mobileAppLogin,
    required this.mobileAppLabourAttendance,
    this.hasMobileAppLoginField = true,
    this.hasLabourAttendanceField = true,
    this.modulePermissions = const <String>{},
    this.hasModulePermissions = false,
  });

  final bool? mobileAppLogin;
  final bool? mobileAppLabourAttendance;
  final bool hasMobileAppLoginField;
  final bool hasLabourAttendanceField;
  final Set<String> modulePermissions;
  final bool hasModulePermissions;

  static MobileAppPermissions? current;
  static bool hasAuthenticatedSession = false;

  static MobileAppPermissions? fromLoginResponse(
    Map<String, dynamic> response,
  ) {
    return _fromAuthenticatedUser(response);
  }

  static MobileAppPermissions? fromBootstrapResponse(
    Map<String, dynamic> response,
  ) {
    return _fromAuthenticatedUser(response);
  }

  static MobilePermissionReconciliation reconcile(
    MobileAppPermissions? login,
    MobileAppPermissions? bootstrap,
  ) {
    final loginDisagrees = login != null &&
        bootstrap != null &&
        ((login.mobileAppLogin != null &&
                bootstrap.mobileAppLogin != null &&
                login.mobileAppLogin != bootstrap.mobileAppLogin) ||
            (login.mobileAppLabourAttendance != null &&
                bootstrap.mobileAppLabourAttendance != null &&
                login.mobileAppLabourAttendance !=
                    bootstrap.mobileAppLabourAttendance));
    if (loginDisagrees) {
      return const MobilePermissionReconciliation(
        status: MobilePermissionReconciliationStatus.mismatch,
      );
    }

    if (login == null || !login.isComplete) {
      return const MobilePermissionReconciliation(
        status: MobilePermissionReconciliationStatus.loginIncomplete,
      );
    }
    if (bootstrap == null || !bootstrap.isComplete) {
      return const MobilePermissionReconciliation(
        status: MobilePermissionReconciliationStatus.bootstrapIncomplete,
      );
    }

    final permissions = MobileAppPermissions(
      mobileAppLogin: bootstrap.mobileAppLogin,
      mobileAppLabourAttendance: bootstrap.mobileAppLabourAttendance,
      hasMobileAppLoginField: true,
      hasLabourAttendanceField: true,
      modulePermissions: bootstrap.hasModulePermissions
          ? bootstrap.modulePermissions
          : login.modulePermissions,
      hasModulePermissions:
          bootstrap.hasModulePermissions || login.hasModulePermissions,
    );
    if (!permissions.canAccessMainApp && !permissions.canUseLabourAttendance) {
      return MobilePermissionReconciliation(
        status: MobilePermissionReconciliationStatus.denied,
        permissions: permissions,
      );
    }
    return MobilePermissionReconciliation(
      status: MobilePermissionReconciliationStatus.verified,
      permissions: permissions,
    );
  }

  static Map<String, Object?> diagnoseResponse(dynamic body) {
    final response = _asMap(body);
    final user = _asMap(response?['user']);
    final success = _diagnoseTopLevelValue(response, 'success');
    final login = _diagnoseField(user, 'mobile_app_login');
    final attendance = _diagnoseField(user, 'mobile_app_labour_attendance');

    final failures = <String>[];
    if (user == null) {
      failures.add('user_object_missing');
    } else {
      if (login['state'] != 'valid') {
        failures.add('mobile_app_login_${login['state']}');
      }
      if (attendance['state'] != 'valid') {
        failures.add('mobile_app_labour_attendance_${attendance['state']}');
      }
    }

    return {
      'json_object': response != null,
      'top_level_keys': response?.keys.toList() ?? const <String>[],
      'success_present': success['present'],
      'success_type': success['type'],
      if (success.containsKey('value')) 'success_value': success['value'],
      'user_present': user != null,
      'user_keys': user?.keys.toList() ?? const <String>[],
      'parser_paths': 'user.mobile_app_login,user.mobile_app_labour_attendance',
      'mobile_app_login_present': login['present'],
      'mobile_app_login_type': login['type'],
      if (login.containsKey('value')) 'mobile_app_login_value': login['value'],
      'mobile_app_login_state': login['state'],
      'mobile_app_labour_attendance_present': attendance['present'],
      'mobile_app_labour_attendance_type': attendance['type'],
      if (attendance.containsKey('value'))
        'mobile_app_labour_attendance_value': attendance['value'],
      'mobile_app_labour_attendance_state': attendance['state'],
      'parser_decision': failures.isEmpty ? 'complete' : failures.join(','),
    };
  }

  static Map<String, Object?> _diagnoseTopLevelValue(
    Map<String, dynamic>? response,
    String key,
  ) {
    if (response == null || !response.containsKey(key)) {
      return {'present': false, 'type': 'missing'};
    }
    final value = response[key];
    if (value is bool || value == null) {
      return {
        'present': true,
        'type': value == null ? 'null' : 'boolean',
        'value': value
      };
    }
    return {'present': true, 'type': _jsonType(value)};
  }

  static MobileAppPermissions? _fromAuthenticatedUser(
    Map<String, dynamic> response,
  ) {
    final user = _asMap(response['user']);
    if (user == null) {
      return null;
    }

    final hasLogin = user.containsKey('mobile_app_login');
    final hasAttendance = user.containsKey('mobile_app_labour_attendance');
    final userHasModulePermissions = user.containsKey('permissions');
    final tokenPermissions = _tokenPermissions(response['token']);
    final rawPermissions = userHasModulePermissions
        ? user['permissions']
        : tokenPermissions.permissions;
    final effectivePermissions = userHasModulePermissions
        ? _parsePermissions(rawPermissions)
        : tokenPermissions.permissions;
    consolePrint(
      'MOBILE PERMISSIONS: source=${userHasModulePermissions ? 'user' : 'token'}, '
      'fieldType=${rawPermissions.runtimeType}, '
      'keys=${effectivePermissions.toList()}',
    );
    return MobileAppPermissions(
      mobileAppLogin: _parseBoolean(user['mobile_app_login']),
      mobileAppLabourAttendance:
          _parseBoolean(user['mobile_app_labour_attendance']),
      hasMobileAppLoginField: hasLogin,
      hasLabourAttendanceField: hasAttendance,
      modulePermissions: effectivePermissions,
      hasModulePermissions:
          userHasModulePermissions || tokenPermissions.present,
    );
  }

  bool hasPermission(String permission) =>
      modulePermissions.contains(permission);

  static Map<String, Object?> _diagnoseField(
    Map<String, dynamic>? user,
    String key,
  ) {
    if (user == null || !user.containsKey(key)) {
      return {
        'present': false,
        'type': 'missing',
        'state': 'missing',
      };
    }

    final value = user[key];
    if (value is bool) {
      return {
        'present': true,
        'type': 'boolean',
        'value': value,
        'state': 'valid',
      };
    }
    if (value == null) {
      return {
        'present': true,
        'type': 'null',
        'value': null,
        'state': 'null',
      };
    }

    return {
      'present': true,
      'type': _jsonType(value),
      'state': 'invalid_type',
    };
  }

  static String _jsonType(Object? value) {
    if (value is String) return 'string';
    if (value is num) return 'number';
    if (value is Map) return 'object';
    if (value is List) return 'array';
    return 'unknown';
  }

  bool get canUseLabourAttendance => mobileAppLabourAttendance == true;
  bool get canAccessMainApp => mobileAppLogin == true;

  bool get isComplete =>
      hasMobileAppLoginField &&
      hasLabourAttendanceField &&
      mobileAppLogin != null &&
      mobileAppLabourAttendance != null;

  MobileAppDestination get destination {
    if (canAccessMainApp) {
      return MobileAppDestination.normalDashboard;
    }
    if (canUseLabourAttendance) {
      return MobileAppDestination.labourAttendance;
    }
    if (mobileAppLogin == false && mobileAppLabourAttendance == false) {
      return MobileAppDestination.denied;
    }
    return MobileAppDestination.permissionConfigurationUnavailable;
  }

  static void beginSession(MobileAppPermissions? permissions) {
    current = permissions;
    hasAuthenticatedSession = true;
  }

  static void clear() {
    current = null;
    hasAuthenticatedSession = false;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static bool? _parseBoolean(dynamic value) {
    if (value is bool) {
      return value;
    }
    return null;
  }

  static Set<String> _parsePermissions(dynamic value) {
    if (value is! List) return const <String>{};
    return Set<String>.unmodifiable(
      value
          .whereType<String>()
          .map((permission) => permission.trim())
          .where((permission) => permission.isNotEmpty),
    );
  }

  static ({Set<String> permissions, bool present}) _tokenPermissions(
    dynamic token,
  ) {
    if (token is! String) {
      return (permissions: const <String>{}, present: false);
    }

    final parts = token.split('.');
    if (parts.length != 3) {
      return (permissions: const <String>{}, present: false);
    }

    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is Map && payload.containsKey('permissions')) {
        return (
          permissions: _parsePermissions(payload['permissions']),
          present: true,
        );
      }
    } on FormatException {
      return (permissions: const <String>{}, present: false);
    }

    return (permissions: const <String>{}, present: false);
  }
}

class MobileAppPermissionMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (Get.testMode) {
      return null;
    }

    if (route == Routes.loginPage || route == Routes.splash) {
      return null;
    }

    if (!MobileAppPermissions.hasAuthenticatedSession) {
      _showAccessDenied();
      return const RouteSettings(name: Routes.loginPage);
    }

    final permissions = MobileAppPermissions.current;
    if (permissions == null || !permissions.isComplete) {
      _showAccessDenied();
      return const RouteSettings(name: Routes.loginPage);
    }

    if (route == Routes.labourAttendance) {
      if (permissions.canUseLabourAttendance) {
        return null;
      }
      _showAccessDenied();
      return permissions.canAccessMainApp
          ? const RouteSettings(name: Routes.dashboard)
          : const RouteSettings(name: Routes.loginPage);
    }

    if (permissions.canAccessMainApp) {
      return null;
    }

    if (permissions.canUseLabourAttendance) {
      _showAccessDenied();
      return const RouteSettings(name: Routes.labourAttendance);
    }

    _showAccessDenied();
    return const RouteSettings(name: Routes.loginPage);
  }

  void _showAccessDenied() {
    if (Get.context == null) {
      return;
    }
    Get.snackbar(
      'Access denied',
      'Your account is not authorized to open this screen.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }
}
