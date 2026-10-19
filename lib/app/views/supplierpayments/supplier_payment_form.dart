import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/supplierpayments/supplier_payment_controller.dart';
import '../../models/lookup_option.dart';
import '../../models/purchase_invoice.dart';
import '../../models/supplier_payment.dart';
import '../../theme/app_theme.dart';

const _ink = AppColors.textDefaultLight;
const _muted = AppColors.textLightGrayLight;
const _line = AppColors.borderLightGrayLight;
const _green = AppColors.primaryLight;
const _maxAttachmentBytes = 10 * 1024 * 1024;

class SupplierPaymentFormView extends StatefulWidget {
  const SupplierPaymentFormView({
    super.key,
    required this.isEdit,
    this.paymentId = '',
  });

  final bool isEdit;
  final String paymentId;

  @override
  State<SupplierPaymentFormView> createState() =>
      _SupplierPaymentFormViewState();
}

class _SupplierPaymentFormViewState extends State<SupplierPaymentFormView> {
  final SupplierPaymentController _controller =
      Get.find<SupplierPaymentController>();
  final _formKey = GlobalKey<FormState>();
  final _paymentNumber = TextEditingController();
  final _date = TextEditingController();
  final _amount = TextEditingController();
  final _remarks = TextEditingController();
  String? _supplierId;
  String? _invoiceId;
  String _invoiceMode = 'Invoice by Invoice';
  String _paymentMode = 'Cash';
  SupplierPayment? _existingPayment;
  bool _loading = true;
  String? _loadError;
  bool _replaceAttachments = false;
  bool _pickingAttachments = false;
  String? _attachmentError;
  final List<SupplierPaymentAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    _date.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _paymentNumber.dispose();
    _date.dispose();
    _amount.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });

    await _controller.loadLookups();
    if (!mounted) return;
    if (_controller.lookupError.value.isNotEmpty) {
      setState(() {
        _loading = false;
        _loadError = _controller.lookupError.value;
      });
      return;
    }

    if (widget.isEdit) {
      final payment =
          await _controller.loadSupplierPaymentById(widget.paymentId);
      if (!mounted) return;
      if (payment == null) {
        setState(() {
          _loading = false;
          _loadError = _controller.detailError.value.isNotEmpty
              ? _controller.detailError.value
              : 'Supplier payment is unavailable.';
        });
        return;
      }
      _existingPayment = payment;
      _paymentNumber.text = payment.paymentNumber;
      final date = DateTime.tryParse(payment.date);
      _date.text =
          date == null ? payment.date : DateFormat('dd/MM/yyyy').format(date);
      _amount.text = _formatAmount(payment.amount);
      _remarks.text = payment.remarks;
      _supplierId = payment.supplierId;
      _invoiceId =
          payment.purchaseInvoiceId.isEmpty ? null : payment.purchaseInvoiceId;
      _invoiceMode = payment.invoiceMode;
      _paymentMode = payment.paymentMode;
    } else {
      final number = await _controller.generatePaymentNumber();
      if (!mounted) return;
      _paymentNumber.text = number ?? '';
      if (number == null) {
        setState(() {
          _loading = false;
          _loadError = 'Payment number could not be generated. Retry to load '
              'the payment form.';
        });
        return;
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _retry() async {
    if (_controller.isLoadingLookups.value ||
        _controller.isLoadingDetail.value) {
      return;
    }
    await _initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Edit Supplier Payment' : 'New Supplier Payment',
        ),
        foregroundColor: _ink,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Close'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _loadError != null
              ? _buildLoadError()
              : _buildForm(),
    );
  }

  Widget _buildLoadError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _muted, size: 36),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(onPressed: _retry, child: const Text('Retry')),
            ],
          ),
        ),
      );

  Widget _buildForm() => Form(
        key: _formKey,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _line),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _twoFields(
                              _textField(
                                'Payment Number',
                                _paymentNumber,
                                readOnly: true,
                                suffixIcon: widget.isEdit
                                    ? null
                                    : const Icon(Icons.auto_awesome_outlined),
                              ),
                              _textField(
                                'Payment Date',
                                _date,
                                readOnly: true,
                                onTap: _pickDate,
                                suffixIcon:
                                    const Icon(Icons.calendar_today_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _twoFields(_supplierField(), _invoiceModeField()),
                            const SizedBox(height: 14),
                            if (_invoiceMode == 'Invoice by Invoice') ...[
                              _invoiceField(),
                              const SizedBox(height: 14),
                            ],
                            _twoFields(_paymentModeField(), _amountField()),
                            const SizedBox(height: 14),
                            _attachmentSection(),
                            const SizedBox(height: 14),
                            _textField('Remarks', _remarks, maxLines: 3),
                            if (_controller.lookupError.value.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _inlineError(
                                _controller.lookupError.value,
                                onRetry: _retry,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildSaveButton(),
            ],
          ),
        ),
      );

  Widget _supplierField() {
    final suppliers = _controller.suppliers.toList(growable: false);
    if (_supplierId != null &&
        suppliers.every((supplier) => supplier.id != _supplierId)) {
      suppliers.add(
        LookupOption(
          id: _supplierId!,
          label: _existingPayment?.supplierName.isNotEmpty == true
              ? _existingPayment!.supplierName
              : _supplierId!,
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _supplierId,
      isExpanded: true,
      decoration: _decoration('Supplier'),
      hint: const Text('Select supplier'),
      items: [
        for (final supplier in suppliers)
          DropdownMenuItem(
            value: supplier.id,
            child: Text(supplier.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => setState(() {
        _supplierId = value;
        _invoiceId = null;
      }),
      validator: (value) =>
          value == null || value.isEmpty ? 'Select a supplier.' : null,
    );
  }

  Widget _invoiceModeField() => DropdownButtonFormField<String>(
        initialValue: _invoiceMode,
        isExpanded: true,
        decoration: _decoration('Invoice Mode'),
        items: const [
          DropdownMenuItem(
            value: 'Invoice by Invoice',
            child: Text('Invoice by Invoice'),
          ),
          DropdownMenuItem(value: 'Cumulative', child: Text('Cumulative')),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _invoiceMode = value;
            if (value == 'Cumulative') _invoiceId = null;
          });
        },
      );

  Widget _invoiceField() {
    final editing = _existingPayment;
    final invoices = _controller.invoicesForSupplier(
      _supplierId ?? '',
      editing: editing,
    );
    final selectedAvailable = _invoiceId != null &&
        invoices.any((invoice) => invoice.id == _invoiceId);
    return DropdownButtonFormField<String>(
      initialValue: selectedAvailable ? _invoiceId : null,
      isExpanded: true,
      decoration: _decoration('Purchase Invoice'),
      hint: Text(
        _supplierId == null ? 'Select a supplier first' : 'Select invoice',
      ),
      items: [
        for (final invoice in invoices)
          DropdownMenuItem(
            value: invoice.id,
            child: Text(
              '${invoice.invoiceNumber} · Outstanding ₹'
              '${_formatAmount(_controller.outstandingForInvoice(
                invoice,
                editing: editing,
              ))}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (!selectedAvailable && _invoiceId != null)
          DropdownMenuItem(
            value: _invoiceId,
            child: Text(
              _existingPayment?.purchaseInvoiceId == _invoiceId
                  ? _invoiceLabel(_invoiceId!)
                  : _invoiceId!,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: _supplierId == null
          ? null
          : (value) => setState(() => _invoiceId = value),
      validator: (value) =>
          value == null || value.isEmpty ? 'Select a purchase invoice.' : null,
    );
  }

  String _invoiceLabel(String id) {
    for (final invoice in _controller.purchaseInvoices) {
      if (invoice.id == id) {
        return invoice.invoiceNumber.isEmpty ? id : invoice.invoiceNumber;
      }
    }
    return id;
  }

  Widget _paymentModeField() => DropdownButtonFormField<String>(
        initialValue: _paymentMode,
        isExpanded: true,
        decoration: _decoration('Payment Mode'),
        items: const [
          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
          DropdownMenuItem(value: 'Bank', child: Text('Bank')),
          DropdownMenuItem(value: 'UPI', child: Text('UPI')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _paymentMode = value);
        },
      );

  Widget _amountField() {
    final invoice = _selectedInvoice;
    final available = invoice == null
        ? null
        : _controller.outstandingForInvoice(
            invoice,
            editing: _existingPayment,
          );
    return TextFormField(
      controller: _amount,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: _decoration('Amount').copyWith(
        prefixText: '₹ ',
        helperText: _invoiceMode == 'Invoice by Invoice' && available != null
            ? 'Available balance: ₹${_formatAmount(available)}'
            : null,
      ),
      validator: (value) {
        final amount = double.tryParse(value?.trim() ?? '');
        if (amount == null || !amount.isFinite || amount <= 0) {
          return 'Enter an amount greater than zero.';
        }
        if (available != null && amount > available + 0.01) {
          return 'Amount exceeds the available invoice balance.';
        }
        return null;
      },
    );
  }

  PurchaseInvoice? get _selectedInvoice {
    for (final invoice in _controller.purchaseInvoices) {
      if (invoice.id == _invoiceId) return invoice;
    }
    return null;
  }

  Widget _attachmentSection() {
    final names = SupplierPaymentAttachment.decodeStringArray(
      _existingPayment?.attachmentNamesJson,
    );
    final hasData = _existingPayment?.attachmentNamesJson?.isNotEmpty == true ||
        _existingPayment?.attachmentFilesJson?.isNotEmpty == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attachment',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        if (widget.isEdit &&
            _existingPayment?.canSafelyPreserveAttachments != true) ...[
          const SizedBox(height: 8),
          _inlineError(
            'Existing attachment fields were not returned. Saving is blocked '
            'to prevent accidental file loss.',
          ),
        ] else if (widget.isEdit && hasData) ...[
          const SizedBox(height: 6),
          Text(
            names == null || names.isEmpty
                ? 'Existing attachment data is available.'
                : 'Existing: ${names.join(', ')}',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ] else if (widget.isEdit) ...[
          const SizedBox(height: 6),
          const Text(
            'No existing attachments.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ],
        if (widget.isEdit) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _replaceAttachments,
            onChanged: (value) =>
                setState(() => _replaceAttachments = value ?? false),
            title: const Text(
              'Replace existing attachments with selected files',
              style: TextStyle(fontSize: 13, color: _ink),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
        OutlinedButton.icon(
          onPressed: _pickingAttachments ? null : _pickAttachments,
          icon: _pickingAttachments
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.attach_file),
          label: Text(_pickingAttachments
              ? 'Opening files…'
              : _attachments.isEmpty
                  ? 'Choose PDF or image files'
                  : 'Add files'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            side: const BorderSide(color: _line),
            minimumSize: const Size(double.infinity, 46),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'PDF, JPG, JPEG, or PNG · up to 10 MB total',
          style: TextStyle(fontSize: 11, color: _muted),
        ),
        if (widget.isEdit && _attachments.isNotEmpty && !_replaceAttachments)
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Text(
              'Selected files will not be uploaded unless replacement is '
              'confirmed.',
              style: TextStyle(fontSize: 11, color: _muted),
            ),
          ),
        for (var index = 0; index < _attachments.length; index++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _attachments[index].name.toLowerCase().endsWith('.pdf')
                  ? Icons.picture_as_pdf_outlined
                  : Icons.image_outlined,
              color: _green,
            ),
            title: Text(
              _attachments[index].name,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Remove ${_attachments[index].name}',
              onPressed: () => setState(() {
                _attachments.removeAt(index);
                _attachmentError = null;
              }),
              icon: const Icon(Icons.close),
            ),
          ),
        if (_attachmentError != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              _attachmentError!,
              style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _pickAttachments() async {
    if (_pickingAttachments) return;
    setState(() {
      _pickingAttachments = true;
      _attachmentError = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withReadStream: true,
      );
      if (!mounted || result == null) return;
      final existingSize =
          _attachments.fold<int>(0, (sum, file) => sum + file.bytes.length);
      final pickedSize =
          result.files.fold<int>(0, (sum, file) => sum + file.size);
      if (existingSize + pickedSize > _maxAttachmentBytes) {
        throw const FormatException(
          'Selected attachments exceed the 10 MB total size limit.',
        );
      }
      final selected = <SupplierPaymentAttachment>[];
      for (final file in result.files) {
        if (SupplierPaymentAttachment.mimeTypeForName(file.name) == null) {
          throw FormatException('Unsupported attachment type: ${file.name}');
        }
        final bytes = file.bytes ?? await _readFile(file);
        if (bytes.isEmpty) {
          throw FormatException('Could not read ${file.name}.');
        }
        selected.add(SupplierPaymentAttachment(name: file.name, bytes: bytes));
      }
      setState(() => _attachments.addAll(selected));
    } catch (error) {
      if (mounted) setState(() => _attachmentError = error.toString());
    } finally {
      if (mounted) setState(() => _pickingAttachments = false);
    }
  }

  Future<Uint8List> _readFile(PlatformFile file) async {
    final stream = file.readStream;
    if (stream == null) return file.xFile.readAsBytes();
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
      if (builder.length > _maxAttachmentBytes) {
        throw const FormatException(
          'Selected attachments exceed the 10 MB total size limit.',
        );
      }
    }
    return builder.takeBytes();
  }

  Widget _buildSaveButton() => SafeArea(
        top: false,
        child: Obx(
          () => Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            color: Colors.white,
            child: ElevatedButton(
              onPressed: _controller.isSaving.value ||
                      (widget.isEdit &&
                          _existingPayment?.canSafelyPreserveAttachments !=
                              true) ||
                      (_replaceAttachments && _attachments.isEmpty)
                  ? null
                  : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _controller.isSaving.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.isEdit ? 'Save Changes' : 'Save Payment'),
            ),
          ),
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final date = DateFormat('dd/MM/yyyy').parseStrict(_date.text.trim());
    final payment = SupplierPayment(
      id: _existingPayment?.id ?? '',
      paymentNumber: _paymentNumber.text.trim(),
      supplierId: _supplierId ?? '',
      supplierName: _supplierName,
      date: DateFormat('yyyy-MM-dd').format(date),
      invoiceMode: _invoiceMode,
      paymentMode: _paymentMode,
      amount: double.parse(_amount.text.trim()),
      purchaseInvoiceId:
          _invoiceMode == 'Invoice by Invoice' ? (_invoiceId ?? '') : '',
      remarks: _remarks.text.trim(),
      attachmentNamesJson: _existingPayment?.attachmentNamesJson,
      attachmentFilesJson: _existingPayment?.attachmentFilesJson,
      hasAttachmentFields: _existingPayment?.hasAttachmentFields ?? false,
      approved: _existingPayment?.approved ?? false,
    );
    final saved = widget.isEdit
        ? await _controller.updateSupplierPayment(
            payment,
            existingPayment: _existingPayment!,
            replaceAttachments: _replaceAttachments,
            attachments: _attachments,
          )
        : await _controller.createSupplierPayment(
            payment,
            attachments: _attachments,
          );
    if (saved && mounted) Get.back<bool>(result: true);
  }

  String get _supplierName {
    for (final supplier in _controller.suppliers) {
      if (supplier.id == _supplierId) return supplier.label;
    }
    return _existingPayment?.supplierName ?? '';
  }

  Future<void> _pickDate() async {
    final current =
        DateFormat('dd/MM/yyyy').tryParseStrict(_date.text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (selected != null && mounted) {
      _date.text = DateFormat('dd/MM/yyyy').format(selected);
    }
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    int maxLines = 1,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) =>
      TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        onTap: onTap,
        decoration: _decoration(label).copyWith(suffixIcon: suffixIcon),
        validator: (value) => value == null || value.trim().isEmpty
            ? '$label is required.'
            : null,
      );

  Widget _twoFields(Widget first, Widget second) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return Column(
        children: [first, const SizedBox(height: 14), second],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }

  Widget _inlineError(String message, {VoidCallback? onRetry}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF1C7C4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFB3261E), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFAFBFA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
      );

  static String _formatAmount(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
