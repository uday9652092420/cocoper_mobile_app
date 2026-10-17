class CashBankExpense {
  final String id;
  final String organizationId;
  final String branchId;
  final String branch;
  final String date;
  final String paymentMode;
  final String transactionType;
  final double amount;
  final String description;
  final List<CashBankExpenseAttachment> attachments;
  final bool hasAttachmentField;
  final bool hasValidAttachmentData;
  final bool approved;
  final String createdAt;

  const CashBankExpense({
    this.id = '',
    this.organizationId = '',
    this.branchId = '',
    this.branch = '',
    this.date = '',
    this.paymentMode = '',
    this.transactionType = '',
    this.amount = 0,
    this.description = '',
    this.attachments = const [],
    this.hasAttachmentField = false,
    this.hasValidAttachmentData = false,
    this.approved = false,
    this.createdAt = '',
  });

  factory CashBankExpense.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'];
    final validAttachments = rawAttachments is List &&
        rawAttachments.every((item) {
          if (item is! Map) return false;
          final attachment = Map<String, dynamic>.from(item);
          return attachment['name'] is String &&
              (attachment['name'] as String).isNotEmpty &&
              const {
                'image/png',
                'image/jpeg',
                'application/pdf',
              }.contains(attachment['mimeType']) &&
              attachment['data'] is String &&
              (attachment['data'] as String).startsWith('data:');
        });
    return CashBankExpense(
      id: _text(json['id']),
      organizationId: _text(json['organizationId']),
      branchId: _text(json['branchId']),
      branch: _text(json['branch']),
      date: _date(json['date']),
      paymentMode: _text(json['paymentMode']),
      transactionType: _text(json['transactionType']),
      amount: _number(json['amount']),
      description: _text(json['description']),
      attachments: rawAttachments is List
          ? rawAttachments
              .whereType<Map<dynamic, dynamic>>()
              .map((item) => CashBankExpenseAttachment.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const [],
      hasAttachmentField: json.containsKey('attachments'),
      hasValidAttachmentData: validAttachments,
      approved: _bool(json['approved']),
      createdAt: _text(json['createdAt']),
    );
  }

  Map<String, dynamic> toRequestJson() => <String, dynamic>{
        'branchId': branchId,
        'date': date,
        'paymentMode': paymentMode,
        'transactionType': transactionType,
        'amount': amount,
        'description': description,
        'attachments': attachments.map((item) => item.toJson()).toList(),
      };

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().trim().toLowerCase() == 'true';
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

class CashBankBranch {
  final String id;
  final String organizationId;
  final String name;
  final String status;

  const CashBankBranch({
    required this.id,
    required this.organizationId,
    required this.name,
    this.status = '',
  });

  factory CashBankBranch.fromJson(Map<String, dynamic> json) =>
      CashBankBranch(
        id: json['id']?.toString().trim() ?? '',
        organizationId:
            json['organization_id']?.toString().trim() ??
                json['organizationId']?.toString().trim() ??
                '',
        name: json['branch_name']?.toString().trim() ??
            json['branchName']?.toString().trim() ??
            '',
        status: json['status']?.toString().trim() ?? '',
      );
}

class CashBankExpenseAttachment {
  final String name;
  final String mimeType;
  final String data;

  const CashBankExpenseAttachment({
    required this.name,
    required this.mimeType,
    required this.data,
  });

  factory CashBankExpenseAttachment.fromJson(Map<String, dynamic> json) =>
      CashBankExpenseAttachment(
        name: json['name']?.toString() ?? '',
        mimeType: json['mimeType']?.toString() ?? '',
        data: json['data']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'mimeType': mimeType,
        'data': data,
      };
}
