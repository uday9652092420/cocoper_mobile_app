import 'dart:convert';
import 'dart:typed_data';

/// Customer Receipt fields documented by the mobile API contract.
class CustomerReceipt {
  final String id;
  final String receiptNumber;
  final String date;
  final String customerId;
  final String invoiceMode;
  final String invoiceNumber;
  final String paymentMode;
  final String remarks;
  final String status;
  final double amount;
  final String? attachmentNamesJson;
  final String? attachmentFilesJson;
  final bool hasAttachmentFields;

  const CustomerReceipt({
    this.id = '',
    this.receiptNumber = '',
    this.date = '',
    this.customerId = '',
    this.invoiceMode = '',
    this.invoiceNumber = '',
    this.paymentMode = '',
    this.remarks = '',
    this.status = '',
    this.amount = 0,
    this.attachmentNamesJson,
    this.attachmentFilesJson,
    this.hasAttachmentFields = false,
  });

  factory CustomerReceipt.fromJson(
    Map<String, dynamic> json, {
    String? fallbackId,
  }) {
    final attachmentNames =
        json['attachment_names'] ?? json['attachmentNames'];
    final attachmentFiles =
        json['attachment_files'] ?? json['attachmentFiles'];
    return CustomerReceipt(
      id: _string(json['id'] ?? json['_id'] ?? fallbackId),
      receiptNumber: _string(json['receipt_no']),
      date: _string(json['receipt_date']),
      customerId: _string(json['customer_id']),
      invoiceMode: _string(json['invoice_mode']),
      invoiceNumber: _string(json['invoice_no']),
      paymentMode: _string(json['payment_mode']),
      remarks: _string(json['remarks']),
      status: _receiptStatus(json),
      amount: _double(json['amount']),
        attachmentNamesJson: _attachmentArrayJson(attachmentNames),
        attachmentFilesJson: _attachmentArrayJson(attachmentFiles),
        hasAttachmentFields:
          (json.containsKey('attachment_names') ||
            json.containsKey('attachmentNames')) &&
          (json.containsKey('attachment_files') ||
            json.containsKey('attachmentFiles')),
    );
  }

  Map<String, dynamic> toRequestJson({
    required String organizationId,
    String? attachmentNamesJson,
    String? attachmentFilesJson,
  }) =>
      <String, dynamic>{
        'receipt_no': receiptNumber,
        'customer_id': customerId,
        'receipt_date': date,
        'invoice_mode': invoiceMode,
        'invoice_no': invoiceNumber.isEmpty ? null : invoiceNumber,
        'amount': amount == amount.roundToDouble() ? amount.toInt() : amount,
        'payment_mode': paymentMode,
        'remarks': remarks,
        'attachment_names': attachmentNamesJson ?? this.attachmentNamesJson,
        'attachment_files': attachmentFilesJson ?? this.attachmentFilesJson,
        'organization_id': organizationId,
      };

  static String _receiptStatus(Map<String, dynamic> json) {
    final approved = _nullableBool(json['approved']);
    if (approved == true) return 'Approved';
    final status = _string(json['status']);
    if (status.isNotEmpty) return status;
    if (approved == false) return 'Draft';
    return '';
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static String? _attachmentArrayJson(dynamic value) {
    if (value == null) return null;
    if (value is List) return jsonEncode(value);
    final text = value.toString().trim();
    if (text.isEmpty) return text;
    try {
      final decoded = jsonDecode(text);
      return decoded is List ? jsonEncode(decoded) : text;
    } on FormatException {
      return text;
    }
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool? _nullableBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
    }
    switch (value?.toString().trim().toLowerCase()) {
      case 'true':
      case '1':
        return true;
      case 'false':
      case '0':
        return false;
      default:
        return null;
    }
  }
}

class CustomerReceiptAttachment {
  final String name;
  final Uint8List bytes;

  const CustomerReceiptAttachment({
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

  static String? attachmentNamesFromJson(String? value) =>
      _decodeArray(value)?.map((item) => item.toString()).join(', ');

  static List<CustomerReceiptAttachment> attachmentsFromJson({
    required String? namesJson,
    required String? filesJson,
  }) {
    final names = _decodeArray(namesJson);
    final files = _decodeArray(filesJson);
    if (names == null || files == null || names.length != files.length) {
      return const [];
    }

    final attachments = <CustomerReceiptAttachment>[];
    for (var index = 0; index < names.length; index++) {
      final name = names[index].toString().trim();
      final dataUrl = files[index].toString().trim();
      final comma = dataUrl.indexOf(',');
      final expectedMime = mimeTypeForName(name);
      if (name.isEmpty ||
          expectedMime == null ||
          !dataUrl.startsWith('data:') ||
          comma < 0 ||
          dataUrl.substring(5, comma).split(';').first.toLowerCase() !=
              expectedMime) {
        continue;
      }
      try {
        final bytes = base64Decode(dataUrl.substring(comma + 1));
        if (bytes.isNotEmpty) {
          attachments.add(CustomerReceiptAttachment(name: name, bytes: bytes));
        }
      } on FormatException {
        continue;
      }
    }
    return attachments;
  }

  static List<dynamic>? _decodeArray(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is List ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
