class BagPurchase {
  final String id;
  final String purchaseNumber;
  final String purchaseDate;
  final String supplierId;
  final String supplierName;
  final String supplierCode;
  final String branchId;
  final String branchName;
  final String remarks;
  final String organizationId;
  final double totalAmount;
  final int lineCount;
  final List<BagPurchaseLine> lines;

  const BagPurchase({
    this.id = '',
    this.purchaseNumber = '',
    this.purchaseDate = '',
    this.supplierId = '',
    this.supplierName = '',
    this.supplierCode = '',
    this.branchId = '',
    this.branchName = '',
    this.remarks = '',
    this.organizationId = '',
    this.totalAmount = 0,
    this.lineCount = 0,
    this.lines = const [],
  });

  factory BagPurchase.fromJson(Map<String, dynamic> json) {
    final supplier = _map(json['supplier']);
    final branch = _map(json['branch']);
    final rawDate = _text(json['purchase_date'] ?? json['purchaseDate']);
    final purchaseDate = parsePurchaseDate(rawDate);
    final rawLines = json['lines'];
    final lines = rawLines is List
        ? rawLines
            .whereType<Map<dynamic, dynamic>>()
            .map((line) => BagPurchaseLine.fromJson(
                  Map<String, dynamic>.from(line),
                ))
            .toList(growable: false)
        : const <BagPurchaseLine>[];

    return BagPurchase(
      id: _text(json['id'] ?? json['_id']),
      purchaseNumber: _text(
        json['purchase_no'] ??
            json['purchaseNo'] ??
            json['purchase_number'] ??
            json['purchaseNumber'],
      ),
      purchaseDate: purchaseDate == null ? rawDate : _dateOnly(purchaseDate),
      supplierId: _text(
        json['supplier_id'] ?? json['supplierId'] ?? supplier['id'],
      ),
      supplierName: _text(
        json['supplier_name'] ??
            json['supplierName'] ??
            supplier['supplier_name'] ??
            supplier['name'],
      ),
      supplierCode: _text(
        json['supplier_code'] ??
            json['supplierCode'] ??
            supplier['supplier_code'] ??
            supplier['code'],
      ),
      branchId: _text(json['branch_id'] ?? json['branchId'] ?? branch['id']),
      branchName: _text(
        json['branch_name'] ??
            json['branchName'] ??
            branch['branch_name'] ??
            branch['name'],
      ),
      remarks: _text(json['remarks']),
      organizationId: _text(
        json['organization_id'] ?? json['organizationId'],
      ),
      totalAmount: parseNumber(
        json['total_amount'] ??
            json['totalAmount'] ??
            json['grand_total'] ??
            json['grandTotal'],
        fallback: lines.fold<double>(0, (total, line) => total + line.amount),
      ),
      lineCount: _integer(
        json['line_count'] ?? json['lineCount'] ?? json['lines_count'],
        fallback: lines.length,
      ),
      lines: lines,
    );
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';

  /// Business calendar date of a backend `purchase_date` value.
  ///
  /// The backend keeps the date-only value at midnight in its own timezone
  /// (UTC+02:00 in summer, UTC+01:00 in winter) and serializes it as a UTC
  /// timestamp: `2026-10-14` is returned as `2026-10-13T22:00:00.000Z` and
  /// `2026-11-20` as `2026-11-19T23:00:00.000Z`. Reading the UTC day would show
  /// the day before the selected one, so a UTC instant is shifted into the
  /// backend timezone before the calendar date is taken. A date-only value is
  /// already the business date and is used unchanged.
  ///
  /// Returns null when [value] is not a recognised date.
  static DateTime? parsePurchaseDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return parsed.isUtc ? parsed.add(_backendDateOffset) : parsed;
    }

    final parts = text.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Offset added to a UTC `purchase_date` instant to read its calendar date.
  ///
  /// Covers the verified UTC+01:00/+02:00 backend serialization and stays
  /// correct if the backend starts returning UTC-midnight dates.
  static const Duration _backendDateOffset = Duration(hours: 2);

  static double parseNumber(Object? value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _integer(Object? value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<dynamic, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    return const {};
  }
}

class BagPurchaseLine {
  final String id;
  final String gunnyBagId;
  final String gunnyBagName;
  final double quantity;
  final double rate;
  final double amount;

  const BagPurchaseLine({
    this.id = '',
    this.gunnyBagId = '',
    this.gunnyBagName = '',
    this.quantity = 0,
    this.rate = 0,
    this.amount = 0,
  });

  factory BagPurchaseLine.fromJson(Map<String, dynamic> json) {
    final bag = BagPurchase._map(json['gunny_bag'] ?? json['gunnyBag']);
    final quantity = BagPurchase.parseNumber(json['quantity']);
    final rate = BagPurchase.parseNumber(json['rate']);
    return BagPurchaseLine(
      id: BagPurchase._text(json['id'] ?? json['_id']),
      gunnyBagId: BagPurchase._text(
        json['gunny_bag_id'] ??
            json['gunnyBagId'] ??
            json['bag_type_id'] ??
            json['bagTypeId'] ??
            json['bag_id'] ??
            json['bagId'] ??
            bag['id'] ??
            bag['_id'] ??
            bag['bag_type_id'] ??
            bag['bagTypeId'],
      ),
      gunnyBagName: BagPurchase._text(
        json['gunny_bag_name'] ??
            json['gunnyBagName'] ??
            json['bag_name'] ??
            json['bagName'] ??
            bag['bag_name'] ??
            bag['bagName'] ??
            bag['name'],
      ),
      quantity: quantity,
      rate: rate,
      amount: BagPurchase.parseNumber(
        json['amount'],
        fallback: quantity * rate,
      ),
    );
  }

  Map<String, dynamic> toRequestJson() => {
        'gunny_bag_id': gunnyBagId,
        'quantity': quantity,
        'rate': rate,
      };
}

class BagPurchaseLookup {
  final String id;
  final String name;
  final String code;
  final double ratePerBag;

  const BagPurchaseLookup({
    required this.id,
    required this.name,
    this.code = '',
    this.ratePerBag = 0,
  });

  String get label => code.isEmpty ? name : '$name ($code)';

  static List<BagPurchaseLookup>? decodeGunnyBagResponse(Object? response) {
    Object? value = response;
    for (var depth = 0; depth < 3; depth++) {
      if (value is List) break;
      if (value is! Map<dynamic, dynamic>) return null;
      value = value['data'] ?? value['items'] ?? value['records'];
      if (value == null) return null;
    }
    if (value is! List) return null;

    return value
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => BagPurchaseLookup.fromGunnyBagJson(
              Map<String, dynamic>.from(row),
            ))
        .where((bag) => bag.id.isNotEmpty && bag.name.isNotEmpty)
        .toList(growable: false);
  }

  factory BagPurchaseLookup.fromGunnyBagJson(Map<String, dynamic> json) {
    String firstText(Iterable<String> keys) {
      for (final key in keys) {
        final value = json[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return BagPurchaseLookup(
      id: firstText(const [
        'id',
        'ID',
        '_id',
        'bagTypeId',
        'bag_type_id',
        'bagId',
        'bag_id',
        'gunnyBagId',
        'gunny_bag_id',
      ]),
      name: firstText(const [
        'name',
        'bagName',
        'bag_name',
        'gunnyBagName',
        'gunny_bag_name',
        'label',
      ]),
      code: firstText(const [
        'bag_code',
        'bagCode',
        'gunny_bag_code',
        'gunnyBagCode',
        'code',
      ]),
      ratePerBag: BagPurchase.parseNumber(
        json['rate_per_bag'] ?? json['ratePerBag'],
      ),
    );
  }

  factory BagPurchaseLookup.fromJson(
    Map<String, dynamic> json, {
    required String nameKey,
    required String codeKey,
    String? alternateNameKey,
    String? alternateCodeKey,
  }) {
    return BagPurchaseLookup(
      id: BagPurchase._text(json['id'] ?? json['_id']),
      name: BagPurchase._text(json[nameKey] ?? json[alternateNameKey]),
      code: BagPurchase._text(json[codeKey] ?? json[alternateCodeKey]),
      ratePerBag: BagPurchase.parseNumber(
        json['rate_per_bag'] ?? json['ratePerBag'],
      ),
    );
  }
}
