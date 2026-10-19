import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../controllers/supplierpayments/supplier_payment_controller.dart';
import '../../models/supplier_payment.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

const _ink = AppColors.textDefaultLight;
const _muted = AppColors.textLightGrayLight;
const _line = AppColors.borderLightGrayLight;
const _green = AppColors.primaryLight;

class ViewSupplierPaymentView extends StatefulWidget {
  const ViewSupplierPaymentView({
    super.key,
    required this.paymentId,
  });

  final String paymentId;

  @override
  State<ViewSupplierPaymentView> createState() =>
      _ViewSupplierPaymentViewState();
}

class _ViewSupplierPaymentViewState extends State<ViewSupplierPaymentView> {
  final SupplierPaymentController _controller =
      Get.find<SupplierPaymentController>();

  @override
  void initState() {
    super.initState();
    unawaited(_controller.loadLookups());
    _controller.loadSupplierPaymentById(widget.paymentId);
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
                      return _errorState();
                    }
                    final payment = _controller.detail.value;
                    if (payment == null) {
                      return _errorState('Supplier payment was not found.');
                    }
                    return _content(payment);
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
                'Supplier Payment Details',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            Obx(() {
              final payment = _controller.detail.value;
              if (payment == null || payment.id.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Edit',
                onPressed: () async {
                  final result = await Get.toNamed<bool>(
                    Routes.editSupplierPayment,
                    arguments: payment.id,
                  );
                  if (result == true) {
                    await _controller.loadSupplierPaymentById(payment.id);
                  }
                },
                icon: const Icon(Icons.edit_outlined, color: _green),
              );
            }),
          ],
        ),
      );

  Widget _content(SupplierPayment payment) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _card(
                  children: [
                    _row('Payment Number', payment.paymentNumber),
                    _row('Date', _displayDate(payment.date)),
                    _row(
                        'Supplier',
                        payment.supplierName.isEmpty
                            ? payment.supplierId
                            : payment.supplierName),
                    _row('Invoice Mode', payment.invoiceMode),
                    if (payment.invoiceMode == 'Invoice by Invoice')
                      _row('Purchase Invoice', _invoiceLabel(payment)),
                    _row('Payment Mode', payment.paymentMode),
                    _row('Amount', '₹${_formatAmount(payment.amount)}'),
                    _row('Status', payment.approved ? 'Approved' : 'Draft'),
                    _row('Remarks', payment.remarks),
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
                    _attachments(payment),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _attachments(SupplierPayment payment) {
    if (!payment.hasAttachmentFields) {
      return const Text(
        'Attachment metadata was not returned by the server.',
        style: TextStyle(color: _muted),
      );
    }
    final names = SupplierPaymentAttachment.decodeStringArray(
      payment.attachmentNamesJson,
    );
    final files = SupplierPaymentAttachment.decodeStringArray(
      payment.attachmentFilesJson,
    );
    if (names == null || files == null) {
      if (payment.attachmentNamesJson == null &&
          payment.attachmentFilesJson == null) {
        return const Text(
          'No attachments.',
          style: TextStyle(color: _muted),
        );
      }
      return const Text(
        'Attachment metadata is invalid and cannot be previewed.',
        style: TextStyle(color: _muted),
      );
    }
    if (names.isEmpty && files.isEmpty) {
      return const Text('No attachments.', style: TextStyle(color: _muted));
    }
    if (names.length != files.length) {
      return const Text(
        'Attachment names and file data do not match; preview is unavailable.',
        style: TextStyle(color: _muted),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < names.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              names[index].toLowerCase().endsWith('.pdf')
                  ? Icons.picture_as_pdf_outlined
                  : Icons.image_outlined,
              color: _green,
            ),
            title: Text(names[index], overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.open_in_new, color: _muted),
            onTap: () => _previewAttachment(
              context,
              names[index],
              files[index],
            ),
          ),
      ],
    );
  }

  Future<void> _previewAttachment(
    BuildContext context,
    String name,
    String dataUrl,
  ) async {
    try {
      final comma = dataUrl.indexOf(',');
      if (!dataUrl.startsWith('data:') || comma < 0) {
        throw const FormatException('The attachment is not a valid data URL.');
      }
      final bytes = base64Decode(dataUrl.substring(comma + 1));
      if (name.toLowerCase().endsWith('.pdf')) {
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: SizedBox(
              width: 900,
              height: MediaQuery.sizeOf(context).height * 0.85,
              child: SfPdfViewer.memory(bytes),
            ),
          ),
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            child: InteractiveViewer(
              child: Image.memory(
                Uint8List.fromList(bytes),
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Unable to preview this image.'),
                ),
              ),
            ),
          ),
        );
      }
    } on FormatException catch (error) {
      Get.snackbar(
        'Attachment unavailable',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  String _invoiceLabel(SupplierPayment payment) {
    for (final invoice in _controller.purchaseInvoices) {
      if (invoice.id == payment.purchaseInvoiceId &&
          invoice.invoiceNumber.isNotEmpty) {
        return invoice.invoiceNumber;
      }
    }
    return payment.purchaseInvoiceId;
  }

  Widget _errorState([String? message]) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: _muted),
              const SizedBox(height: 10),
              Text(
                message ?? _controller.detailError.value,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: widget.paymentId.isEmpty
                    ? null
                    : () => _controller.loadSupplierPaymentById(
                          widget.paymentId,
                        ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: const TextStyle(fontSize: 13, color: _ink),
              ),
            ),
          ],
        ),
      );

  String _displayDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _formatAmount(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
