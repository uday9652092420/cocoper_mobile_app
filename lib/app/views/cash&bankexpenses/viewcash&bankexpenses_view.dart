// ignore_for_file: file_names

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../controllers/cash&bankexpenses/cash_bank_expenses_controller.dart';
import '../../models/cash_bank_expense_model.dart';
import '../../theme/app_theme.dart';

const _ink = AppColors.textDefaultLight;
const _muted = AppColors.textLightGrayLight;
const _line = AppColors.borderLightGrayLight;
const _green = AppColors.primaryLight;

class ViewCashBankExpenseView extends StatefulWidget {
  const ViewCashBankExpenseView({
    super.key,
    required this.expenseId,
  });

  final String expenseId;

  @override
  State<ViewCashBankExpenseView> createState() =>
      _ViewCashBankExpenseViewState();
}

class _ViewCashBankExpenseViewState extends State<ViewCashBankExpenseView> {
  final CashBankExpensesController _controller =
      Get.find<CashBankExpensesController>();

  @override
  void initState() {
    super.initState();
    _controller.loadExpenseById(widget.expenseId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppGradients.pageBackground,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: Obx(() {
                    if (_controller.isLoadingDetail.value) {
                      return const Center(
                        child: CircularProgressIndicator(color: _green),
                      );
                    }
                    if (_controller.detailError.value.isNotEmpty) {
                      return _errorState(_controller.detailError.value);
                    }
                    final expense = _controller.detail.value;
                    if (expense == null) {
                      return _errorState('Cash / bank expense was not found.');
                    }
                    return _content(expense);
                  }),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => Get.back<void>(),
              icon: const Icon(Icons.arrow_back_ios_new, color: _ink),
            ),
            const Expanded(
              child: Text(
                'Cash & Bank Expense',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _errorState(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 38,
                color: Color(0xFFB3261E),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              TextButton(
                onPressed: () => _controller.loadExpenseById(widget.expenseId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _content(CashBankExpense expense) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _card(
                  children: [
                    _row('Branch', expense.branch),
                    _row('Date', _displayDate(expense.date)),
                    _row('Transaction Type', expense.transactionType),
                    _row('Payment Mode', expense.paymentMode),
                    _row('Amount',
                        '₹${NumberFormat('#,##0.##').format(expense.amount)}'),
                    _row('Status', expense.approved ? 'Approved' : 'Draft'),
                    _row('Description', expense.description),
                  ],
                ),
                const SizedBox(height: 12),
                _card(
                  children: [
                    const Text(
                      'Attachments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _attachments(expense),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _attachments(CashBankExpense expense) {
    if (!expense.hasAttachmentField || !expense.hasValidAttachmentData) {
      return const Text(
        'Attachment metadata was not returned in a usable format.',
        style: TextStyle(color: _muted),
      );
    }
    if (expense.attachments.isEmpty) {
      return const Text('No attachments.', style: TextStyle(color: _muted));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final attachment in expense.attachments)
          _attachmentTile(attachment),
      ],
    );
  }

  Widget _attachmentTile(CashBankExpenseAttachment attachment) {
    final bytes = _attachmentBytes(attachment.data);
    final isPdf = attachment.mimeType == 'application/pdf';
    return SizedBox(
      width: 160,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: bytes == null ? null : () => _preview(attachment, bytes),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bytes != null && !isPdf)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    bytes,
                    height: 96,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 96,
                      child: Center(
                        child: Icon(Icons.broken_image_outlined, color: _muted),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 96,
                  width: double.infinity,
                  child: Icon(
                    isPdf
                        ? Icons.picture_as_pdf_outlined
                        : Icons.insert_drive_file_outlined,
                    color: _green,
                    size: 42,
                  ),
                ),
              const SizedBox(height: 5),
              Text(
                attachment.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _ink),
              ),
              if (bytes != null)
                const Text(
                  'Tap to preview',
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _preview(
    CashBankExpenseAttachment attachment,
    Uint8List bytes,
  ) async {
    await Get.dialog<void>(
      Dialog(
        child: SizedBox(
          width: 720,
          height: 600,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Close preview',
                  onPressed: () => Get.back<void>(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: attachment.mimeType == 'application/pdf'
                    ? SfPdfViewer.memory(bytes)
                    : InteractiveViewer(
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Uint8List? _attachmentBytes(String data) {
    final comma = data.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(data.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 145,
              child: Text(label, style: const TextStyle(color: _muted)),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  String _displayDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : DateFormat('dd/MM/yyyy').format(parsed);
  }
}
