import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:cocoper_mobile/app/config/environment.dart';
import 'package:cocoper_mobile/app/helpers/secure_store.dart';
import 'package:cocoper_mobile/app/helpers/shared_preferences.dart';
import 'package:cocoper_mobile/app/localization/localization.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/services/api_service.dart';
import 'package:cocoper_mobile/app/services/endpoints.dart';
import 'package:cocoper_mobile/app/services/mobile_app_permissions.dart';

class LoginController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  final isLoading = false.obs;
  final isPasswordVisible = false.obs;
  final rememberMe = false.obs;

  // ============================================================
  // LOGIN ENDPOINT
  // ============================================================

  // POST {baseUrl}auth/login  ->  https://uat.cocoper.com/api/auth/login
  static const String loginEndpoint = EndPoints.login;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();

    super.onClose();
  }

  // ============================================================
  // PASSWORD VISIBILITY
  // ============================================================

  void togglePasswordVisibility() {
    isPasswordVisible.toggle();
  }

  // ============================================================
  // REMEMBER ME
  // ============================================================

  void toggleRememberMe(bool? value) {
    rememberMe.value = value ?? false;
  }

  // ============================================================
  // LOGIN IDENTIFIER VALIDATION
  // ============================================================

  String? validateEmail(String? value) {
    final identifier = value?.trim() ?? '';

    if (identifier.isEmpty) {
      return 'Please enter your email or username';
    }

    return null;
  }

  // ============================================================
  // PASSWORD VALIDATION
  // ============================================================

  String? validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Please enter your password';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  // ============================================================
  // SUBMIT LOGIN
  // ============================================================

  Future<void> submit() async {
    if (isLoading.value) {
      return;
    }

    final isValid = formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    MobileAppPermissions.clear();

    final email = emailController.text.trim();
    final password = passwordController.text;

    try {
      isLoading.value = true;
      await FlutterSecureStore().deleteAllData();
      await _clearStoredUserIdentity();

      _logLogin(
        'request environment=${_environmentLabel()} '
        'api_base_url=${_safeBaseUrl()} '
        'endpoint_path=${_endpointPath(loginEndpoint)} client=mobile',
      );

      final response = await ApiService.post(
        loginEndpoint,
        {
          'email': email,
          'password': password,
          // The authentication contract identifies this as a mobile client.
          'client': 'mobile',
        },
        requireAuthToken: false,
      );

      if (response == null) {
        _logLogin(
          'authentication_result=unavailable permission_api_called=false',
        );
        _showError(
          'Network unavailable',
          'Unable to connect to the server. Please try again.',
        );
        return;
      }

      final data = response.data;
      _logPermissionResponse(
        source: 'login_response',
        endpoint: response.requestOptions.uri.toString(),
        statusCode: response.statusCode,
        requestId: response.headers.value('x-request-id'),
        body: data,
      );
      final success =
          response.statusCode == 200 && data is Map && data['success'] == true;
      _logLogin(
        'login_http_status=${response.statusCode} '
        'authentication_success=$success',
      );

      // ========================================================
      // SUCCESS
      // ========================================================

      if (response.statusCode == 200 &&
          data is Map &&
          data['success'] == true) {
        final loginResponse = Map<String, dynamic>.from(data);
        var permissions = MobileAppPermissions.fromLoginResponse(loginResponse);
        final user = _asMap(loginResponse['user']);

        _logLogin(
          'authenticated_user_parsed=${user != null} '
          'token_present=${loginResponse['token'] is String && (loginResponse['token'] as String).trim().isNotEmpty} '
          'userIdPresent=${user?['id'] != null} '
          'organizationIdPresent=${user?['organization_id'] != null} '
          'mobileLoginFieldFound='
          '${permissions?.hasMobileAppLoginField ?? false} '
          'mobileLogin=${permissions?.mobileAppLogin} '
          'labourAttendanceFieldFound='
          '${permissions?.hasLabourAttendanceField ?? false} '
          'labourAttendance=${permissions?.mobileAppLabourAttendance}',
        );

        if (permissions?.mobileAppLogin == false &&
            permissions?.canUseLabourAttendance != true) {
          await _clearRejectedLogin();
          _logLogin('denied reason=mobile_login_disabled');
          _showError(
            'Access denied',
            'Your account is not authorized to use the mobile app.',
          );
          return;
        }

        final token = loginResponse['token'];
        if (token is! String || token.trim().isEmpty) {
          await _clearRejectedLogin();
          _logLogin(
            'permission_result=verification_unavailable '
            'reason=login_token_missing bootstrap_api_called=false',
          );
          _showError(
            'Login verification unavailable',
            'Login succeeded, but the server did not provide the required '
                'authentication token. Please try again or contact support.',
          );
          return;
        }

        await _handleSuccessfulLogin(loginResponse);

        final storedAccessToken = await FlutterSecureStore().getSingleValue(
          SharedPrefsHelper.accessToken,
        );
        final tokenAvailable =
            storedAccessToken != null && storedAccessToken.trim().isNotEmpty;
        _logLogin(
          'bootstrap_request environment=${_environmentLabel()} '
          'api_base_url=${_safeBaseUrl()} '
          'endpoint_path=${_endpointPath(EndPoints.mobileBootstrap)} '
          'attempt=1 '
          'stored_access_token_present=$tokenAvailable',
        );
        if (!tokenAvailable) {
          await _clearRejectedLogin();
          _logLogin(
            'permission_result=verification_unavailable '
            'reason=stored_access_token_missing bootstrap_api_called=false',
          );
          _showError(
            'Permission verification unavailable',
            'The authenticated session could not be established. Please sign '
                'in again.',
          );
          return;
        }

        final bootstrapResponse = await ApiService.get(
          EndPoints.mobileBootstrap,
        );
        if (bootstrapResponse == null) {
          _logLogin(
            'bootstrap_result=unavailable http_status=none '
            'endpoint_path=${_endpointPath(EndPoints.mobileBootstrap)}',
          );
          await _clearRejectedLogin();
          _showError(
            'Permission verification unavailable',
            'Could not retrieve your mobile permissions. Check your '
                'connection and try again.',
          );
          return;
        }

        final bootstrapData = bootstrapResponse.data;
        _logPermissionResponse(
          source: 'bootstrap_response',
          endpoint: bootstrapResponse.requestOptions.uri.toString(),
          statusCode: bootstrapResponse.statusCode,
          requestId: bootstrapResponse.headers.value('x-request-id'),
          body: bootstrapData,
        );
        final bootstrapSuccess = bootstrapResponse.statusCode == 200 &&
            bootstrapData is Map &&
            bootstrapData['success'] == true;
        _logLogin(
          'bootstrap_http_status=${bootstrapResponse.statusCode} '
          'bootstrap_success=$bootstrapSuccess',
        );
        if (!bootstrapSuccess) {
          final denied = bootstrapResponse.statusCode == 401 ||
              bootstrapResponse.statusCode == 403;
          await _clearRejectedLogin();
          _showError(
            denied ? 'Access denied' : 'Permission verification failed',
            denied
                ? 'Your account is not authorized to use the mobile app.'
                : 'Could not retrieve your mobile permissions. Please try '
                    'again later.',
          );
          return;
        }

        final bootstrapMap = Map<String, dynamic>.from(bootstrapData);
        final bootstrapPermissions =
            MobileAppPermissions.fromBootstrapResponse(bootstrapMap);
        final reconciliation =
            MobileAppPermissions.reconcile(permissions, bootstrapPermissions);
        _logLogin(
          'permission_reconciliation status=${reconciliation.status.name} '
          'login=${permissions?.mobileAppLogin} '
          'login_attendance=${permissions?.mobileAppLabourAttendance} '
          'bootstrap=${bootstrapPermissions?.mobileAppLogin} '
          'bootstrap_attendance='
          '${bootstrapPermissions?.mobileAppLabourAttendance}',
        );

        if (reconciliation.status ==
            MobilePermissionReconciliationStatus.denied) {
          await _clearRejectedLogin();
          _logLogin(
              'navigation decision=denied reason=no_mobile_module_access');
          _showError(
            'Access denied',
            'Your account is not authorized to use the mobile app.',
          );
          return;
        }
        if (reconciliation.status !=
            MobilePermissionReconciliationStatus.verified) {
          final bootstrapDiagnostics =
              MobileAppPermissions.diagnoseResponse(bootstrapData);
          _logLogin(
            'permission_result=configuration_unverified '
            'reason=${reconciliation.status.name} '
            'login_parser_decision='
            '${MobileAppPermissions.diagnoseResponse(loginResponse)['parser_decision']} '
            'bootstrap_parser_decision='
            '${bootstrapDiagnostics['parser_decision']}',
          );
          await _clearRejectedLogin();
          _showError(
            'Permission verification failed',
            reconciliation.status ==
                    MobilePermissionReconciliationStatus.mismatch
                ? 'Login and bootstrap returned different mobile permissions. '
                    'Please contact your administrator.'
                : 'The server did not return both mobile permissions in both '
                    'responses. Please contact your administrator.',
          );
          return;
        }

        permissions = reconciliation.permissions!;
        await _storeDefaultAttendanceBranch(bootstrapMap);
        await _restoreSavedLocale();
        MobileAppPermissions.beginSession(permissions);

        final destination =
            permissions.destination == MobileAppDestination.labourAttendance
                ? Routes.labourAttendance
                : Routes.dashboard;
        _logLogin(
          'navigation decision=verified destination=$destination '
          'reason=login_and_bootstrap_permissions_match',
        );
        Get.offAllNamed<void>(destination);

        return;
      }

      // ========================================================
      // ERROR RESPONSE
      // ========================================================

      String message = 'Invalid email or password.';

      if (data is Map) {
        final serverMessage = data['message']?.toString();

        if (serverMessage != null && serverMessage.trim().isNotEmpty) {
          message = serverMessage.trim();
        }
      }

      _logLogin(
        'authentication_success=false '
        'http_status=${response.statusCode} '
        'permission_result=not_requested',
      );
      await FlutterSecureStore().deleteAllData();
      if (response.statusCode == 403) {
        _showError(
          'Access denied',
          message == 'Invalid email or password.'
              ? 'This account is not permitted to log in to the mobile app.'
              : message,
        );
      } else if (response.statusCode != null && response.statusCode! >= 500) {
        _showError(
          'Server unavailable',
          'The server could not complete login. Please try again later.',
        );
      } else {
        _showError('Login Failed', message);
      }
    } catch (e) {
      _logLogin(
        'authentication_result=error exception=${e.runtimeType} '
        'permission_result=not_requested',
      );
      await FlutterSecureStore().deleteAllData();

      _showError(
        'Login Failed',
        'Unable to login. Please try again.',
      );
    } finally {
      isLoading.value = false;
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

  void _logPermissionResponse({
    required String source,
    required String endpoint,
    required int? statusCode,
    required String? requestId,
    required dynamic body,
  }) {
    final diagnostics = MobileAppPermissions.diagnoseResponse(body);
    _logLogin(
      '$source environment=${_environmentLabel()} '
      'api_base_url=${_safeBaseUrl()} '
      'endpoint_path=${_endpointPath(endpoint)} '
      'http_status=$statusCode request_id=${requestId ?? 'none'} '
      'diagnostics=$diagnostics',
    );
  }

  String _safeBaseUrl() {
    final uri = Uri.tryParse(Environment.baseUrl);
    if (uri == null || uri.host.isEmpty) {
      return '[unparseable]';
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
  }

  String _environmentLabel() {
    final host = Uri.tryParse(Environment.baseUrl)?.host.toLowerCase();
    if (host == 'uat.cocoper.com') {
      return 'uat';
    }
    if (host == 'cocoper.com' || Environment.isProduction) {
      return 'production';
    }
    return 'custom_non_production';
  }

  String _endpointPath(String endpoint) {
    final uri = Uri.tryParse(endpoint);
    final path = uri?.hasAuthority == true ? uri!.path : endpoint;
    return path.split('?').first;
  }

  void _logLogin(String message) {
    if (!ApiService.isProduction) {
      debugPrint('[auth] $message');
    }
  }

  Future<void> _clearStoredUserIdentity() async {
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

  Future<void> _clearRejectedLogin() async {
    await FlutterSecureStore().deleteAllData();
    await _clearStoredUserIdentity();
    MobileAppPermissions.clear();
  }

  // ============================================================
  // HANDLE SUCCESSFUL LOGIN
  // ============================================================

  Future<void> _handleSuccessfulLogin(
    Map<String, dynamic> data,
  ) async {
    final token = data['token']?.toString().trim();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Login successful but token was not received.',
      );
    }

    // ==========================================================
    // SAVE JWT TOKEN
    // ==========================================================

    await FlutterSecureStore().storeSingleValue(
      SharedPrefsHelper.accessToken,
      token,
    );

    debugPrint(
      'JWT token saved successfully.',
    );

    // ==========================================================
    // REMEMBER EMAIL
    // ==========================================================

    await SharedPrefsHelper.setString(
      SharedPrefsHelper.emailId,
      emailController.text.trim(),
    );

    if (rememberMe.value) {
      await SharedPrefsHelper.setBool(
        SharedPrefsHelper.rememberMe,
        true,
      );
    }

    // ==========================================================
    // USER DATA
    // ==========================================================

    final userData = data['user'];

    if (userData is Map) {
      final user = Map<String, dynamic>.from(userData);

      final userId = user['id']?.toString();

      final username = user['username']?.toString();

      final fullName = user['full_name']?.toString();

      final role = user['role']?.toString();

      final organizationId = user['organization_id']?.toString();

      // --------------------------------------------------------
      // USER ID
      // --------------------------------------------------------

      if (userId != null && userId.trim().isNotEmpty && userId != 'null') {
        await SharedPrefsHelper.setString(
          SharedPrefsHelper.userId,
          userId.trim(),
        );
      }

      // --------------------------------------------------------
      // USERNAME
      // --------------------------------------------------------

      if (username != null &&
          username.trim().isNotEmpty &&
          username != 'null') {
        await SharedPrefsHelper.setString(
          SharedPrefsHelper.username,
          username.trim(),
        );
      }

      // --------------------------------------------------------
      // FULL NAME
      // --------------------------------------------------------

      if (fullName != null &&
          fullName.trim().isNotEmpty &&
          fullName != 'null') {
        await SharedPrefsHelper.setString(
          SharedPrefsHelper.fullName,
          fullName.trim(),
        );
      }

      // --------------------------------------------------------
      // ROLE
      // --------------------------------------------------------

      if (role != null && role.trim().isNotEmpty && role != 'null') {
        await SharedPrefsHelper.setString(
          SharedPrefsHelper.userRole,
          role.trim(),
        );
      }

      // --------------------------------------------------------
      // ORGANIZATION ID
      // --------------------------------------------------------

      if (organizationId != null &&
          organizationId.trim().isNotEmpty &&
          organizationId != 'null') {
        await SharedPrefsHelper.setString(
          SharedPrefsHelper.organizationId,
          organizationId.trim(),
        );
      }
    }

    debugPrint(
      '========================================',
    );
    debugPrint(
      'LOGIN SUCCESS',
    );
    debugPrint(
      'Token saved',
    );
    debugPrint(
      'User information saved',
    );
    debugPrint(
      'Navigating to dashboard',
    );
    debugPrint(
      '========================================',
    );
  }

  Future<void> _restoreSavedLocale() async {
    try {
      final localeValues = await Future.wait([
        SharedPrefsHelper.getString(
          SharedPrefsHelper.languageCode,
          defaultValue: 'en',
        ),
        SharedPrefsHelper.getString(
          SharedPrefsHelper.countryCode,
          defaultValue: 'US',
        ),
      ]);
      final languageCode = localeValues[0].isEmpty ? 'en' : localeValues[0];
      final countryCode = localeValues[1].isEmpty ? 'US' : localeValues[1];
      final locale = Locale(languageCode, countryCode);
      if (Localization.supportedLocales.contains(locale)) {
        Get.updateLocale(locale);
      } else {
        debugPrint(
          'Saved locale $languageCode-$countryCode is unsupported; using '
          '${Localization.defaultLocale.languageCode}-'
          '${Localization.defaultLocale.countryCode}.',
        );
      }
    } catch (error) {
      debugPrint('Unable to restore saved locale: $error');
    }
  }

  // ============================================================
  // ERROR SNACKBAR
  // ============================================================

  void _showError(
    String title,
    String message,
  ) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }
}
