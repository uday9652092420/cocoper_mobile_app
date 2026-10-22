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
    );
    final data = _readData(response);
    return LabourAttendanceToday.fromJson(data);
  }

  @override
  Future<LabourAttendanceActionResult> checkIn() async {
    final response = await ApiService.post(
      EndPoints.mobileLabourAttendanceCheckIn,
      const <String, dynamic>{},
      headers: await _branchHeaders(),
    );
    return LabourAttendanceActionResult.fromJson(_readData(response));
  }

  @override
  Future<LabourAttendanceActionResult> checkOut({
    required String branchId,
  }) async {
    final response = await ApiService.post(
      EndPoints.mobileLabourAttendanceCheckOut,
      const <String, dynamic>{},
      headers: await _branchHeaders(branchId: branchId),
    );
    return LabourAttendanceActionResult.fromJson(_readData(response));
  }

  Map<String, dynamic> _readData(Response<dynamic>? response) {
    if (response == null) {
      throw const LabourAttendanceException(
        'Unable to reach the attendance service. Check your connection and retry.',
      );
    }
    final body = _asMap(response.data);
    if (response.statusCode == 401) {
      throw const LabourAttendanceException(
        'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      throw LabourAttendanceException(
        _message(body, 'You are not authorized to use Labour Attendance.'),
        statusCode: 403,
      );
    }
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300 ||
        body['success'] != true) {
      throw LabourAttendanceException(
        _message(body, 'The attendance request could not be completed.'),
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
}
