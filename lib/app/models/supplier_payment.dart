import 'dart:convert';
import 'dart:typed_data';

class SupplierPayment {
  final String id;
  final String paymentNumber;
  final String supplierId;
  final String supplierName;
  final String date;
  final String invoiceMode;
  final String paymentMode;
  final double amount;
  final String purchaseInvoiceId;
  final String remarks;
  final String? attachmentNamesJson;
  final String? attachmentFilesJson;
  final bool hasAttachmentFields;
  final bool approved;
  final String organizationId;

  const SupplierPayment({
    this.id = '',
    this.paymentNumber = '',
    this.supplierId = '',
    this.supplierName = '',
    this.date = '',
    this.invoiceMode = '',
    this.paymentMode = '',
    this.amount = 0,
    this.purchaseInvoiceId = '',
    this.remarks = '',
    this.attachmentNamesJson,
    this.attachmentFilesJson,
    this.hasAttachmentFields = false,
    this.approved = false,
    this.organizationId = '',
  });

  bool get canSafelyPreserveAttachments {
    if (!hasAttachmentFields) return false;
    final names = attachmentNamesJson;
    final files = attachmentFilesJson;
    if (names == null && files == null) return true;
    if (names == null || files == null) return false;
    if (names.isEmpty && files.isEmpty) return true;
    final parsedNames = SupplierPaymentAttachment.decodeStringArray(names);
    final parsedFiles = SupplierPaymentAttachment.decodeStringArray(files);
    return parsedNames != null &&
        parsedFiles != null &&
        parsedNames.length == parsedFiles.length;
  }

  factory SupplierPayment.fromJson(Map<String, dynamic> json) {
    return SupplierPayment(
      id: _text(json['id']),
      paymentNumber: _text(json['paymentNumber']),
      supplierId: _text(json['supplierId']),
      supplierName: _text(json['supplierName']),
      date: _date(json['date']),
      invoiceMode: _text(json['invoiceMode']),
      paymentMode: _text(json['paymentMode']),
      amount: _number(json['amount']),
      purchaseInvoiceId: _text(json['purchaseInvoiceId']),
      remarks: _text(json['remarks']),
      attachmentNamesJson: json['attachmentNames']?.toString(),
      attachmentFilesJson: json['attachmentFiles']?.toString(),
      hasAttachmentFields: json.containsKey('attachmentNames') &&
          json.containsKey('attachmentFiles'),
      approved: _bool(json['approved']),
      organizationId: _text(json['organizationId']),
    );
  }

  Map<String, dynamic> toRequestJson({
    required String organizationId,
    String? attachmentNamesJson,
    String? attachmentFilesJson,
  }) =>
      <String, dynamic>{
        'paymentNumber': paymentNumber,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'date': date,
        'invoiceMode': invoiceMode,
        'paymentMode': paymentMode,
        'amount': amount,
        'purchaseInvoiceId':
            invoiceMode == 'Cumulative' || purchaseInvoiceId.isEmpty
                ? null
                : purchaseInvoiceId,
        'remarks': remarks,
        'attachmentNames': attachmentNamesJson ?? this.attachmentNamesJson,
        'attachmentFiles': attachmentFilesJson ?? this.attachmentFilesJson,
        'organizationId': organizationId,
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
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return '${parsed.year.toString().padLeft(4, '0')}-'
          '${parsed.month.toString().padLeft(2, '0')}-'
          '${parsed.day.toString().padLeft(2, '0')}';
    }
    final parts = text.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        final candidate = DateTime(year, month, day);
        if (candidate.year == year &&
            candidate.month == month &&
            candidate.day == day) {
          return '${year.toString().padLeft(4, '0')}-'
              '${month.toString().padLeft(2, '0')}-'
              '${day.toString().padLeft(2, '0')}';
        }
      }
    }
    return text;
  }
}

class SupplierPaymentAttachment {
  final String name;
  final Uint8List bytes;

  const SupplierPaymentAttachment({
    required this.name,
    required this.bytes,
  });

  String get dataUrl {
    final mimeType = mimeTypeForName(name);
    if (mimeType == null) {
      throw FormatException('Unsupported attachment type: $name');
    }
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  static String? mimeTypeForName(String name) {
    switch (name.split('.').last.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return null;
    }
  }

  static List<String>? decodeStringArray(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List || decoded.any((item) => item is! String)) {
        return null;
      }
      return decoded.cast<String>();
    } on FormatException {
      return null;
    }
  }
}
