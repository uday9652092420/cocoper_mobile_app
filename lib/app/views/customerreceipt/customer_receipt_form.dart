import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/customerreceipt/customer_receipt_controller.dart';
import '../../models/customer_receipt.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _maxAttachmentBytes = 10 * 1024 * 1024;

class CustomerReceiptFormView extends StatefulWidget {
  const CustomerReceiptFormView({
    super.key,
    required this.isEdit,
    this.receiptId = '',
    this.attachmentPicker,
  });

  final bool isEdit;
  final String receiptId;
  final Future<List<CustomerReceiptAttachment>?> Function()? attachmentPicker;

  @override
  State<CustomerReceiptFormView> createState() =>
      _CustomerReceiptFormViewState();
}

class _CustomerReceiptFormViewState extends State<CustomerReceiptFormView> {
  final CustomerReceiptController _controller =
      Get.find<CustomerReceiptController>();
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _date = TextEditingController();
  final _amount = TextEditingController();
  final _remarks = TextEditingController();
  final _invoiceNumber = TextEditingController();
  String? _customerId;
  String _invoiceMode = 'Invoice by Invoice';
  String _paymentMode = 'Cash';
  CustomerReceipt? _receipt;
  bool _loading = true;
  String? _loadError;
  String? _numberError;
  bool _isGeneratingNumber = false;
  bool _hasUserEditedNumber = false;
  bool _isPickingAttachments = false;
  final List<CustomerReceiptAttachment> _attachments = [];
  String? _attachmentError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    if (widget.isEdit) {
      await _controller.loadFormLookups();
      if (!mounted) return;
      if (_controller.lookupError.value.isNotEmpty) {
        setState(() {
          _loading = false;
          _loadError = _controller.lookupError.value;
        });
        return;
      }
      final receipt = await _controller.fetchReceipt(widget.receiptId);
      if (!mounted) return;
      if (receipt == null) {
        setState(() {
          _loading = false;
          _loadError = _controller.hasListError.value
              ? 'Unable to load the latest receipt.'
              : 'This receipt is no longer available.';
        });
        return;
      }
      if (receipt.status.trim().toLowerCase() != 'draft') {
        setState(() {
          _loading = false;
          _loadError = 'Only Draft customer receipts can be edited.';
        });
        return;
      }
      if (!const {'Invoice by Invoice', 'Cumulative'}
              .contains(receipt.invoiceMode) ||
          !const {'Cash', 'UPI'}.contains(receipt.paymentMode)) {
        setState(() {
          _loading = false;
          _loadError =
              'This receipt uses an unsupported mode and cannot be edited.';
        });
        return;
      }
      if (!_controller.customers
          .any((customer) => customer.id == receipt.customerId)) {
        setState(() {
          _loading = false;
          _loadError =
              'The receipt customer is unavailable in the current customer list.';
        });
        return;
      }
      if (receipt.invoiceMode == 'Invoice by Invoice' &&
          !_controller.approvedInvoices.any((invoice) =>
              invoice.number == receipt.invoiceNumber &&
              (invoice.customerId.isEmpty ||
                  invoice.customerId == receipt.customerId))) {
        setState(() {
          _loading = false;
          _loadError =
              'The receipt invoice is unavailable in the approved invoice list.';
        });
        return;
      }
      _receipt = receipt;
      _number.text = receipt.receiptNumber;
      _date.text = _displayDate(receipt.date);
      _amount.text = receipt.amount == receipt.amount.roundToDouble()
          ? receipt.amount.toInt().toString()
          : receipt.amount.toString();
      _remarks.text = receipt.remarks;
      _customerId = receipt.customerId;
      _invoiceMode = receipt.invoiceMode;
      _paymentMode = receipt.paymentMode;
    } else {
      _date.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
      if (!mounted) return;
      setState(() => _loading = false);
      unawaited(_loadNewReceiptLookups());
      unawaited(_generateReceiptNumber());
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadNewReceiptLookups() async {
    await _controller.loadFormLookups();
    if (mounted) setState(() {});
  }

  Future<void> _retryLookups() async {
    if (_controller.isLoadingForm.value) return;
    await _loadNewReceiptLookups();
  }

  Future<void> _generateReceiptNumber() async {
    if (_isGeneratingNumber) return;
    setState(() {
      _isGeneratingNumber = true;
      _numberError = null;
    });
    final number = await _controller.generateReceiptNumber();
    if (!mounted) return;
    setState(() {
      _isGeneratingNumber = false;
      if (number == null) {
        _numberError = 'Could not generate a receipt number. Retry or enter '
            'one manually.';
      } else if (!_hasUserEditedNumber) {
        _number.text = number;
        _numberError = null;
      } else {
        _numberError = null;
      }
    });
  }

  @override
  void dispose() {
    _number.dispose();
    _date.dispose();
    _amount.dispose();
    _remarks.dispose();
    _invoiceNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.isEdit ? 'Edit Customer Receipt' : 'New Customer Receipt';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        title: Text(title),
        foregroundColor: _kInk,
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
          ? const Center(child: CircularProgressIndicator(color: _kGreen))
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
              const Icon(Icons.error_outline, color: _kMuted, size: 36),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(onPressed: _initialize, child: const Text('Retry')),
            ],
          ),
        ),
      );

  Widget _buildForm() => Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _kLine),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_controller.isLoadingForm.value ||
                            _controller.lookupError.value.isNotEmpty) ...[
                          _lookupStatus(),
                          const SizedBox(height: 14),
                        ],
                        _twoFields(
                          _receiptNumberField(),
                          _input(
                            'Date',
                            _date,
                            required: true,
                            readOnly: true,
                            onTap: _pickDate,
                            suffixIcon:
                                const Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _twoFields(
                          _customerField(),
                          _dropdown(
                            'Invoice Mode',
                            _invoiceMode,
                            const ['Invoice by Invoice', 'Cumulative'],
                            (value) {
                              setState(() {
                                _invoiceMode = value!;
                                _invoiceNumber.clear();
                                _amount.clear();
                              });
                            },
                          ),
                        ),
                        if (!_controller.isLoadingForm.value &&
                            _controller.customers.isEmpty) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'No customers are available.',
                            style: TextStyle(fontSize: 12, color: _kMuted),
                          ),
                        ],
                        const SizedBox(height: 14),
                        if (_invoiceMode == 'Invoice by Invoice') ...[
                          _invoiceField(),
                          if (!_controller.isLoadingForm.value &&
                              _controller
                                  .invoicesForCustomer(_customerId ?? '')
                                  .isEmpty) ...[
                            const SizedBox(height: 6),
                            const Text(
                              'No approved invoices are available for this '
                              'customer.',
                              style: TextStyle(fontSize: 12, color: _kMuted),
                            ),
                          ],
                          const SizedBox(height: 14),
                        ],
                        if (widget.isEdit) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFEAD6A7),
                              ),
                            ),
                            child: const Text(
                              'The receipt list may omit existing attachment '
                              'data. Select replacement attachment(s) before '
                              'saving unless the existing files are shown '
                              'below; this prevents an update from clearing '
                              'unknown attachments.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF765B1B),
                              ),
                            ),
                          ),
                        ],
                        _twoFields(
                          _dropdown(
                            'Payment Mode',
                            _paymentMode,
                            const ['Cash', 'UPI'],
                            (value) => setState(() => _paymentMode = value!),
                          ),
                          _input(
                            'Amount',
                            _amount,
                            required: true,
                            numeric: true,
                            prefixText: '₹ ',
                          ),
                        ),
                        const SizedBox(height: 14),
                        _attachmentSection(),
                        const SizedBox(height: 14),
                        _input('Remarks', _remarks, maxLines: 2),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSaveButton(),
            ],
          ),
        ),
      );

  Widget _customerField() => DropdownButtonFormField<String>(
        initialValue: _customerId,
        isExpanded: true,
        decoration: _decoration('Customer'),
        hint: const Text('Select customer'),
        items: [
          for (final customer in _controller.customers)
            DropdownMenuItem(
              value: customer.id,
              child: Text(customer.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _controller.isLoadingForm.value
            ? null
            : (value) => setState(() {
                  _customerId = value;
                  _invoiceNumber.clear();
                  _amount.clear();
                }),
        validator: (value) =>
            (value?.isNotEmpty ?? false) ? null : 'Select a customer.',
      );

  Widget _receiptNumberField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _input(
            'Receipt Number',
            _number,
            required: true,
            onChanged: (_) => _hasUserEditedNumber = true,
            suffixIcon: _isGeneratingNumber
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          if (_numberError != null && !widget.isEdit) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _numberError!,
                    style: const TextStyle(
                      color: Color(0xFFB3261E),
                      fontSize: 11,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      _isGeneratingNumber ? null : _generateReceiptNumber,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(40, 32),
                  ),
                  child: _isGeneratingNumber
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Retry'),
                ),
              ],
            ),
          ],
        ],
      );

  Widget _invoiceField() {
    final invoices = _controller.invoicesForCustomer(
      _customerId ?? '',
      excludingReceiptId: widget.isEdit ? _receipt?.id : null,
    );
    if (widget.isEdit &&
        _invoiceNumber.text.isNotEmpty &&
        invoices.every((invoice) => invoice.number != _invoiceNumber.text)) {
      CustomerReceiptInvoice? original;
      for (final invoice in _controller.approvedInvoices) {
        if (invoice.number == _invoiceNumber.text &&
            invoice.customerId == _customerId) {
          original = invoice;
          break;
        }
      }
      if (original != null) invoices.add(original);
    }
    return DropdownButtonFormField<String>(
      key: ValueKey('invoice-$_customerId-$_invoiceMode'),
      initialValue: _invoiceNumber.text.isEmpty ? null : _invoiceNumber.text,
      isExpanded: true,
      decoration: _decoration('Invoice No'),
      hint: const Text('Select invoice'),
      items: [
        for (final invoice in invoices)
          DropdownMenuItem(
            value: invoice.number,
            child: Text(
              '${invoice.displayNumber.isEmpty ? invoice.number : invoice.displayNumber}'
              ' · ${_formatAmount(invoice.total)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: _controller.isLoadingForm.value
          ? null
          : (value) => setState(() {
                _invoiceNumber.text = value ?? '';
                final invoice = value == null
                    ? null
                    : _controller.invoiceForCustomer(
                        _customerId ?? '',
                        value,
                        excludingReceiptId: widget.isEdit ? _receipt?.id : null,
                      );
                _amount.text =
                    invoice == null ? '' : _formatAmount(invoice.outstanding);
              }),
      validator: (value) {
        if (value?.isNotEmpty != true) return 'Select an invoice.';
        if (_controller.invoiceForCustomer(
              _customerId ?? '',
              value!,
              excludingReceiptId: widget.isEdit ? _receipt?.id : null,
            ) ==
            null) {
          return 'Select an unpaid invoice for this customer.';
        }
        return null;
      },
    );
  }

  Widget _attachmentSection() {
    final currentReceipt = _receipt;
    final existingNames = currentReceipt?.hasAttachmentFields == true
        ? CustomerReceiptAttachment.attachmentNamesFromJson(
            currentReceipt?.attachmentNamesJson,
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Payment Screenshot'),
        const SizedBox(height: 6),
        if (existingNames != null && existingNames.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kLine),
            ),
            child: Text(
              'Existing attachment(s): $existingNames',
              style: const TextStyle(fontSize: 12, color: _kMuted),
            ),
          ),
        ],
        OutlinedButton.icon(
          onPressed: _isPickingAttachments ? null : _pickAttachments,
          icon: _isPickingAttachments
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.attach_file),
          label: Text(_isPickingAttachments
              ? 'Opening files…'
              : _attachments.isEmpty
                  ? 'Attach File / Upload Attachment'
                  : 'Add Files'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kInk,
            side: const BorderSide(color: _kLine),
            minimumSize: const Size(double.infinity, 46),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'PDF, JPG, JPEG, or PNG · up to 10 MB total',
          style: TextStyle(fontSize: 11, color: _kMuted),
        ),
        if (widget.isEdit && _attachments.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text(
            'Selected files will replace the receipt’s existing attachments.',
            style: TextStyle(fontSize: 11, color: _kMuted),
          ),
        ],
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (var index = 0; index < _attachments.length; index++)
            _attachmentTile(index),
        ],
        if (_attachmentError != null) ...[
          const SizedBox(height: 6),
          Text(
            _attachmentError!,
            style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _attachmentTile(int index) {
    final attachment = _attachments[index];
    final extension = attachment.name.split('.').last.toLowerCase();
    final icon = extension == 'pdf'
        ? Icons.picture_as_pdf_outlined
        : Icons.image_outlined;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kLine),
      ),
      child: Row(
        children: [
          Icon(icon, color: _kGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _kInk),
            ),
          ),
          IconButton(
            tooltip: 'Remove ${attachment.name}',
            onPressed: () => setState(() {
              _attachments.removeAt(index);
              _attachmentError = null;
            }),
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _pickAttachments() async {
    if (_isPickingAttachments) return;
    setState(() {
      _isPickingAttachments = true;
      _attachmentError = null;
    });
    try {
      final picked = widget.attachmentPicker != null
          ? await widget.attachmentPicker!.call()
          : await _pickDeviceAttachments();
      if (!mounted || picked == null || picked.isEmpty) return;

      for (final attachment in picked) {
        if (CustomerReceiptAttachment.mimeTypeForName(attachment.name) ==
            null) {
          setState(() {
            _attachmentError =
                'Unsupported file "${attachment.name}". Choose a PDF, JPG, '
                'JPEG, or PNG file.';
          });
          return;
        }
        if (attachment.bytes.isEmpty) {
          setState(() {
            _attachmentError =
                'Could not read "${attachment.name}". Choose the file again.';
          });
          return;
        }
      }

      final newTotal = [
        ..._attachments,
        ...picked,
      ].fold<int>(0, (total, file) => total + file.bytes.length);
      if (newTotal > _maxAttachmentBytes) {
        setState(() {
          _attachmentError =
              'Selected attachments exceed the 10 MB total size limit.';
        });
        return;
      }
      setState(() {
        _attachments.addAll(picked);
        _attachmentError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _attachmentError = 'Unable to select attachments: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isPickingAttachments = false);
      }
    }
  }

  Future<List<CustomerReceiptAttachment>?> _pickDeviceAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withReadStream: true,
    );
    if (result == null) return null;
    final selectedSize = result.files.fold<int>(
      0,
      (total, file) => total + file.size,
    );
    final currentlySelectedSize = _attachments.fold<int>(
      0,
      (total, file) => total + file.bytes.length,
    );
    if (currentlySelectedSize + selectedSize > _maxAttachmentBytes) {
      throw const FormatException(
        'Selected attachments exceed the 10 MB total size limit.',
      );
    }
    final files = <CustomerReceiptAttachment>[];
    for (final file in result.files) {
      final bytes = file.bytes ?? await _readPickedFile(file);
      if (currentlySelectedSize +
              files.fold<int>(0, (total, item) => total + item.bytes.length) +
              bytes.length >
          _maxAttachmentBytes) {
        throw const FormatException(
          'Selected attachments exceed the 10 MB total size limit.',
        );
      }
      files.add(CustomerReceiptAttachment(name: file.name, bytes: bytes));
    }
    return files;
  }

  Future<Uint8List> _readPickedFile(PlatformFile file) async {
    final stream = file.readStream;
    if (stream == null) {
      return file.xFile.readAsBytes();
    }
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

  Widget _lookupStatus() {
    final loading = _controller.isLoadingForm.value;
    final message = loading
        ? 'Loading customers and eligible invoices…'
        : _controller.lookupError.value;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: loading ? const Color(0xFFF6F8F6) : const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kLine),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.error_outline, color: Color(0xFFB3261E), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: _kMuted),
            ),
          ),
          if (!loading)
            TextButton(
              onPressed: _retryLookups,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _dropdown(
    String label,
    String current,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) =>
      DropdownButtonFormField<String>(
        initialValue: current,
        isExpanded: true,
        decoration: _decoration(label),
        items: [
          for (final value in values)
            DropdownMenuItem(value: value, child: Text(value)),
        ],
        onChanged: onChanged,
      );

  Widget _input(
    String label,
    TextEditingController controller, {
    bool required = false,
    bool readOnly = false,
    bool numeric = false,
    int maxLines = 1,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
    String? prefixText,
  }) =>
      TextFormField(
        controller: controller,
        onChanged: onChanged,
        readOnly: readOnly,
        maxLines: maxLines,
        onTap: onTap,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        inputFormatters:
            numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: _decoration(label).copyWith(
          suffixIcon: suffixIcon,
          prefixText: prefixText,
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) return '$label is required.';
          if (numeric && text.isNotEmpty) {
            final amount = double.tryParse(text);
            if (amount == null || !amount.isFinite || amount <= 0) {
              return 'Enter an amount greater than zero.';
            }
            if (amount != amount.roundToDouble()) {
              return 'Amount must be a whole number of rupees.';
            }
          }
          return null;
        },
      );

  Widget _fieldLabel(String label) => Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _kInk,
        ),
      );

  Widget _twoFields(Widget first, Widget second) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return Column(
        children: [
          first,
          const SizedBox(height: 14),
          second,
        ],
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

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFAFBFA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kLine),
        ),
      );

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
                          _attachments.isEmpty &&
                          _receipt?.hasAttachmentFields != true)
                  ? null
                  : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
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
                  : Text(widget.isEdit ? 'Save Changes' : 'Save'),
            ),
          ),
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = int.parse(_amount.text.trim()).toDouble();
    final date = DateFormat('dd/MM/yyyy').parseStrict(_date.text.trim());
    final receipt = CustomerReceipt(
      id: _receipt?.id ?? '',
      receiptNumber: _number.text.trim(),
      date: DateFormat('yyyy-MM-dd').format(date),
      customerId: _customerId ?? '',
      invoiceMode: _invoiceMode,
      invoiceNumber: _invoiceMode == 'Invoice by Invoice'
          ? _invoiceNumber.text.trim()
          : '',
      paymentMode: _paymentMode,
      remarks: _remarks.text.trim(),
      amount: amount,
      status: _receipt?.status ?? 'Draft',
      attachmentNamesJson: _receipt?.attachmentNamesJson,
      attachmentFilesJson: _receipt?.attachmentFilesJson,
      hasAttachmentFields: _receipt?.hasAttachmentFields ?? false,
    );
    final saved = await _controller.saveReceipt(
      receipt,
      isEdit: widget.isEdit,
      attachments: _attachments,
    );
    if (saved && mounted) Get.back<void>();
  }

  Future<void> _pickDate() async {
    final current = DateFormat('dd/MM/yyyy').parseStrict(_date.text);
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

  String _displayDate(String date) {
    final parsed = DateTime.tryParse(date);
    return parsed == null ? date : DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _formatAmount(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
