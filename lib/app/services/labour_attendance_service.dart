import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../helpers/shared_preferences.dart';
import '../models/labour_attendance.dart';
import 'api_service.dart';
import 'endpoints.dart';

class LabourAttendanceException implements Exception {
  const LabourAttendanceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract interface class LabourAttendanceRepository {
  Future<LabourAttendanceToday> getToday();

  Future<LabourAttendanceActionResult> checkIn();

  Future<LabourAttendanceActionResult> checkOut({required String branchId});
}

class LabourAttendanceService implements LabourAttendanceRepository {
  Future<Map<String, String>> _branchHeaders({String? branchId}) async {
    final selectedBranchId = branchId ??
        await SharedPrefsHelper.getString(
          SharedPrefsHelper.selectedBranchId,
        );
    if (selectedBranchId.isEmpty) {
      throw const LabourAttendanceException(
        'No assigned branch is available for attendance. Contact your administrator.',
      );
    }
    return {'x-branch-id': selectedBranchId};
  }

  @override
  Future<LabourAttendanceToday> getToday() async {
    final response = await ApiService.get(
      EndPoints.mobileLabourAttendanceToday,
      headers: await _branchHeaders(),
      diagnosticLabel: 'labour_attendance_today',
    );
    final data = _readData(
      response,
      endpoint: EndPoints.mobileLabourAttendanceToday,
    );
    return LabourAttendanceToday.fromJson(data);
  }

  @override
  Future<LabourAttendanceActionResult> checkIn() async {
    final response = await ApiService.post(
      EndPoints.mobileLabourAttendanceCheckIn,
      const <String, dynamic>{},
      headers: await _branchHeaders(),
      diagnosticLabel: 'labour_attendance_check_in',
    );
    return LabourAttendanceActionResult.fromJson(
      _readData(
        response,
        endpoint: EndPoints.mobileLabourAttendanceCheckIn,
      ),
    );
  }

  @override
  Future<LabourAttendanceActionResult> checkOut({
    required String branchId,
  }) async {
    final response = await ApiService.post(
      EndPoints.mobileLabourAttendanceCheckOut,
      const <String, dynamic>{},
      headers: await _branchHeaders(branchId: branchId),
      diagnosticLabel: 'labour_attendance_check_out',
    );
    return LabourAttendanceActionResult.fromJson(
      _readData(
        response,
        endpoint: EndPoints.mobileLabourAttendanceCheckOut,
      ),
    );
  }

  Map<String, dynamic> _readData(
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
    final body = _asMap(response.data);
    if (response.statusCode == 401) {
      _logFailure(
        endpoint: endpoint,
        statusCode: response.statusCode,
        requestId: response.headers.value('x-request-id'),
        errorCode: _errorCode(body, response.statusCode),
      );
      throw const LabourAttendanceException(
        'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      _logFailure(
        endpoint: endpoint,
        statusCode: response.statusCode,
        requestId: response.headers.value('x-request-id'),
        errorCode: _errorCode(body, response.statusCode),
      );
      throw LabourAttendanceException(
        _message(body, 'You are not authorized to use Labour Attendance.'),
        statusCode: 403,
      );
    }
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300 ||
        body['success'] != true) {
      _logFailure(
        endpoint: endpoint,
        statusCode: response.statusCode,
        requestId: response.headers.value('x-request-id'),
        errorCode: _errorCode(body, response.statusCode),
      );
      throw LabourAttendanceException(
        _message(
          body,
          'Attendance API returned HTTP ${response.statusCode ?? 'unknown'} '
          '(${_errorCode(body, response.statusCode)}).',
        ),
        statusCode: response.statusCode,
      );
    }
    return _asMap(body['data']);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  String _message(Map<String, dynamic> body, String fallback) {
    final message = body['message']?.toString().trim() ?? '';
    return message.isEmpty ? fallback : message;
  }

  String _errorCode(Map<String, dynamic> body, int? statusCode) {
    final candidate = (body['errorCode'] ?? body['code'])?.toString() ?? '';
    if (RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(candidate)) {
      return candidate;
    }
    return statusCode == null ? 'unknown' : 'http_$statusCode';
  }

  void _logFailure({
    required String endpoint,
    required int? statusCode,
    required String? requestId,
    required String errorCode,
  }) {
    if (ApiService.isProduction) return;
    developer.log(
      'endpoint=$endpoint '
      'status=${statusCode ?? 'none'} '
      'requestId=${requestId ?? 'none'} errorCode=$errorCode',
      name: 'labour_attendance',
    );
  }
}
