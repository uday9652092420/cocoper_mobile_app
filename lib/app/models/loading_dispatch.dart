class LoadingDispatch {
  final String id;
  final String dispatchNumber;
  final String customerId;
  final String lorryNumber;
  final String driverName;
  final String driverMobile;
  final String dispatchDate;
  final String dispatchStatus;
  final bool invoiceGenerated;
  final List<LoadingDispatchLine> lines;

  const LoadingDispatch({
    this.id = '',
    this.dispatchNumber = '',
    this.customerId = '',
    this.lorryNumber = '',
    this.driverName = '',
    this.driverMobile = '',
    this.dispatchDate = '',
    this.dispatchStatus = 'Draft',
    this.invoiceGenerated = false,
    this.lines = const [],
  });

  factory LoadingDispatch.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return LoadingDispatch(
      id: _text(json['id']),
      dispatchNumber: _text(json['dispatchNumber']),
      customerId: _text(json['customerId']),
      lorryNumber: _text(json['lorryNumber']),
      driverName: _text(json['driverName']),
      driverMobile: _text(json['driverMobile']),
      dispatchDate: _date(json['dispatchDate']),
      dispatchStatus: _text(json['dispatchStatus']).isEmpty
          ? 'Draft'
          : _text(json['dispatchStatus']),
      invoiceGenerated: _bool(json['invoiceGenerated']),
      lines: rawLines is List
          ? rawLines
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (row) => LoadingDispatchLine.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toRequestJson() => <String, dynamic>{
        if (id.isNotEmpty) 'id': id,
        'dispatchNumber': dispatchNumber.trim(),
        'customerId': customerId,
        'lorryNumber': lorryNumber.trim(),
        'driverName': driverName.trim(),
        'driverMobile': driverMobile.trim(),
        'dispatchStatus': dispatchStatus,
        if (dispatchDate.isNotEmpty) 'dispatchDate': dispatchDate,
        'invoiceGenerated': invoiceGenerated,
        'lines': lines.map((line) => line.toRequestJson()).toList(),
      };

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  static String _date(dynamic value) {
    final text = _text(value);
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }
}

class LoadingDispatchLine {
  final String id;
  final String branchId;
  final String date;
  final String itemId;
  final String bharthi;
  final double quantity;
  final double loadedQuantity;
  final double pendingQuantity;

  const LoadingDispatchLine({
    this.id = '',
    this.branchId = '',
    this.date = '',
    this.itemId = '',
    this.bharthi = '',
    this.quantity = 0,
    this.loadedQuantity = 0,
    this.pendingQuantity = 0,
  });

  factory LoadingDispatchLine.fromJson(Map<String, dynamic> json) =>
      LoadingDispatchLine(
        id: _text(json['id']),
        branchId: _text(json['branchId']),
        date: _date(json['date']),
        itemId: _text(json['itemId']),
        bharthi: _text(json['bharthi']),
        quantity: _number(json['quantity']),
        loadedQuantity: _number(json['loadedQuantity']),
        pendingQuantity: _number(json['pendingQuantity']),
      );

  Map<String, dynamic> toRequestJson() => <String, dynamic>{
        if (id.isNotEmpty) 'id': id,
        'branchId': branchId,
        'date': date,
        'itemId': itemId,
        'bharthi': bharthi.trim(),
        'quantity': quantity,
        'loadedQuantity': loadedQuantity,
        'pendingQuantity': pendingQuantity,
      };

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _date(dynamic value) {
    final text = _text(value);
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }
}
