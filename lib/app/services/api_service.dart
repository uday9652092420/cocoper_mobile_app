import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../config/environment.dart';
import '../custome_widgets/no_internet_connection.dart';
import '../helpers/console_print.dart';
import '../helpers/flutter_toast.dart';
import '../helpers/helper_check_internet.dart';
import '../helpers/secure_store.dart';
import '../helpers/shared_preferences.dart';

class ApiService {
  static bool interceptorsAdded = false;

  static bool isInternetDialouge = false;

  static const bool isProduction = Environment.isProduction;

  static final Map<String, String> commonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: Environment.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: commonHeaders,
      responseType: ResponseType.json,
    ),
  );

  // ============================================================
  // HEADERS
  // ============================================================

  static Future<Map<String, String>> _mergeHeaders(
    Map<String, String>? headers, {
    bool requireAuthToken = true,
  }) async {
    final mergedHeaders = <String, String>{
      ...commonHeaders,
      ...?headers,
    };

    if (requireAuthToken) {
      final accessToken = await FlutterSecureStore().getSingleValue(
        SharedPrefsHelper.accessToken,
      );

      final organizationId = await SharedPrefsHelper.getString(
        SharedPrefsHelper.organizationId,
      );

      if (organizationId.isNotEmpty) {
        mergedHeaders['x-organization-id'] = organizationId;
      }

      if (accessToken != null && accessToken.trim().isNotEmpty) {
        mergedHeaders['Authorization'] = 'Bearer ${accessToken.trim()}';
      }
    }

    return mergedHeaders;
  }

  // ============================================================
  // NO INTERNET
  // ============================================================

  static Future<void> _showNoInternetDialog() async {
    if (isInternetDialouge) {
      return;
    }

    if (Get.context == null) {
      return;
    }

    isInternetDialouge = true;

    try {
      await Get.dialog(
        const NoInternetConnection(),
        barrierColor: const Color(0xFF000000).withValues(
          alpha: 0.7,
        ),
        barrierDismissible: false,
      );
    } finally {
      isInternetDialouge = false;
    }
  }

  // ============================================================
  // INTERCEPTORS
  // ============================================================

  static void _addInterceptors() {
    if (interceptorsAdded) {
      return;
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        // --------------------------------------------------------
        // REQUEST
        // --------------------------------------------------------

        onRequest: (options, handler) {
          if (!isProduction) {
            log(
              '''
========== API REQUEST ==========
URL: ${options.uri}
Method: ${options.method}
Headers: ${options.headers}
Body: ${options.data ?? ''}
==================================
''',
            );
          }

          handler.next(options);
        },

        // --------------------------------------------------------
        // RESPONSE
        // --------------------------------------------------------

        onResponse: (response, handler) {
          if (!isProduction) {
            log(
              '''
========== API RESPONSE =========
URL: ${response.requestOptions.uri}
Status: ${response.statusCode}
Data: ${response.data}
==================================
''',
            );
          }

          handler.next(response);
        },

        // --------------------------------------------------------
        // ERROR
        // --------------------------------------------------------

        onError: (error, handler) {
          if (!isProduction) {
            log(
              '''
========== API ERROR ============
URL: ${error.requestOptions.uri}
Method: ${error.requestOptions.method}
Status: ${error.response?.statusCode}
Message: ${error.message}
Response: ${error.response?.data}
=================================
''',
            );
          }

          final statusCode = error.response?.statusCode;

          // Server error
          if (statusCode != null && statusCode >= 500) {
            if (Get.context != null) {
              errorToast(
                'Something went wrong. Please try again.',
              );
            }
          }

          // IMPORTANT:
          //
          // Do NOT logout automatically for 401.
          //
          // Login can itself return 401 when credentials
          // are incorrect.
          //
          // The controller handles login failure.

          handler.next(error);
        },
      ),
    );

    interceptorsAdded = true;
  }

  // ============================================================
  // POST
  // ============================================================

  static Future<Response?> post(
    String endpoint,
    dynamic body, {
    Map<String, String>? headers,
    bool requireAuthToken = true,
  }) async {
    if (!await isInternet()) {
      consolePrint(
        'Internet connection unavailable.',
      );

      await _showNoInternetDialog();

      return null;
    }

    _addInterceptors();

    try {
      final mergedHeaders = await _mergeHeaders(
        headers,
        requireAuthToken: requireAuthToken,
      );

      final response = await dio.post(
        endpoint,
        data: body,
        options: Options(
          headers: mergedHeaders,
        ),
      );

      return response;
    } on DioException catch (e) {
      debugPrint(
        '========== POST API ERROR ==========',
      );
      debugPrint(
        'URL: ${e.requestOptions.uri}',
      );
      debugPrint(
        'Status: ${e.response?.statusCode}',
      );
      debugPrint(
        'Response: ${e.response?.data}',
      );
      debugPrint(
        'Message: ${e.message}',
      );
      debugPrint(
        '====================================',
      );

      return e.response;
    } catch (e) {
      debugPrint(
        'POST API EXCEPTION: $e',
      );

      return null;
    }
  }

  // ============================================================
  // GET
  // ============================================================

  static Future<Response?> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    bool requireAuthToken = true,
  }) async {
    if (!await isInternet()) {
      consolePrint(
        'Internet connection unavailable.',
      );

      await _showNoInternetDialog();

      return null;
    }

    _addInterceptors();

    try {
      final mergedHeaders = await _mergeHeaders(
        headers,
        requireAuthToken: requireAuthToken,
      );

      final response = await dio.get(
        endpoint,
        queryParameters: queryParameters,
        options: Options(
          headers: mergedHeaders,
        ),
      );

      return response;
    } on DioException catch (e) {
      debugPrint(
        '========== GET API ERROR ==========',
      );
      debugPrint(
        'URL: ${e.requestOptions.uri}',
      );
      debugPrint(
        'Status: ${e.response?.statusCode}',
      );
      debugPrint(
        'Response: ${e.response?.data}',
      );
      debugPrint(
        'Message: ${e.message}',
      );
      debugPrint(
        '===================================',
      );

      return e.response;
    } catch (e) {
      debugPrint(
        'GET API EXCEPTION: $e',
      );

      return null;
    }
  }

  // ============================================================
  // PUT
  // ============================================================

  static Future<Response?> put(
    String endpoint,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
    bool requireAuthToken = true,
  }) async {
    if (!await isInternet()) {
      consolePrint(
        'Internet connection unavailable.',
      );

      await _showNoInternetDialog();

      return null;
    }

    _addInterceptors();

    try {
      final mergedHeaders = await _mergeHeaders(
        headers,
        requireAuthToken: requireAuthToken,
      );

      final response = await dio.put(
        endpoint,
        data: body,
        options: Options(
          headers: mergedHeaders,
        ),
      );

      return response;
    } on DioException catch (e) {
      debugPrint(
        '========== PUT API ERROR ==========',
      );
      debugPrint(
        'URL: ${e.requestOptions.uri}',
      );
      debugPrint(
        'Status: ${e.response?.statusCode}',
      );
      debugPrint(
        'Response: ${e.response?.data}',
      );
      debugPrint(
        'Message: ${e.message}',
      );
      debugPrint(
        '===================================',
      );

      return e.response;
    } catch (e) {
      debugPrint(
        'PUT API EXCEPTION: $e',
      );

      return null;
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  static Future<Response?> delete(
    String endpoint, {
    Map<String, String>? headers,
    bool requireAuthToken = true,
  }) async {
    if (!await isInternet()) {
      consolePrint(
        'Internet connection unavailable.',
      );

      await _showNoInternetDialog();

      return null;
    }

    _addInterceptors();

    try {
      final mergedHeaders = await _mergeHeaders(
        headers,
        requireAuthToken: requireAuthToken,
      );

      final response = await dio.delete(
        endpoint,
        options: Options(
          headers: mergedHeaders,
        ),
      );

      return response;
    } on DioException catch (e) {
      debugPrint(
        '========== DELETE API ERROR ==========',
      );
      debugPrint(
        'URL: ${e.requestOptions.uri}',
      );
      debugPrint(
        'Status: ${e.response?.statusCode}',
      );
      debugPrint(
        'Response: ${e.response?.data}',
      );
      debugPrint(
        'Message: ${e.message}',
      );
      debugPrint(
        '======================================',
      );

      return e.response;
    } catch (e) {
      debugPrint(
        'DELETE API EXCEPTION: $e',
      );

      return null;
    }
  }
}
