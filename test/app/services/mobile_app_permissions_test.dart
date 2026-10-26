import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/services/mobile_app_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(MobileAppPermissions.clear);

  test('reads mobile permissions from the authenticated user payload', () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'success': true,
      'token': 'test-token',
      'user': {
        'id': 'user-1',
        'username': 'employee',
        'full_name': 'Test Employee',
        'role': 'Worker',
        'organization_id': 'org-1',
        'mobile_app_login': true,
        'mobile_app_labour_attendance': true,
      },
    });

    expect(permissions?.mobileAppLogin, isTrue);
    expect(permissions?.mobileAppLabourAttendance, isTrue);
    expect(permissions?.canUseLabourAttendance, isTrue);
  });

  test('reads explicit disabled permissions without guessing a role', () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': false,
      },
    });

    expect(permissions?.mobileAppLogin, isTrue);
    expect(permissions?.mobileAppLabourAttendance, isFalse);
    expect(permissions?.canUseLabourAttendance, isFalse);
    expect(
      permissions?.destination,
      MobileAppDestination.normalDashboard,
    );
  });

  test('attendance permission selects Labour Attendance independently', () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': false,
        'mobile_app_labour_attendance': true,
      },
    });

    expect(permissions?.destination, MobileAppDestination.labourAttendance);
    expect(permissions?.canUseLabourAttendance, isTrue);
  });

  test('routes both enabled permissions to the normal dashboard by default',
      () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': true,
      },
    });

    expect(permissions?.destination, MobileAppDestination.normalDashboard);
  });

  test('routes normal mobile permissions to the normal dashboard', () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': false,
      },
    });

    expect(permissions?.destination, MobileAppDestination.normalDashboard);
  });

  test('allows attendance-only access when mobile login is disabled', () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': false,
        'mobile_app_labour_attendance': true,
      },
    });

    expect(permissions?.destination, MobileAppDestination.labourAttendance);
  });

  test('attendance permission grants attendance access without login flag', () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'user': {'mobile_app_labour_attendance': true},
    });

    expect(
      permissions?.destination,
      MobileAppDestination.labourAttendance,
    );
    expect(permissions?.canUseLabourAttendance, isTrue);
  });

  test('an explicit main-app permission selects the normal dashboard', () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'user': {'mobile_app_login': true},
    });

    expect(
      permissions?.destination,
      MobileAppDestination.normalDashboard,
    );
  });

  test('incomplete permissions are not a valid session configuration', () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'user': {'mobile_app_login': true},
    });

    expect(permissions?.isComplete, isFalse);
    expect(
      permissions?.destination,
      MobileAppDestination.normalDashboard,
    );
  });

  test('does not coerce string or null values into permissions', () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': 'true',
        'mobile_app_labour_attendance': null,
      },
    });

    expect(permissions?.hasMobileAppLoginField, isTrue);
    expect(permissions?.hasLabourAttendanceField, isTrue);
    expect(permissions?.mobileAppLogin, isNull);
    expect(permissions?.mobileAppLabourAttendance, isNull);
    expect(
      permissions?.destination,
      MobileAppDestination.permissionConfigurationUnavailable,
    );
  });

  test('null permission values do not grant access', () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': null,
        'mobile_app_labour_attendance': null,
      },
    });

    expect(
      permissions?.destination,
      MobileAppDestination.permissionConfigurationUnavailable,
    );
  });

  test('invalid permission types do not grant attendance access', () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': 1,
        'mobile_app_labour_attendance': 'true',
      },
    });

    expect(
      permissions?.destination,
      MobileAppDestination.permissionConfigurationUnavailable,
    );
    expect(permissions?.canUseLabourAttendance, isFalse);
  });

  test('blocks routes when backend omits both permission flags', () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'user': {'role': 'Labour'},
    });

    expect(permissions?.isComplete, isFalse);
    MobileAppPermissions.beginSession(permissions);

    expect(
      MobileAppPermissionMiddleware().redirect(Routes.dashboard)?.name,
      Routes.loginPage,
    );
  });

  test('parses the exact user object in the mobile bootstrap response', () {
    final permissions = MobileAppPermissions.fromBootstrapResponse({
      'success': true,
      'user': {
        'id': 'user-1',
        'mobile_app_login': true,
        'mobile_app_labour_attendance': false,
      },
    });

    expect(permissions?.destination, MobileAppDestination.normalDashboard);
  });

  test('reconciles matching login and bootstrap permissions', () {
    final login = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': true,
      },
    });
    final bootstrap = MobileAppPermissions.fromBootstrapResponse({
      'success': true,
      'user': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': true,
      },
    });

    final result = MobileAppPermissions.reconcile(login, bootstrap);

    expect(result.status, MobilePermissionReconciliationStatus.verified);
    expect(
      result.permissions?.destination,
      MobileAppDestination.normalDashboard,
    );
  });

  test('reconciles matching normal mobile permissions', () {
    final login = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': false,
      },
    });
    final bootstrap = MobileAppPermissions.fromBootstrapResponse({
      'success': true,
      'user': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': false,
      },
    });

    final result = MobileAppPermissions.reconcile(login, bootstrap);

    expect(result.status, MobilePermissionReconciliationStatus.verified);
    expect(
      result.permissions?.destination,
      MobileAppDestination.normalDashboard,
    );
  });

  test('requires both responses to provide explicit permission flags', () {
    final login = MobileAppPermissions.fromLoginResponse({
      'success': true,
      'user': {'id': 'user-1', 'username': 'bunny'},
    });
    final bootstrap = MobileAppPermissions.fromBootstrapResponse({
      'success': true,
      'user': {'id': 'user-1', 'username': 'bunny'},
    });

    final result = MobileAppPermissions.reconcile(login, bootstrap);

    expect(
      result.status,
      MobilePermissionReconciliationStatus.loginIncomplete,
    );
    expect(result.permissions, isNull);
  });

  test('rejects login and bootstrap responses with missing permission flags',
      () {
    final complete = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': true,
      },
    });
    final incomplete = MobileAppPermissions.fromBootstrapResponse({
      'success': true,
      'user': {'mobile_app_login': true},
    });

    final loginMissing = MobileAppPermissions.reconcile(incomplete, complete);
    final bootstrapMissing =
        MobileAppPermissions.reconcile(complete, incomplete);

    expect(
      loginMissing.status,
      MobilePermissionReconciliationStatus.loginIncomplete,
    );
    expect(
      bootstrapMissing.status,
      MobilePermissionReconciliationStatus.bootstrapIncomplete,
    );
    expect(loginMissing.permissions, isNull);
    expect(bootstrapMissing.permissions, isNull);
  });

  test('rejects disagreeing login and bootstrap permissions', () {
    final login = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': true,
      },
    });
    final bootstrap = MobileAppPermissions.fromBootstrapResponse({
      'success': true,
      'user': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': false,
      },
    });

    final result = MobileAppPermissions.reconcile(login, bootstrap);

    expect(result.status, MobilePermissionReconciliationStatus.mismatch);
    expect(result.permissions, isNull);
  });

  test('allows matching attendance-only permissions when mobile login is off',
      () {
    final login = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': false,
        'mobile_app_labour_attendance': true,
      },
    });
    final bootstrap = MobileAppPermissions.fromBootstrapResponse({
      'success': true,
      'user': {
        'mobile_app_login': false,
        'mobile_app_labour_attendance': true,
      },
    });

    final result = MobileAppPermissions.reconcile(login, bootstrap);

    expect(result.status, MobilePermissionReconciliationStatus.verified);
    expect(
      result.permissions?.destination,
      MobileAppDestination.labourAttendance,
    );
  });

  test('diagnoses the documented user-level permission response shape', () {
    final response = {
      'success': true,
      'user': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': false,
      },
    };

    final diagnostics = MobileAppPermissions.diagnoseResponse(response);
    final permissions = MobileAppPermissions.fromLoginResponse(response);

    expect(
      diagnostics['parser_paths'],
      'user.mobile_app_login,user.mobile_app_labour_attendance',
    );
    expect(diagnostics['json_object'], isTrue);
    expect(diagnostics['success_present'], isTrue);
    expect(diagnostics['success_type'], 'boolean');
    expect(diagnostics['success_value'], isTrue);
    expect(diagnostics['user_present'], isTrue);
    expect(diagnostics['mobile_app_login_present'], isTrue);
    expect(diagnostics['mobile_app_login_type'], 'boolean');
    expect(diagnostics['mobile_app_login_value'], isTrue);
    expect(diagnostics['mobile_app_labour_attendance_present'], isTrue);
    expect(diagnostics['mobile_app_labour_attendance_type'], 'boolean');
    expect(diagnostics['mobile_app_labour_attendance_value'], isFalse);
    expect(diagnostics['parser_decision'], 'complete');
    expect(permissions?.destination, MobileAppDestination.normalDashboard);
  });

  test('diagnoses missing permission fields without accepting aliases', () {
    final diagnostics = MobileAppPermissions.diagnoseResponse({
      'data': {
        'user': {
          'mobile_app_login': true,
          'mobile_app_labour_attendance': true,
        },
      },
    });

    expect(diagnostics['user_present'], isFalse);
    expect(diagnostics['mobile_app_login_present'], isFalse);
    expect(diagnostics['mobile_app_labour_attendance_present'], isFalse);
    expect(
      diagnostics['parser_decision'],
      'user_object_missing',
    );
  });

  test('does not grant access when login response omits permissions', () {
    final response = {
      'success': true,
      'message': 'Login successful',
      'user': {
        'id': 'redacted',
        'username': 'redacted',
        'full_name': null,
        'role': 'redacted',
        'is_super_admin': false,
        'organization_id': 'redacted',
      },
      'token': 'redacted',
      'tokenId': 'redacted',
      'expiresAt': 0,
    };

    final permissions = MobileAppPermissions.fromLoginResponse(response);
    final diagnostics = MobileAppPermissions.diagnoseResponse(response);

    expect(permissions?.isComplete, isFalse);
    expect(
      permissions?.destination,
      MobileAppDestination.permissionConfigurationUnavailable,
    );
    expect(permissions?.canUseLabourAttendance, isFalse);
    expect(diagnostics['parser_decision'],
        'mobile_app_login_missing,mobile_app_labour_attendance_missing');
  });

  test('does not grant access when bootstrap response omits permissions', () {
    final response = {
      'success': true,
      'user': {
        'id': 'redacted',
        'username': 'redacted',
        'full_name': 'redacted',
        'email': 'redacted',
        'role': 'redacted',
      },
      'organization': <String, Object?>{},
      'branches': <Object?>[],
      'default_branch_id': null,
    };

    final permissions = MobileAppPermissions.fromBootstrapResponse(response);
    final diagnostics = MobileAppPermissions.diagnoseResponse(response);

    expect(permissions?.isComplete, isFalse);
    expect(
      permissions?.destination,
      MobileAppDestination.permissionConfigurationUnavailable,
    );
    expect(permissions?.canUseLabourAttendance, isFalse);
    expect(diagnostics['parser_decision'],
        'mobile_app_login_missing,mobile_app_labour_attendance_missing');
  });

  test('diagnoses null and non-Boolean permission types explicitly', () {
    final diagnostics = MobileAppPermissions.diagnoseResponse({
      'user': {
        'mobile_app_login': 'true',
        'mobile_app_labour_attendance': null,
      },
    });

    expect(diagnostics['mobile_app_login_present'], isTrue);
    expect(diagnostics['mobile_app_login_type'], 'string');
    expect(diagnostics.containsKey('mobile_app_login_value'), isFalse);
    expect(diagnostics['mobile_app_login_state'], 'invalid_type');
    expect(diagnostics['mobile_app_labour_attendance_present'], isTrue);
    expect(diagnostics['mobile_app_labour_attendance_type'], 'null');
    expect(diagnostics['mobile_app_labour_attendance_value'], isNull);
    expect(
      diagnostics['parser_decision'],
      'mobile_app_login_invalid_type,mobile_app_labour_attendance_null',
    );
  });

  test('session restoration uses fresh bootstrap permission values', () {
    final attendanceOnlyPermissions =
        MobileAppPermissions.fromBootstrapResponse({
      'success': true,
      'user': {
        'mobile_app_login': false,
        'mobile_app_labour_attendance': true,
      },
    });
    final labourPermissions = MobileAppPermissions.fromBootstrapResponse({
      'success': true,
      'user': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': true,
      },
    });
    final normalPermissions = MobileAppPermissions.fromBootstrapResponse({
      'success': true,
      'user': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': false,
      },
    });
    final deniedPermissions = MobileAppPermissions.fromBootstrapResponse({
      'success': true,
      'user': {
        'mobile_app_login': false,
        'mobile_app_labour_attendance': false,
      },
    });
    final incompletePermissions = MobileAppPermissions.fromBootstrapResponse({
      'success': true,
      'user': {'mobile_app_login': true},
    });

    expect(
      labourPermissions?.destination,
      MobileAppDestination.normalDashboard,
    );
    expect(
      attendanceOnlyPermissions?.destination,
      MobileAppDestination.labourAttendance,
    );
    expect(
      normalPermissions?.destination,
      MobileAppDestination.normalDashboard,
    );
    expect(deniedPermissions?.destination, MobileAppDestination.denied);
    expect(incompletePermissions?.isComplete, isFalse);
    expect(
      incompletePermissions?.destination,
      MobileAppDestination.normalDashboard,
    );
  });

  test('does not read similarly named fields outside the user object', () {
    final permissions = MobileAppPermissions.fromLoginResponse({
      'mobile_app_login': true,
      'mobile_app_labour_attendance': true,
      'permissions': {
        'mobile_app_login': true,
        'mobile_app_labour_attendance': true,
      },
      'user': {'id': 'user-1'},
    });

    expect(permissions?.mobileAppLogin, isNull);
    expect(permissions?.mobileAppLabourAttendance, isNull);
  });

  test('permits the attendance route with attendance permission alone', () {
    final middleware = MobileAppPermissionMiddleware();

    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: false,
        mobileAppLabourAttendance: true,
      ),
    );
    expect(middleware.redirect(Routes.labourAttendance), isNull);

    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: true,
        mobileAppLabourAttendance: false,
      ),
    );
    expect(
      middleware.redirect(Routes.labourAttendance)?.name,
      Routes.dashboard,
    );
  });

  test('denies routes when the backend omits permission fields', () {
    MobileAppPermissions.beginSession(
      MobileAppPermissions.fromBootstrapResponse({
        'success': true,
        'user': {'id': 'user-1'},
      }),
    );

    final middleware = MobileAppPermissionMiddleware();
    expect(middleware.redirect(Routes.dashboard)?.name, Routes.loginPage);
    expect(
      middleware.redirect(Routes.labourAttendance)?.name,
      Routes.loginPage,
    );
  });

  test('restricts attendance-only users to the attendance dashboard', () {
    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: false,
        mobileAppLabourAttendance: true,
      ),
    );

    expect(
      MobileAppPermissionMiddleware().redirect(Routes.dashboard)?.name,
      Routes.labourAttendance,
    );
    expect(
      MobileAppPermissionMiddleware().redirect(Routes.purchaseOrder)?.name,
      Routes.labourAttendance,
    );
  });

  test('both permissions allow normal modules and Labour Attendance', () {
    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: true,
        mobileAppLabourAttendance: true,
      ),
    );
    final middleware = MobileAppPermissionMiddleware();

    expect(middleware.redirect(Routes.dashboard), isNull);
    expect(middleware.redirect(Routes.purchaseOrder), isNull);
    expect(middleware.redirect(Routes.labourAttendance), isNull);
  });

  test('main-app-only users cannot open Labour Attendance', () {
    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: true,
        mobileAppLabourAttendance: false,
      ),
    );

    expect(
      MobileAppPermissionMiddleware().redirect(Routes.labourAttendance)?.name,
      Routes.dashboard,
    );
  });

  test('users with neither permission are sent to login', () {
    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: false,
        mobileAppLabourAttendance: false,
      ),
    );

    final middleware = MobileAppPermissionMiddleware();
    expect(middleware.redirect(Routes.dashboard)?.name, Routes.loginPage);
    expect(
      middleware.redirect(Routes.labourAttendance)?.name,
      Routes.loginPage,
    );
  });

  test('redirects protected routes when no authenticated session exists', () {
    expect(
      MobileAppPermissionMiddleware().redirect(Routes.dashboard)?.name,
      Routes.loginPage,
    );
  });

  test('logout clears the current permission session', () {
    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: true,
        mobileAppLabourAttendance: true,
      ),
    );

    MobileAppPermissions.clear();

    expect(MobileAppPermissions.current, isNull);
    expect(MobileAppPermissions.hasAuthenticatedSession, isFalse);
  });

  test('switching users replaces old permission values', () {
    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: true,
        mobileAppLabourAttendance: true,
      ),
    );
    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: true,
        mobileAppLabourAttendance: false,
      ),
    );

    expect(
      MobileAppPermissions.current?.destination,
      MobileAppDestination.normalDashboard,
    );
    expect(
      MobileAppPermissionMiddleware().redirect(Routes.labourAttendance)?.name,
      Routes.dashboard,
    );
  });

  test('new attendance-only login removes prior normal-module access', () {
    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: true,
        mobileAppLabourAttendance: true,
      ),
    );
    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: false,
        mobileAppLabourAttendance: true,
      ),
    );

    final middleware = MobileAppPermissionMiddleware();
    expect(middleware.redirect(Routes.labourAttendance), isNull);
    expect(
      middleware.redirect(Routes.purchaseOrder)?.name,
      Routes.labourAttendance,
    );
  });

  test('denies users with neither mobile login nor attendance permission', () {
    final login = MobileAppPermissions.fromLoginResponse({
      'user': {
        'mobile_app_login': false,
        'mobile_app_labour_attendance': false,
      },
    });
    final bootstrap = MobileAppPermissions.fromBootstrapResponse({
      'user': {
        'mobile_app_login': false,
        'mobile_app_labour_attendance': false,
      },
    });

    final result = MobileAppPermissions.reconcile(login, bootstrap);

    expect(result.status, MobilePermissionReconciliationStatus.denied);
    expect(result.permissions?.destination, MobileAppDestination.denied);
  });
}
