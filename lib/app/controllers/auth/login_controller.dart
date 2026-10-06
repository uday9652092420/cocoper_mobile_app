import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:cocoper_mobile/app/helpers/secure_store.dart';
import 'package:cocoper_mobile/app/helpers/shared_preferences.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/services/api_service.dart';
import 'package:cocoper_mobile/app/services/endpoints.dart';

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
  // EMAIL VALIDATION
  // ============================================================

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Please enter your email';
    }

    if (!RegExp(
      r'^[\w.+-]+@[\w-]+\.[\w\.-]+$',
    ).hasMatch(email)) {
      return 'Please enter a valid email address';
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

    final email = emailController.text.trim();
    final password = passwordController.text;

    try {
      isLoading.value = true;

      debugPrint(
        '========================================',
      );
      debugPrint(
        'COCOPER MOBILE LOGIN',
      );
      debugPrint(
        'Email: $email',
      );
      debugPrint(
        'Endpoint: $loginEndpoint',
      );
      debugPrint(
        '========================================',
      );

      final response = await ApiService.post(
        loginEndpoint,
        {
          'email': email,
          'password': password,
          // The backend only enforces the mobile-app login permission when the
          // client explicitly identifies itself as mobile.
          'client': 'mobile',
        },
        requireAuthToken: false,
      );

      if (response == null) {
        _showError(
          'Unable to connect to the server. Please try again.',
        );
        return;
      }

      debugPrint(
        'Login status code: ${response.statusCode}',
      );

      debugPrint(
        'Login response: ${response.data}',
      );

      final data = response.data;

      // ========================================================
      // SUCCESS
      // ========================================================

      if (response.statusCode == 200 &&
          data is Map &&
          data['success'] == true) {
        await _handleSuccessfulLogin(
          Map<String, dynamic>.from(data),
        );

        Get.offAllNamed(
          Routes.dashboard,
        );

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

      _showError(message);
    } catch (e, stackTrace) {
      debugPrint(
        'LOGIN EXCEPTION: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      _showError(
        'Unable to login. Please try again.',
      );
    } finally {
      isLoading.value = false;
    }
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

  // ============================================================
  // ERROR SNACKBAR
  // ============================================================

  void _showError(String message) {
    Get.snackbar(
      'Login Failed',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }
}
