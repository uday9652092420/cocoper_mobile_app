import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../helpers/shared_preferences.dart';
import '../models/labour_attendance.dart';
import 'attendance_location_provider.dart';
import 'api_service.dart';
import 'endpoints.dart';
import 'mobile_app_permissions.dart';

class LabourAttendanceException implements Exception {
  const LabourAttendanceException(
    this.message, {
    this.statusCode,
    this.isLocationError = false,
    this.isOutsideGeofence = false,
  });

  final String message;
  final int? statusCode;
  final bool isLocationError;
  final bool isOutsideGeofence;

  @override
  String toString() => message;
}

enum AttendanceLocationStatus {
  notRequired,
  withinGeofence,
  outsideGeofence,
}

class AttendanceLocationVerification {
  const AttendanceLocationVerification({
    required this.status,
    this.distanceMeters,
  });

  final AttendanceLocationStatus status;
  final double? distanceMeters;
}

abstract interface class LabourAttendanceRepository {
  Future<LabourAttendanceToday> getToday();

  Future<AttendanceLocationVerification> verifyCurrentLocation(
    LabourAttendanceToday today,
  );

  Future<LabourAttendanceActionResult> checkIn();

  Future<LabourAttendanceActionResult> checkOut({
    required String attendanceId,
    required String branchId,
  });
}

abstract interface class LabourAttendanceApi {
  Future<Response<dynamic>?> get(
    String endpoint, {
    required Map<String, String> headers,
    required String diagnosticLabel,
  });

  Future<Response<dynamic>?> post(
    String endpoint,
    Map<String, dynamic> body, {
    required Map<String, String> headers,
    required String diagnosticLabel,
  });

  Future<Response<dynamic>?> patch(
    String endpoint, {
    required Map<String, dynamic> body,
    required Map<String, String> headers,
    required String diagnosticLabel,
  });
}

class _ApiServiceLabourAttendanceApi implements LabourAttendanceApi {
  const _ApiServiceLabourAttendanceApi();

  @override
  Future<Response<dynamic>?> get(
    String endpoint, {
    required Map<String, String> headers,
    required String diagnosticLabel,
  }) =>
      ApiService.get(
        endpoint,
        headers: headers,
        diagnosticLabel: diagnosticLabel,
      );

  @override
  Future<Response<dynamic>?> post(
    String endpoint,
    Map<String, dynamic> body, {
    required Map<String, String> headers,
    required String diagnosticLabel,
  }) =>
      ApiService.post(
        endpoint,
        body,
        headers: headers,
        diagnosticLabel: diagnosticLabel,
      );

  @override
  Future<Response<dynamic>?> patch(
    String endpoint, {
    required Map<String, dynamic> body,
    required Map<String, String> headers,
    required String diagnosticLabel,
  }) =>
      ApiService.patch(
        endpoint,
        body: body,
        headers: headers,
        diagnosticLabel: diagnosticLabel,
      );
}

class LabourAttendanceService implements LabourAttendanceRepository {
  LabourAttendanceService({
    LabourAttendanceApi? api,
    AttendanceLocationProvider? locationProvider,
  })  : _api = api ?? const _ApiServiceLabourAttendanceApi(),
        _locationProvider =
            locationProvider ?? const GeolocatorAttendanceLocationProvider();

  final LabourAttendanceApi _api;
  final AttendanceLocationProvider _locationProvider;

  Future<Map<String, String>> _branchHeaders({String? branchId}) async {
    final selectedBranchId = branchId ??
        await SharedPrefsHelper.getString(
          SharedPrefsHelper.selectedBranchId,
        );
    if (selectedBranchId.trim().isEmpty) {
      throw const LabourAttendanceException(
        'No assigned branch is available for attendance. Contact your administrator.',
      );
    }
    return {'x-branch-id': selectedBranchId.trim()};
  }

  Future<({String userId, String organizationId, String userName})>
      _identity() async {
    final userId = await SharedPrefsHelper.getString(SharedPrefsHelper.userId);
    final organizationId = await SharedPrefsHelper.getString(
      SharedPrefsHelper.organizationId,
    );
    final userName = await SharedPrefsHelper.getString(
      SharedPrefsHelper.fullName,
    );
    if (userId.trim().isEmpty || organizationId.trim().isEmpty) {
      throw const LabourAttendanceException(
        'Your signed-in user or organization could not be verified. Sign in again.',
      );
    }
    return (
      userId: userId.trim(),
      organizationId: organizationId.trim(),
      userName: userName.trim(),
    );
  }

  void _requirePermissions() {
    final permissions = MobileAppPermissions.current;
    if (!MobileAppPermissions.hasAuthenticatedSession ||
        permissions?.canUseLabourAttendance != true) {
      throw const LabourAttendanceException(
        'Your account is not authorized to use Labour Attendance.',
        statusCode: 403,
      );
    }
  }

  @override
  Future<LabourAttendanceToday> getToday() async {
    _requirePermissions();
    final identity = await _identity();
    final headers = await _branchHeaders();
    final serverTodayResponse = await _api.get(
      EndPoints.mobileLabourAttendanceToday,
      headers: headers,
      diagnosticLabel: 'labour_attendance_today',
    );
    final serverTodayData = _readObject(
      serverTodayResponse,
      endpoint: EndPoints.mobileLabourAttendanceToday,
    );
    late final LabourAttendanceToday serverToday;
    try {
      serverToday = LabourAttendanceToday.fromJson(
        serverTodayData,
        authenticatedUserId: identity.userId,
        authenticatedUserName: identity.userName,
        authenticatedOrganizationId: identity.organizationId,
      );
    } on FormatException catch (error) {
      throw LabourAttendanceException(error.message);
    }
    _validateTodayScope(
      serverToday,
      userId: identity.userId,
      organizationId: identity.organizationId,
      branchId: headers['x-branch-id']!,
    );
    const endpoint = EndPoints.mobileLabourAttendance;
    final response = await _api.get(
      endpoint,
      headers: headers,
      diagnosticLabel: 'labour_attendance_list',
    );
    final rows = _readList(response, endpoint: endpoint);
    final records = <LabourAttendanceRecord>[];
    for (final row in rows) {
      final rowMap = _asMap(row);
      if (rowMap['user_id']?.toString() == identity.userId) {
        try {
          records.add(LabourAttendanceRecord.fromJson(rowMap));
        } on FormatException {
          throw const LabourAttendanceException(
            'The attendance service returned an invalid attendance record.',
          );
        }
      }
    }
    try {
      return serverToday.withHistory(records);
    } on FormatException catch (error) {
      throw LabourAttendanceException(error.message);
    }
  }

  @override
  Future<AttendanceLocationVerification> verifyCurrentLocation(
    LabourAttendanceToday today,
  ) async {
    _requirePermissions();
    final identity = await _identity();
    final headers = await _branchHeaders(branchId: today.branchId);
    _validateTodayScope(
      today,
      userId: identity.userId,
      organizationId: identity.organizationId,
      branchId: headers['x-branch-id']!,
    );

    final geofence = today.branchGeofence;
    if (geofence == null) {
      throw const LabourAttendanceException(
        'Branch geofence settings could not be verified. Refresh and retry.',
        isLocationError: true,
      );
    }
    if (!geofence.enabled) {
      return const AttendanceLocationVerification(
        status: AttendanceLocationStatus.notRequired,
      );
    }

    late final AttendanceLocationFix fix;
    try {
      fix = await _locationProvider.getCurrentFix();
    } on AttendanceLocationException catch (error) {
      throw LabourAttendanceException(error.message, isLocationError: true);
    }
    final distance = Geolocator.distanceBetween(
      geofence.latitude!,
      geofence.longitude!,
      fix.latitude,
      fix.longitude,
    );
    return AttendanceLocationVerification(
      status: distance <= geofence.radiusMeters
          ? AttendanceLocationStatus.withinGeofence
          : AttendanceLocationStatus.outsideGeofence,
      distanceMeters: distance,
    );
  }

  @override
  Future<LabourAttendanceActionResult> checkIn() async {
    _requirePermissions();
    final identity = await _identity();
    final branchHeaders = await _branchHeaders();
    final location = await _locationForAction(
      userId: identity.userId,
      userName: identity.userName,
      organizationId: identity.organizationId,
      branchId: branchHeaders['x-branch-id']!,
    );
    const endpoint = EndPoints.mobileLabourAttendanceCheckIn;
    final response = await _api.post(
      endpoint,
      location?.toJson() ?? <String, dynamic>{},
      headers: branchHeaders,
      diagnosticLabel: 'labour_attendance_check_in',
    );
    final result = _parseActionResult(response, endpoint);
    _validateRecordScope(
      result.attendance,
      userId: identity.userId,
      organizationId: identity.organizationId,
      branchId: branchHeaders['x-branch-id']!,
    );
    return result;
  }

  @override
  Future<LabourAttendanceActionResult> checkOut({
    required String attendanceId,
    required String branchId,
  }) async {
    _requirePermissions();
    final identity = await _identity();
    final location = await _locationForAction(
      userId: identity.userId,
      userName: identity.userName,
      organizationId: identity.organizationId,
      branchId: branchId,
    );
    final endpoint = EndPoints.mobileLabourAttendanceCheckOut(attendanceId);
    final response = await _api.patch(
      endpoint,
      body: location?.toJson() ?? <String, dynamic>{},
      headers: const <String, String>{},
      diagnosticLabel: 'labour_attendance_check_out',
    );
    final result = _parseActionResult(response, endpoint);
    _validateRecordScope(
      result.attendance,
      userId: identity.userId,
      organizationId: identity.organizationId,
      branchId: branchId,
    );
    return result;
  }

  Future<AttendanceLocationFix?> _locationForAction({
    required String userId,
    required String userName,
    required String organizationId,
    required String branchId,
  }) async {
    final response = await _api.get(
      EndPoints.mobileLabourAttendanceToday,
      headers: await _branchHeaders(branchId: branchId),
      diagnosticLabel: 'labour_attendance_geofence',
    );
    final data = _readObject(
      response,
      endpoint: EndPoints.mobileLabourAttendanceToday,
    );
    late final LabourAttendanceToday state;
    try {
      state = LabourAttendanceToday.fromJson(
        data,
        authenticatedUserId: userId,
        authenticatedUserName: userName,
        authenticatedOrganizationId: organizationId,
      );
    } on FormatException catch (error) {
      throw LabourAttendanceException(error.message);
    }
    _validateTodayScope(
      state,
      userId: userId,
      organizationId: organizationId,
      branchId: branchId,
    );
    final geofence = state.branchGeofence;
    if (geofence == null) {
      throw const LabourAttendanceException(
        'Branch geofence settings could not be verified. Refresh and retry.',
      );
    }
    if (!geofence.enabled) return null;

    try {
      return await _locationProvider.getCurrentFix();
    } on AttendanceLocationException catch (error) {
      throw LabourAttendanceException(
        error.message,
        isLocationError: true,
      );
    }
  }

  void _validateTodayScope(
    LabourAttendanceToday today, {
    required String userId,
    required String organizationId,
    required String branchId,
  }) {
    if (today.employeeId != userId ||
        today.organizationId != organizationId ||
        today.branchId != branchId) {
      throw const LabourAttendanceException(
        'The attendance service returned a different user or branch scope.',
      );
    }
  }

  LabourAttendanceActionResult _parseActionResult(
    Response<dynamic>? response,
    String endpoint,
  ) {
    final data = _readObject(response, endpoint: endpoint);
    try {
      return LabourAttendanceActionResult.fromJson(data);
    } on FormatException {
      _logFailure(
        endpoint: endpoint,
        statusCode: response?.statusCode,
        requestId: response?.headers.value('x-request-id'),
        errorCode: 'invalid_response',
      );
      throw const LabourAttendanceException(
        'The attendance service returned an invalid attendance record.',
      );
    }
  }

  List<dynamic> _readList(
    Response<dynamic>? response, {
    required String endpoint,
  }) {
    final body = _readBody(response, endpoint: endpoint);
    final data = body['data'];
    if (data is! List) {
      _logFailure(
        endpoint: endpoint,
        statusCode: response?.statusCode,
        requestId: response?.headers.value('x-request-id'),
        errorCode: 'invalid_response',
      );
      throw const LabourAttendanceException(
        'The attendance service returned an invalid attendance list.',
      );
    }
    return data;
  }

  Map<String, dynamic> _readObject(
    Response<dynamic>? response, {
    required String endpoint,
  }) {
    _logResponseShape(response, endpoint);
    final body = _readBody(response, endpoint: endpoint);
    try {
      return _asMap(body['data']);
    } on FormatException {
      _logFailure(
        endpoint: endpoint,
        statusCode: response?.statusCode,
        requestId: response?.headers.value('x-request-id'),
        errorCode: 'invalid_response',
      );
      throw const LabourAttendanceException(
        'The attendance service returned an invalid attendance record.',
      );
    }
  }

  Map<String, dynamic> _readBody(
    Response<dynamic>? response, {
    required String endpoint,
  }) {
    if (response == null) {
      _logFailure(
        endpoint: endpoint,
        statusCode: null,
        requestId: null,
        errorCode: 'no_response',
      );
      throw const LabourAttendanceException(
        'Unable to reach the attendance service. Check your connection and retry.',
      );
    }
    late final Map<String, dynamic> body;
    try {
      body = _asMap(response.data);
    } on FormatException {
      _logFailure(
        endpoint: endpoint,
        statusCode: response.statusCode,
        requestId: response.headers.value('x-request-id'),
        errorCode: 'invalid_response',
      );
      throw const LabourAttendanceException(
        'The attendance service returned an invalid response.',
      );
    }
    final statusCode = response.statusCode;
    if (statusCode == 401) {
      _logFailure(
        endpoint: endpoint,
        statusCode: statusCode,
        requestId: response.headers.value('x-request-id'),
        errorCode: _errorCode(body, statusCode),
      );
      throw const LabourAttendanceException(
        'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }
    if (statusCode == 403) {
      _logFailure(
        endpoint: endpoint,
        statusCode: statusCode,
        requestId: response.headers.value('x-request-id'),
        errorCode: _errorCode(body, statusCode),
      );
      throw LabourAttendanceException(
        _message(body, 'You are not authorized to use Labour Attendance.'),
        statusCode: 403,
      );
    }
    final errorCode = _errorCode(body, statusCode);
    if (errorCode == 'LABOUR_LINK_REQUIRED') {
      _logFailure(
        endpoint: endpoint,
        statusCode: statusCode,
        requestId: response.headers.value('x-request-id'),
        errorCode: errorCode,
      );
      throw LabourAttendanceException(
        'This login is not linked to an active labour record. Ask your COPPER '
        'administrator to link it in User Master, then retry.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 404 &&
        endpoint == EndPoints.mobileLabourAttendanceToday) {
      _logFailure(
        endpoint: endpoint,
        statusCode: statusCode,
        requestId: response.headers.value('x-request-id'),
        errorCode: 'attendance_today_route_missing',
      );
      throw const LabourAttendanceException(
        'The attendance API on this server is outdated. Update the backend to '
        'support today’s attendance and branch location settings, then retry.',
        statusCode: 404,
      );
    }
    if (statusCode == null ||
        statusCode < 200 ||
        statusCode >= 300 ||
        body['success'] != true) {
      final code = _errorCode(body, statusCode);
      final message = _message(body, 'Attendance request failed');
      final outsideGeofence = _isOutsideGeofence(code, message);
      _logFailure(
        endpoint: endpoint,
        statusCode: statusCode,
        requestId: response.headers.value('x-request-id'),
        errorCode: code,
      );
      throw LabourAttendanceException(
        '$message (HTTP ${statusCode ?? 'unknown'}, $code).',
        statusCode: statusCode,
        isLocationError: outsideGeofence || _isLocationFailure(code, message),
        isOutsideGeofence: outsideGeofence,
      );
    }
    return body;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Expected a JSON object');
  }

  String _message(Map<String, dynamic> body, String fallback) {
    final nestedError = body['error'];
    final nestedMessage = nestedError is Map ? nestedError['message'] : null;
    final message = (body['message'] ?? nestedMessage ?? nestedError)
            ?.toString()
            .replaceAll(RegExp(r'[\r\n\t]'), ' ')
            .trim() ??
        '';
    if (message.isEmpty) return fallback;
    return message.length <= 240 ? message : '${message.substring(0, 240)}...';
  }

  String _errorCode(Map<String, dynamic> body, int? statusCode) {
    final details = body['details'];
    final nestedCode =
        details is Map ? details['errorCode'] ?? details['code'] : null;
    final nestedError = body['error'];
    final nestedErrorCode = nestedError is Map
        ? nestedError['errorCode'] ?? nestedError['code']
        : null;
    final candidate =
        (body['errorCode'] ?? body['code'] ?? nestedCode ?? nestedErrorCode)
                ?.toString() ??
            '';
    if (RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(candidate)) {
      return candidate;
    }
    return statusCode == null ? 'unknown' : 'http_$statusCode';
  }

  bool _isOutsideGeofence(String code, String message) {
    final normalizedCode = code.toUpperCase();
    final normalizedMessage = message.toLowerCase();
    return normalizedCode.contains('GEOFENCE') ||
        normalizedCode.contains('OUTSIDE') ||
        normalizedCode.contains('DISTANCE') ||
        normalizedMessage.contains('geofence') ||
        normalizedMessage.contains('outside') ||
        normalizedMessage.contains('not within') ||
        normalizedMessage.contains('branch radius') ||
        normalizedMessage.contains('too far');
  }

  bool _isLocationFailure(String code, String message) {
    final normalizedCode = code.toUpperCase();
    final normalizedMessage = message.toLowerCase();
    return normalizedCode.contains('LOCATION') ||
        normalizedCode.contains('GPS') ||
        normalizedMessage.contains('location') ||
        normalizedMessage.contains('gps');
  }

  void _logResponseShape(
    Response<dynamic>? response,
    String endpoint,
  ) {
    if (ApiService.isProduction) return;
    debugPrint(
      '[labour_attendance_response_shape] '
      'endpoint=$endpoint '
      'status=${response?.statusCode ?? 'none'} '
      'contentType=${response?.headers.value('content-type') ?? 'none'} '
      'bodyShape=${_jsonShape(response?.data)}',
    );
  }

  String _jsonShape(dynamic value, {int depth = 0}) {
    if (value == null) return 'null';
    if (value is Map) {
      if (depth >= 3) return 'object';
      final entries = value.entries.take(40).map((entry) {
        final key = entry.key.toString();
        return '$key:${_jsonShape(entry.value, depth: depth + 1)}';
      });
      final suffix = value.length > 40 ? ',…' : '';
      return '{${entries.join(',')}$suffix}';
    }
    if (value is List) {
      if (value.isEmpty) return 'array(length:0)';
      return 'array(length:${value.length},first:${_jsonShape(value.first, depth: depth + 1)})';
    }
    if (value is String) return 'string';
    if (value is bool) return 'boolean';
    if (value is num) return 'number';
    return 'other';
  }

  void _validateRecordScope(
    LabourAttendanceRecord record, {
    required String userId,
    required String organizationId,
    required String branchId,
  }) {
    if (record.userId != userId ||
        record.organizationId != organizationId ||
        record.branchId != branchId) {
      throw const LabourAttendanceException(
        'The attendance response did not match the signed-in user and branch.',
      );
    }
  }

  void _logFailure({
    required String endpoint,
    required int? statusCode,
    required String? requestId,
    required String errorCode,
  }) {
    if (ApiService.isProduction) return;
    developer.log(
      'endpoint=$endpoint status=${statusCode ?? 'none'} '
      'requestId=${requestId ?? 'none'} errorCode=$errorCode',
      name: 'labour_attendance',
    );
  }
}
