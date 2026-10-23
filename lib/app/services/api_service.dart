import 'dart:developer';
import 'dart:convert';

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
      connectTimeout: isProduction
          ? const Duration(seconds: 15)
          : const Duration(seconds: 8),
      sendTimeout: isProduction
          ? const Duration(seconds: 15)
          : const Duration(seconds: 8),
      receiveTimeout: isProduction
          ? const Duration(seconds: 15)
          : const Duration(seconds: 8),
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
      await Get.dialog<void>(
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
Path: ${options.uri.path}
Method: ${options.method}
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
Path: ${response.requestOptions.uri.path}
Status: ${response.statusCode}
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
Path: ${error.requestOptions.uri.path}
Method: ${error.requestOptions.method}
Status: ${error.response?.statusCode}
Error type: ${error.type.name}
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

  static Future<Response<dynamic>?> post(
    String endpoint,
    dynamic body, {
    Map<String, String>? headers,
    bool requireAuthToken = true,
    String? diagnosticLabel,
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

      if (!isProduction && diagnosticLabel != null) {
        log(
          'HTTP request\n'
          'path: ${_endpointPath(endpoint)}\n'
          'method: POST\n'
          'bearerTokenPresent: '
          '${mergedHeaders['Authorization']?.startsWith('Bearer ') == true}\n'
          'payloadKeys: ${_safePayloadKeys(body)}',
          name: diagnosticLabel,
        );
      }

      final response = await dio.post<dynamic>(
        endpoint,
        data: body,
        options: Options(
          headers: mergedHeaders,
        ),
      );

      if (!isProduction && diagnosticLabel != null) {
        log(
          'HTTP response\n'
          'path: ${response.requestOptions.uri.path}\n'
          'method: ${response.requestOptions.method}\n'
          'status: ${response.statusCode}\n'
          'requestId: ${response.headers.value('x-request-id') ?? 'none'}\n'
          'body: ${jsonEncode(_safeDiagnosticBody(response.data))}',
          name: diagnosticLabel,
        );
      }
      return response;
    } on DioException catch (e) {
      if (!isProduction && diagnosticLabel != null) {
        log(
          'HTTP error\n'
          'path: ${e.requestOptions.uri.path}\n'
          'method: ${e.requestOptions.method}\n'
          'status: ${e.response?.statusCode}\n'
          'requestId: ${e.response?.headers.value('x-request-id') ?? 'none'}\n'
          'body: ${jsonEncode(_safeDiagnosticBody(e.response?.data))}\n'
          'errorType: ${e.type.name}',
          name: diagnosticLabel,
        );
      }
      debugPrint(
        '========== POST API ERROR ==========',
      );
      debugPrint(
        'Path: ${e.requestOptions.uri.path}',
      );
      debugPrint(
        'Status: ${e.response?.statusCode}',
      );
      debugPrint(
        'Error type: ${e.type.name}',
      );
      debugPrint(
        '====================================',
      );

      return e.response;
    } catch (e) {
      debugPrint('POST API EXCEPTION: ${e.runtimeType}');

      return null;
    }
  }

  static List<String> _safePayloadKeys(dynamic body) {
    if (body is! Map) {
      return const [];
    }
    return body.keys.map((key) => key.toString()).toList(growable: false);
  }

  static Map<String, dynamic> _safeDiagnosticBody(dynamic body) {
    if (body is! Map) {
      return const {};
    }
    const safeKeys = {
      'success',
      'code',
      'errorCode',
      'requestId',
    };
    return <String, dynamic>{
      for (final entry in body.entries)
        if (safeKeys.contains(entry.key.toString()))
          entry.key.toString(): entry.value,
    };
  }

  // ============================================================
  // GET
  // ============================================================

  static Future<Response<dynamic>?> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    bool requireAuthToken = true,
    String? diagnosticLabel,
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

      if (!isProduction && diagnosticLabel != null) {
        log(
          'HTTP request\n'
          'path: ${_endpointPath(endpoint)}\n'
          'method: GET\n'
          'bearerTokenPresent: '
          '${mergedHeaders['Authorization']?.startsWith('Bearer ') == true}',
          name: diagnosticLabel,
        );
      }

      final response = await dio.get<dynamic>(
        endpoint,
        queryParameters: queryParameters,
        options: Options(
          headers: mergedHeaders,
        ),
      );

      if (!isProduction && diagnosticLabel != null) {
        log(
          'HTTP response\n'
          'path: ${_endpointPath(endpoint)}\n'
          'method: GET\n'
          'status: ${response.statusCode}\n'
          'requestId: ${response.headers.value('x-request-id') ?? 'none'}',
          name: diagnosticLabel,
        );
      }
      return response;
    } on DioException catch (e) {
      if (!isProduction && diagnosticLabel != null) {
        log(
          'HTTP error\n'
          'path: ${_endpointPath(endpoint)}\n'
          'method: GET\n'
          'status: ${e.response?.statusCode ?? 'none'}\n'
          'requestId: ${e.response?.headers.value('x-request-id') ?? 'none'}\n'
          'errorType: ${e.type.name}',
          name: diagnosticLabel,
        );
      }
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
        'Error type: ${e.type.name}',
      );
      debugPrint(
        '===================================',
      );

      return e.response;
    } catch (e) {
      debugPrint(
        'GET API EXCEPTION: ${e.runtimeType}',
      );

      return null;
    }
  }

  static String _endpointPath(String endpoint) {
    final uri = Uri.tryParse(endpoint);
    return (uri?.hasAuthority == true ? uri!.path : endpoint).split('?').first;
  }

  // ============================================================
  // PUT
  // ============================================================

  static Future<Response<dynamic>?> put(
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

      final response = await dio.put<dynamic>(
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

  static Future<Response<dynamic>?> delete(
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

      final response = await dio.delete<dynamic>(
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
