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

  double get displayedWorkingHours {
    if (totalWorkingHours > 0 || outTime == null) return totalWorkingHours;
    final elapsed = outTime!.difference(inTime).inSeconds / 3600;
    return elapsed > 0 ? elapsed : totalWorkingHours;
  }

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
      totalWorkingHours: _requiredDouble(json, 'total_working_hours'),
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

  static double _requiredDouble(Map<String, dynamic> json, String key) {
    final value = double.tryParse(json[key]?.toString() ?? '');
    if (value == null || !value.isFinite) {
      throw FormatException('Attendance response contains invalid $key');
    }
    return value;
  }
}

class AttendanceGeofence {
  const AttendanceGeofence({
    required this.enabled,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final bool enabled;
  final double? latitude;
  final double? longitude;
  final int radiusMeters;

  factory AttendanceGeofence.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final radius = int.tryParse(json['radius_meters']?.toString() ?? '');
    final latitude = _optionalDouble(json['latitude']);
    final longitude = _optionalDouble(json['longitude']);
    if (enabled is! bool ||
        radius == null ||
        radius < 10 ||
        radius > 5000 ||
        (latitude == null) != (longitude == null) ||
        (enabled && (latitude == null || longitude == null))) {
      throw const FormatException(
        'Attendance response contains an invalid branch geofence',
      );
    }
    return AttendanceGeofence(
      enabled: enabled,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radius,
    );
  }

  static double? _optionalDouble(dynamic value) {
    if (value == null) return null;
    final parsed = double.tryParse(value.toString());
    if (parsed == null || !parsed.isFinite) {
      throw const FormatException(
        'Attendance response contains invalid geofence coordinates',
      );
    }
    return parsed;
  }
}

class LabourAttendanceToday {
  const LabourAttendanceToday({
    required this.attendance,
    required this.status,
    required this.employeeId,
    required this.employeeName,
    required this.organizationId,
    required this.branchId,
    required this.attendanceDate,
    required this.serverTimestamp,
    this.lastAttendance,
    this.branchGeofence,
  });

  final LabourAttendanceRecord? attendance;
  final LabourAttendanceRecord? lastAttendance;
  final String status;
  final String employeeId;
  final String employeeName;
  final String organizationId;
  final String branchId;
  final DateTime attendanceDate;
  final DateTime serverTimestamp;
  final AttendanceGeofence? branchGeofence;

  factory LabourAttendanceToday.fromJson(Map<String, dynamic> json) {
    final employee = _asMap(json['employee']);
    final attendance = json['attendance'];
    final branchGeofence = json['branch_geofence'];
    final status = _requiredString(json, 'status');
    if (!const {'Not Checked In', 'Checked In', 'Completed'}.contains(status)) {
      throw const FormatException(
          'Attendance response contains an invalid status');
    }
    if (branchGeofence == null) {
      throw const FormatException(
        'Attendance response is missing branch geofence settings',
      );
    }
    final parsedAttendance = attendance == null
        ? null
        : LabourAttendanceRecord.fromJson(_asMap(attendance));
    final employeeId = _requiredString(employee, 'id');
    final organizationId = _requiredString(json, 'organization_id');
    final branchId = _requiredString(json, 'branch_id');
    if (parsedAttendance != null &&
        (parsedAttendance.userId != employeeId ||
            parsedAttendance.organizationId != organizationId ||
            parsedAttendance.branchId != branchId)) {
      throw const FormatException(
        'Attendance response contains a record outside the authenticated scope',
      );
    }
    return LabourAttendanceToday(
      attendance: parsedAttendance,
      status: status,
      employeeId: employeeId,
      employeeName: _requiredString(employee, 'full_name'),
      organizationId: organizationId,
      branchId: branchId,
      attendanceDate: DateTime.parse(
        _requiredString(json, 'attendance_date'),
      ),
      serverTimestamp: DateTime.parse(
        _requiredString(json, 'server_timestamp'),
      ).toLocal(),
      branchGeofence: AttendanceGeofence.fromJson(_asMap(branchGeofence)),
    );
  }

  LabourAttendanceToday withHistory(
    List<LabourAttendanceRecord> records,
  ) {
    final scopedRecords = records
        .where((record) =>
            record.userId == employeeId &&
            record.organizationId == organizationId &&
            record.branchId == branchId)
        .toList(growable: false);
    final openRecords =
        scopedRecords.where((record) => record.isWorking).toList();
    if (openRecords.length > 1) {
      throw const FormatException(
        'Multiple open attendance records exist for this user',
      );
    }
    final currentAttendance =
        openRecords.isNotEmpty ? openRecords.single : attendance;
    final allRecords = [
      ...scopedRecords,
      if (currentAttendance != null &&
          !scopedRecords.any((record) => record.id == currentAttendance.id))
        currentAttendance,
    ]..sort(_compareAttendanceRecency);
    return LabourAttendanceToday(
      attendance: currentAttendance,
      lastAttendance: allRecords.isEmpty ? null : allRecords.last,
      status: currentAttendance?.isWorking == true
          ? 'Checked In'
          : currentAttendance == null
              ? status
              : currentAttendance.isWorking
                  ? 'Checked In'
                  : 'Completed',
      employeeId: employeeId,
      employeeName: employeeName,
      organizationId: organizationId,
      branchId: branchId,
      attendanceDate: attendanceDate,
      serverTimestamp: serverTimestamp,
      branchGeofence: branchGeofence,
    );
  }

  LabourAttendanceToday withAttendance(
    LabourAttendanceRecord record,
    DateTime serverTimestamp,
  ) {
    return LabourAttendanceToday(
      attendance: record,
      lastAttendance: record,
      status: record.outTime == null ? 'Checked In' : 'Completed',
      employeeId: employeeId,
      employeeName: employeeName,
      organizationId: organizationId,
      branchId: branchId,
      attendanceDate: record.attendanceDate,
      serverTimestamp: serverTimestamp,
      branchGeofence: branchGeofence,
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

  static int _compareAttendanceRecency(
    LabourAttendanceRecord left,
    LabourAttendanceRecord right,
  ) {
    final dateOrder = left.attendanceDate.compareTo(right.attendanceDate);
    return dateOrder != 0 ? dateOrder : left.inTime.compareTo(right.inTime);
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
    final record = json['attendance'] ?? json;
    final attendanceJson = _asMap(record);
    return LabourAttendanceActionResult(
      attendance: LabourAttendanceRecord.fromJson(attendanceJson),
      serverTimestamp: json['server_timestamp'] == null
          ? DateTime.parse(
              _requiredString(
                attendanceJson,
                attendanceJson['out_time'] == null ? 'in_time' : 'out_time',
              ),
            ).toLocal()
          : DateTime.parse(
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
