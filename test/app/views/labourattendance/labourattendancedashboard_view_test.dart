import 'dart:async';

import 'package:cocoper_mobile/app/controllers/labourattendance/labour_attendance_controller.dart';
import 'package:cocoper_mobile/app/helpers/shared_preferences.dart';
import 'package:cocoper_mobile/app/models/labour_attendance.dart';
import 'package:cocoper_mobile/app/services/labour_attendance_service.dart';
import 'package:cocoper_mobile/app/views/labourattendance/labourattendancedashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsHelper.init();
  });

  tearDown(Get.reset);

  testWidgets('initial state enables check-in and disables check-out',
      (tester) async {
    await _pumpAttendance(tester, FakeLabourAttendanceRepository());

    expect(find.text('Not Checked In'), findsOneWidget);
    expect(_checkInButton(tester).onPressed, isNotNull);
    expect(_checkOutButton(tester).onPressed, isNull);
  });

  testWidgets('check-in and check-out display only confirmed server state',
      (tester) async {
    final repository = FakeLabourAttendanceRepository();
    await _pumpAttendance(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, 'Check-In'));
    await tester.pumpAndSettle();

    expect(find.text('Checked In'), findsOneWidget);
    expect(find.text('9:05 AM'), findsOneWidget);
    expect(_checkInButton(tester).onPressed, isNull);
    expect(_checkOutButton(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Check-Out'));
    await tester.pumpAndSettle();

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('5:30 PM'), findsOneWidget);
    expect(_checkInButton(tester).onPressed, isNull);
    expect(_checkOutButton(tester).onPressed, isNull);
    expect(repository.checkInCalls, 1);
    expect(repository.checkOutCalls, 1);
  });

  testWidgets('disables repeated taps while a check-in is processing',
      (tester) async {
    final repository = FakeLabourAttendanceRepository()
      ..checkInCompleter = Completer<LabourAttendanceActionResult>();
    await _pumpAttendance(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, 'Check-In'));
    await tester.pump();
    expect(_checkInButton(tester).onPressed, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Check-In'));
    expect(repository.checkInCalls, 1);

    repository.checkInCompleter!.complete(repository.checkInResult);
    await tester.pumpAndSettle();
    expect(find.text('Checked In'), findsOneWidget);
  });

  testWidgets('shows retrieval errors without enabling punches',
      (tester) async {
    final repository = FakeLabourAttendanceRepository()
      ..loadError =
          const LabourAttendanceException('Permission denied', statusCode: 403);
    await _pumpAttendance(tester, repository);

    expect(find.text('Attendance unavailable'), findsOneWidget);
    expect(find.text('Permission denied'), findsOneWidget);
    expect(_checkInButton(tester).onPressed, isNull);
    expect(_checkOutButton(tester).onPressed, isNull);
    expect(
      find.text(
          "Punch actions stay disabled until today's status is verified."),
      findsOneWidget,
    );
  });

  testWidgets('refreshes attendance when the app resumes', (tester) async {
    final repository = FakeLabourAttendanceRepository();
    await _pumpAttendance(tester, repository);
    expect(repository.loadCalls, 1);

    Get.find<LabourAttendanceController>()
        .didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
  });

  testWidgets('disables punches when a resumed refresh cannot verify state',
      (tester) async {
    final repository = FakeLabourAttendanceRepository();
    await _pumpAttendance(tester, repository);
    await tester.tap(find.widgetWithText(FilledButton, 'Check-In'));
    await tester.pumpAndSettle();
    expect(_checkOutButton(tester).onPressed, isNotNull);

    repository.loadError =
        const LabourAttendanceException('Attendance service unavailable');
    Get.find<LabourAttendanceController>()
        .didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(_checkOutButton(tester).onPressed, isNull);
    expect(find.text('Attendance service unavailable'), findsOneWidget);
  });

  testWidgets('keeps the verified employee name and does not show username',
      (tester) async {
    await SharedPrefsHelper.setString(
      SharedPrefsHelper.fullName,
      'Verified Employee',
    );
    await SharedPrefsHelper.setString(
      SharedPrefsHelper.username,
      'unverified-login-name',
    );
    await _pumpAttendance(tester, FakeLabourAttendanceRepository());

    expect(find.text('Hello, Verified Employee'), findsOneWidget);
    expect(find.text('unverified-login-name'), findsNothing);
  });
}

Future<void> _pumpAttendance(
  WidgetTester tester,
  LabourAttendanceRepository repository,
) async {
  Get.put(
    LabourAttendanceController(repository: repository),
  );
  await tester.pumpWidget(
    const GetMaterialApp(home: LabourAttendanceDashboardView()),
  );
  await tester.pumpAndSettle();
}

FilledButton _checkInButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Check-In'));

OutlinedButton _checkOutButton(WidgetTester tester) => tester
    .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Check-Out'));

class FakeLabourAttendanceRepository implements LabourAttendanceRepository {
  FakeLabourAttendanceRepository()
      : _today = LabourAttendanceToday(
          attendance: null,
          status: 'Not Checked In',
          employeeId: 'user-1',
          employeeName: 'Verified Employee',
          organizationId: 'org-1',
          branchId: 'branch-1',
          attendanceDate: DateTime(2025, 4, 3),
          serverTimestamp: DateTime(2025, 4, 3, 8),
        );

  LabourAttendanceToday _today;
  LabourAttendanceException? loadError;
  Completer<LabourAttendanceActionResult>? checkInCompleter;
  int checkInCalls = 0;
  int checkOutCalls = 0;
  int loadCalls = 0;

  final checkInResult = LabourAttendanceActionResult(
    attendance: LabourAttendanceRecord(
      id: 'attendance-1',
      labourName: 'Verified Employee',
      userId: 'user-1',
      attendanceDate: DateTime(2025, 4, 3),
      inTime: DateTime(2025, 4, 3, 9, 5),
      outTime: null,
      totalWorkingHours: 0,
      organizationId: 'org-1',
      branchId: 'branch-1',
    ),
    serverTimestamp: DateTime(2025, 4, 3, 9, 5),
  );

  final checkOutResult = LabourAttendanceActionResult(
    attendance: LabourAttendanceRecord(
      id: 'attendance-1',
      labourName: 'Verified Employee',
      userId: 'user-1',
      attendanceDate: DateTime(2025, 4, 3),
      inTime: DateTime(2025, 4, 3, 9, 5),
      outTime: DateTime(2025, 4, 3, 17, 30),
      totalWorkingHours: 8.42,
      organizationId: 'org-1',
      branchId: 'branch-1',
    ),
    serverTimestamp: DateTime(2025, 4, 3, 17, 30),
  );

  @override
  Future<LabourAttendanceToday> getToday() async {
    loadCalls++;
    if (loadError != null) throw loadError!;
    return _today;
  }

  @override
  Future<LabourAttendanceActionResult> checkIn() async {
    checkInCalls++;
    final result = checkInCompleter == null
        ? checkInResult
        : await checkInCompleter!.future;
    _today = _today.withAttendance(result.attendance, result.serverTimestamp);
    return result;
  }

  @override
  Future<LabourAttendanceActionResult> checkOut(
      {required String branchId}) async {
    checkOutCalls++;
    _today = _today.withAttendance(
      checkOutResult.attendance,
      checkOutResult.serverTimestamp,
    );
    return checkOutResult;
  }
}
