import 'package:cocoper_mobile/app/helpers/shared_preferences.dart';
import 'package:cocoper_mobile/app/services/endpoints.dart';
import 'package:cocoper_mobile/app/services/attendance_location_provider.dart';
import 'package:cocoper_mobile/app/services/labour_attendance_service.dart';
import 'package:cocoper_mobile/app/services/mobile_app_permissions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsHelper.init();
    await SharedPrefsHelper.setString(SharedPrefsHelper.userId, 'user-1');
    await SharedPrefsHelper.setString(
      SharedPrefsHelper.organizationId,
      'org-1',
    );
    await SharedPrefsHelper.setString(
      SharedPrefsHelper.selectedBranchId,
      'branch-1',
    );
    await SharedPrefsHelper.setString(
      SharedPrefsHelper.fullName,
      'Authenticated User',
    );
    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: true,
        mobileAppLabourAttendance: true,
      ),
    );
  });

  tearDown(MobileAppPermissions.clear);

  test('GET uses collection route and selected branch, filters to own record',
      () async {
    final api = FakeLabourAttendanceApi()
      ..getResponse = _success([
        _record(userId: 'other-user'),
        _record(userId: 'user-1'),
      ]);
    final service = LabourAttendanceService(
      api: api,
    );

    final result = await service.getToday();

    expect(
        api.getEndpoints,
        containsAll([
          EndPoints.mobileLabourAttendanceToday,
          EndPoints.mobileLabourAttendance,
        ]));
    expect(api.getHeaders, {'x-branch-id': 'branch-1'});
    expect(result.status, 'Checked In');
    expect(result.attendance?.id, 'record-1');
    expect(result.employeeId, 'user-1');
  });

  test('GET reports no attendance today when own rows are for another date',
      () async {
    final api = FakeLabourAttendanceApi()
      ..getResponse = _success([
        _record(
          userId: 'user-1',
          date: '2026-10-22',
          outTime: '2026-10-22T17:30:00.000Z',
          hours: 8.25,
        ),
      ]);
    final result = await LabourAttendanceService(
      api: api,
    ).getToday();

    expect(result.status, 'Not Checked In');
    expect(result.attendance, isNull);
    expect(result.lastAttendance?.id, 'record-1');
    expect(result.lastAttendance?.outTime, isNotNull);
    expect(result.attendanceDate, DateTime(2026, 10, 23));
  });

  test('uses the organization date returned by the server', () async {
    final api = FakeLabourAttendanceApi()
      ..getResponse = _success([
        _record(
          userId: 'user-1',
          date: '2026-10-22',
          outTime: '2026-10-22T17:30:00.000Z',
        ),
      ])
      ..todayResponse = _success(
        _todayPayload(
          status: 'Completed',
          attendanceDate: '2026-10-22',
          attendance: _record(
            userId: 'user-1',
            date: '2026-10-22',
            outTime: '2026-10-22T17:30:00.000Z',
          ),
        ),
      );
    final result = await LabourAttendanceService(api: api).getToday();

    expect(result.attendanceDate, DateTime(2026, 10, 22));
    expect(result.status, 'Completed');
  });

  test('GET identifies a completed attendance record', () async {
    final api = FakeLabourAttendanceApi()
      ..getResponse = _success([
        _record(
          userId: 'user-1',
          outTime: '2026-10-23T17:30:00.000Z',
          hours: 8.25,
        ),
      ]);
    api.todayResponse = _success(
      _todayPayload(
        status: 'Completed',
        attendance: _record(
          userId: 'user-1',
          outTime: '2026-10-23T17:30:00.000Z',
          hours: 8.25,
        ),
      ),
    );
    final result = await LabourAttendanceService(
      api: api,
    ).getToday();

    expect(result.status, 'Completed');
    expect(result.attendance?.isWorking, isFalse);
    expect(result.attendance?.totalWorkingHours, 8.25);
  });

  test('does not hide an open record across a local-date boundary', () async {
    final api = FakeLabourAttendanceApi()
      ..getResponse = _success([
        _record(userId: 'user-1', date: '2026-10-22'),
      ]);
    final result = await LabourAttendanceService(api: api).getToday();

    expect(result.status, 'Checked In');
    expect(result.attendance?.attendanceDate, DateTime(2026, 10, 22));
  });

  test('GET rejects duplicate current-user rows instead of choosing one',
      () async {
    final api = FakeLabourAttendanceApi()
      ..getResponse = _success([
        _record(userId: 'user-1'),
        _record(userId: 'user-1', id: 'record-2'),
      ]);
    await expectLater(
      LabourAttendanceService(api: api).getToday(),
      throwsA(
        isA<LabourAttendanceException>().having(
          (error) => error.message,
          'message',
          contains('Multiple open attendance records'),
        ),
      ),
    );
  });

  test('Check-In uses dedicated API with server-verified geofence config',
      () async {
    final api = FakeLabourAttendanceApi()
      ..postResponse = _success(_record(userId: 'user-1'));
    final result = await LabourAttendanceService(
      api: api,
    ).checkIn();

    expect(api.postEndpoint, EndPoints.mobileLabourAttendanceCheckIn);
    expect(api.postHeaders, {'x-branch-id': 'branch-1'});
    expect(api.postBody, isEmpty);
    expect(result.attendance.id, 'record-1');
  });

  test('Check-In sends current GPS when server requires a branch geofence',
      () async {
    final api = FakeLabourAttendanceApi()
      ..postResponse = _success(_record(userId: 'user-1'))
      ..todayResponse = _success(_todayPayload(
        branchGeofence: {
          'enabled': true,
          'latitude': 12.5,
          'longitude': 77.5,
          'radius_meters': 100,
        },
      ));
    final location = FakeAttendanceLocationProvider(
      AttendanceLocationFix(
        latitude: 12.5,
        longitude: 77.5,
        accuracyMeters: 4,
        capturedAt: DateTime.now().toUtc(),
      ),
    );
    await LabourAttendanceService(
      api: api,
      locationProvider: location,
    ).checkIn();

    expect(location.calls, 1);
    expect(api.postBody?['latitude'], 12.5);
    expect(api.postBody?['longitude'], 77.5);
    expect(api.postBody?['accuracy_meters'], 4);
    expect(api.postBody?['captured_at'], isA<String>());
  });

  test('Check-Out PATCHes the record with captured GPS when enabled', () async {
    final api = FakeLabourAttendanceApi()
      ..patchResponse = _success(
        _record(
          userId: 'user-1',
          outTime: '2026-10-23T17:30:00.000Z',
          hours: 8.25,
        ),
      );
    api.todayResponse = _success(_todayPayload(
      branchGeofence: {
        'enabled': true,
        'latitude': 12.5,
        'longitude': 77.5,
        'radius_meters': 150,
      },
    ));
    final location = FakeAttendanceLocationProvider(
      AttendanceLocationFix(
        latitude: 12.5,
        longitude: 77.5,
        accuracyMeters: 5,
        capturedAt: DateTime.utc(2026, 10, 23, 12),
      ),
    );
    final result = await LabourAttendanceService(
      api: api,
      locationProvider: location,
    ).checkOut(attendanceId: 'record-1', branchId: 'branch-1');

    expect(
      api.patchEndpoint,
      EndPoints.mobileLabourAttendanceCheckOut('record-1'),
    );
    expect(api.patchHeaders, isEmpty);
    expect(api.patchBody, {
      'latitude': 12.5,
      'longitude': 77.5,
      'accuracy_meters': 5.0,
      'captured_at': '2026-10-23T12:00:00.000Z',
    });
    expect(result.attendance.outTime, isNotNull);
    expect(result.attendance.totalWorkingHours, 8.25);
  });

  test('missing assigned branch blocks requests', () async {
    await SharedPrefsHelper.remove(SharedPrefsHelper.selectedBranchId);
    final api = FakeLabourAttendanceApi();
    await expectLater(
      LabourAttendanceService(api: api).getToday(),
      throwsA(isA<LabourAttendanceException>()),
    );
    expect(api.getEndpoint, isNull);
  });

  test('missing mobile permission blocks requests', () async {
    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: true,
        mobileAppLabourAttendance: false,
      ),
    );
    final api = FakeLabourAttendanceApi();
    await expectLater(
      LabourAttendanceService(api: api).getToday(),
      throwsA(
        isA<LabourAttendanceException>()
            .having((error) => error.statusCode, 'statusCode', 403),
      ),
    );
    expect(api.getEndpoint, isNull);
  });

  test('explains when the today endpoint is missing from the backend',
      () async {
    final api = FakeLabourAttendanceApi()
      ..todayResponse = _response(
        status: 404,
        data: {'error': 'Not found'},
      );
    await expectLater(
      LabourAttendanceService(api: api).getToday(),
      throwsA(
        isA<LabourAttendanceException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having(
              (error) => error.message,
              'message',
              contains('attendance API on this server is outdated'),
            ),
      ),
    );
    expect(api.getEndpoints, [EndPoints.mobileLabourAttendanceToday]);
  });

  test('parses other backend errors and preserves HTTP status', () async {
    final api = FakeLabourAttendanceApi()
      ..getResponse = _response(
        status: 404,
        data: {'error': 'Not found'},
      );
    await expectLater(
      LabourAttendanceService(api: api).getToday(),
      throwsA(
        isA<LabourAttendanceException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having((error) => error.message, 'message', contains('Not found')),
      ),
    );
  });

  test('handles 401 and 403 distinctly', () async {
    for (final status in [401, 403]) {
      final api = FakeLabourAttendanceApi()
        ..getResponse = _response(
          status: status,
          data: {'message': 'denied'},
        );
      await expectLater(
        LabourAttendanceService(api: api).getToday(),
        throwsA(
          isA<LabourAttendanceException>()
              .having((error) => error.statusCode, 'statusCode', status),
        ),
      );
    }
  });

  test('handles duplicate check-in conflict', () async {
    final api = FakeLabourAttendanceApi()
      ..postResponse = _response(
        status: 409,
        data: {'message': 'Attendance already exists'},
      );
    await expectLater(
      LabourAttendanceService(api: api).checkIn(),
      throwsA(
        isA<LabourAttendanceException>()
            .having((error) => error.statusCode, 'statusCode', 409),
      ),
    );
  });

  test('explains the required COPPER Web labour link', () async {
    final api = FakeLabourAttendanceApi()
      ..todayResponse = _response(
        status: 409,
        data: {
          'message':
              'This mobile user is not linked to an active labour master record',
          'details': {'code': 'LABOUR_LINK_REQUIRED'},
        },
      );

    await expectLater(
      LabourAttendanceService(api: api).getToday(),
      throwsA(
        isA<LabourAttendanceException>()
            .having((error) => error.statusCode, 'statusCode', 409)
            .having(
              (error) => error.message,
              'message',
              contains('link it in User Master'),
            ),
      ),
    );
  });

  test('reads the labour-link code from a nested API error object', () async {
    final api = FakeLabourAttendanceApi()
      ..todayResponse = _response(
        status: 409,
        data: {
          'error': {
            'code': 'LABOUR_LINK_REQUIRED',
            'message':
                'This mobile user is not linked to an active labour master record',
          },
        },
      );

    await expectLater(
      LabourAttendanceService(api: api).getToday(),
      throwsA(
        isA<LabourAttendanceException>().having(
          (error) => error.message,
          'message',
          contains('link it in User Master'),
        ),
      ),
    );
  });

  test('rejects a successful response for a different authenticated user',
      () async {
    final api = FakeLabourAttendanceApi()
      ..postResponse = _success(_record(userId: 'different-user'));
    await expectLater(
      LabourAttendanceService(api: api).checkIn(),
      throwsA(isA<LabourAttendanceException>()),
    );
  });

  test('shows a safe connectivity message when there is no response', () async {
    final api = FakeLabourAttendanceApi();
    await expectLater(
      LabourAttendanceService(api: api).getToday(),
      throwsA(
        isA<LabourAttendanceException>().having(
          (error) => error.message,
          'message',
          contains('Unable to reach'),
        ),
      ),
    );
  });

  test('maps server failures to an explicit status-bearing error', () async {
    final api = FakeLabourAttendanceApi()
      ..getResponse = _response(
        status: 500,
        data: {'message': 'Attendance service failed'},
      );
    await expectLater(
      LabourAttendanceService(api: api).getToday(),
      throwsA(
        isA<LabourAttendanceException>()
            .having((error) => error.statusCode, 'statusCode', 500)
            .having(
              (error) => error.message,
              'message',
              contains('Attendance service failed'),
            ),
      ),
    );
  });
}

Map<String, dynamic> _record({
  required String userId,
  String id = 'record-1',
  String date = '2026-10-23',
  String? outTime,
  double hours = 0,
}) =>
    {
      'id': id,
      'labour_name': 'Authenticated User',
      'user_id': userId,
      'attendance_date': date,
      'in_time': '2026-10-23T09:15:00.000Z',
      'out_time': outTime,
      'total_working_hours': hours,
      'organization_id': 'org-1',
      'branch_id': 'branch-1',
    };

Map<String, dynamic> _todayPayload({
  String status = 'Not Checked In',
  String attendanceDate = '2026-10-23',
  Map<String, dynamic>? attendance,
  Map<String, dynamic>? branchGeofence,
}) =>
    {
      'attendance': attendance,
      'status': status,
      'employee': {
        'id': 'user-1',
        'full_name': 'Authenticated User',
      },
      'organization_id': 'org-1',
      'branch_id': 'branch-1',
      'attendance_date': attendanceDate,
      'server_timestamp': '2026-10-23T12:00:00.000Z',
      'branch_geofence': branchGeofence ??
          {
            'enabled': false,
            'latitude': null,
            'longitude': null,
            'radius_meters': 100,
          },
    };

Response<dynamic> _success(dynamic data) => _response(
      status: 200,
      data: {'success': true, 'data': data},
    );

Response<dynamic> _response({
  required int status,
  required dynamic data,
}) =>
    Response<dynamic>(
      requestOptions: RequestOptions(path: '/mobile/labour-attendance'),
      statusCode: status,
      data: data,
      headers: Headers.fromMap({
        'x-request-id': ['request-1']
      }),
    );

class FakeLabourAttendanceApi implements LabourAttendanceApi {
  Response<dynamic>? getResponse;
  Response<dynamic>? todayResponse;
  Response<dynamic>? postResponse;
  Response<dynamic>? patchResponse;
  String? getEndpoint;
  final List<String> getEndpoints = [];
  String? postEndpoint;
  String? patchEndpoint;
  Map<String, String>? getHeaders;
  Map<String, String>? postHeaders;
  Map<String, String>? patchHeaders;
  Map<String, dynamic>? postBody;
  Map<String, dynamic>? patchBody;

  @override
  Future<Response<dynamic>?> get(
    String endpoint, {
    required Map<String, String> headers,
    required String diagnosticLabel,
  }) async {
    getEndpoint = endpoint;
    getHeaders = headers;
    getEndpoints.add(endpoint);
    if (endpoint == EndPoints.mobileLabourAttendanceToday) {
      return todayResponse ?? _success(_todayPayload());
    }
    return getResponse;
  }

  @override
  Future<Response<dynamic>?> post(
    String endpoint,
    Map<String, dynamic> body, {
    required Map<String, String> headers,
    required String diagnosticLabel,
  }) async {
    postEndpoint = endpoint;
    postHeaders = headers;
    postBody = body;
    return postResponse;
  }

  @override
  Future<Response<dynamic>?> patch(
    String endpoint, {
    required Map<String, dynamic> body,
    required Map<String, String> headers,
    required String diagnosticLabel,
  }) async {
    patchEndpoint = endpoint;
    patchHeaders = headers;
    patchBody = body;
    return patchResponse;
  }
}

class FakeAttendanceLocationProvider implements AttendanceLocationProvider {
  FakeAttendanceLocationProvider(this.fix);

  final AttendanceLocationFix fix;
  int calls = 0;

  @override
  Future<AttendanceLocationFix> getCurrentFix() async {
    calls++;
    return fix;
  }
}
