class LabourAttendanceRecord {
  const LabourAttendanceRecord({
    required this.id,
    required this.labourName,
    required this.userId,
    required this.attendanceDate,
    required this.inTime,
    required this.outTime,
    required this.totalWorkingHours,
    required this.organizationId,
    required this.branchId,
  });

  final String id;
  final String labourName;
  final String userId;
  final DateTime attendanceDate;
  final DateTime inTime;
  final DateTime? outTime;
  final double totalWorkingHours;
  final String organizationId;
  final String branchId;

  bool get isWorking => outTime == null;

  factory LabourAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return LabourAttendanceRecord(
      id: _requiredString(json, 'id'),
      labourName: _requiredString(json, 'labour_name'),
      userId: _requiredString(json, 'user_id'),
      attendanceDate: DateTime.parse(_requiredString(json, 'attendance_date')),
      inTime: DateTime.parse(_requiredString(json, 'in_time')).toLocal(),
      outTime: json['out_time'] == null
          ? null
          : DateTime.parse(json['out_time'].toString()).toLocal(),
      totalWorkingHours:
          double.tryParse(json['total_working_hours'].toString()) ?? 0,
      organizationId: _requiredString(json, 'organization_id'),
      branchId: _requiredString(json, 'branch_id'),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty || value == 'null') {
      throw FormatException('Attendance response is missing $key');
    }
    return value;
  }
}

class LabourAttendanceToday {
  const LabourAttendanceToday({
    required this.attendance,
    required this.employeeId,
    required this.employeeName,
    required this.organizationId,
    required this.branchId,
    required this.attendanceDate,
    required this.serverTimestamp,
  });

  final LabourAttendanceRecord? attendance;
  final String employeeId;
  final String employeeName;
  final String organizationId;
  final String branchId;
  final DateTime attendanceDate;
  final DateTime serverTimestamp;

  factory LabourAttendanceToday.fromJson(Map<String, dynamic> json) {
    final employee = _asMap(json['employee']);
    final attendance = json['attendance'];
    return LabourAttendanceToday(
      attendance: attendance == null
          ? null
          : LabourAttendanceRecord.fromJson(_asMap(attendance)),
      employeeId: _requiredString(employee, 'id'),
      employeeName: _requiredString(employee, 'full_name'),
      organizationId: _requiredString(json, 'organization_id'),
      branchId: _requiredString(json, 'branch_id'),
      attendanceDate: DateTime.parse(
        _requiredString(json, 'attendance_date'),
      ),
      serverTimestamp: DateTime.parse(
        _requiredString(json, 'server_timestamp'),
      ).toLocal(),
    );
  }

  LabourAttendanceToday withAttendance(
    LabourAttendanceRecord record,
    DateTime serverTimestamp,
  ) {
    return LabourAttendanceToday(
      attendance: record,
      employeeId: employeeId,
      employeeName: employeeName,
      organizationId: organizationId,
      branchId: branchId,
      attendanceDate: record.attendanceDate,
      serverTimestamp: serverTimestamp,
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException(
        'Attendance response contains an invalid object');
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty || value == 'null') {
      throw FormatException('Attendance response is missing $key');
    }
    return value;
  }
}

class LabourAttendanceActionResult {
  const LabourAttendanceActionResult({
    required this.attendance,
    required this.serverTimestamp,
  });

  final LabourAttendanceRecord attendance;
  final DateTime serverTimestamp;

  factory LabourAttendanceActionResult.fromJson(Map<String, dynamic> json) {
    final attendance = json['attendance'];
    return LabourAttendanceActionResult(
      attendance: LabourAttendanceRecord.fromJson(_asMap(attendance)),
      serverTimestamp: DateTime.parse(
        _requiredString(json, 'server_timestamp'),
      ).toLocal(),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException(
        'Attendance response contains an invalid record');
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty || value == 'null') {
      throw FormatException('Attendance response is missing $key');
    }
    return value;
  }
}
