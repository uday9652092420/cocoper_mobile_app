import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/cash&bankexpenses/cash_bank_expenses_controller.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/cash_bank_expense_model.dart';

const _ink = Color(0xFF14342B);
const _muted = Color(0xFF5C6B66);
const _line = Color(0xFFE4EBE4);
const _green = Color(0xFF2D8135);
const _maxFileBytes = 5 * 1024 * 1024;

class CashBankExpenseFormView extends StatefulWidget {
  const CashBankExpenseFormView({
    super.key,
    required this.isEdit,
    this.expenseId = '',
  });

  final bool isEdit;
  final String expenseId;

  @override
  State<CashBankExpenseFormView> createState() =>
      _CashBankExpenseFormViewState();
}

class _CashBankExpenseFormViewState extends State<CashBankExpenseFormView> {
  final CashBankExpensesController _controller =
      Get.find<CashBankExpensesController>();
  final _formKey = GlobalKey<FormState>();
  final _date = TextEditingController();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _branchId;
  String _paymentMode = 'Cash';
  String _transactionType = 'Expenses';
  CashBankExpense? _existingExpense;
  bool _loading = true;
  String? _loadError;
  bool _pickingAttachments = false;
  String? _attachmentError;
  final List<CashBankExpenseAttachment> _attachments = [];

  bool get _readOnly => _existingExpense?.approved ?? false;

  @override
  void initState() {
    super.initState();
    _date.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _date.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    await _controller.loadBranches();
    if (!mounted) return;
    if (!widget.isEdit && _controller.branchError.value.isNotEmpty) {
      setState(() {
        _loading = false;
        _loadError = _controller.branchError.value;
      });
      return;
    }

    if (widget.isEdit) {
      final expense = await _controller.loadExpenseById(widget.expenseId);
      if (!mounted) return;
      if (expense == null) {
        setState(() {
          _loading = false;
          _loadError = _controller.detailError.value.isNotEmpty
              ? _controller.detailError.value
              : 'Cash / bank expense is unavailable.';
        });
        return;
      }
      _existingExpense = expense;
      _branchId = expense.branchId;
      _date.text = _displayDate(expense.date);
      _amount.text = _formatAmount(expense.amount);
      _description.text = expense.description;
      _paymentMode = expense.paymentMode;
      _transactionType = expense.transactionType;
      _attachments
        ..clear()
        ..addAll(expense.attachments);
      if (_controller.branches.every((branch) => branch.id != expense.branchId)) {
        _controller.branches.add(
          CashBankBranch(
            id: expense.branchId,
            organizationId: expense.organizationId,
            name: expense.branch.isEmpty ? expense.branchId : expense.branch,
            status: 'Existing',
          ),
        );
      }
    } else {
      final selectedBranch = await SharedPrefsHelper.getString(
        SharedPrefsHelper.selectedBranchId,
      );
      if (!mounted) return;
      _branchId = _controller.branches.any((branch) => branch.id == selectedBranch)
          ? selectedBranch
          : _controller.branches.first.id;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _retry() async {
    if (_controller.isLoadingBranches.value ||
        _controller.isLoadingDetail.value) {
      return;
    }
    await _initialize();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F6F4),
        appBar: AppBar(
          title: Text(
            widget.isEdit ? 'Edit Cash & Bank Expense' : 'New Cash & Bank Expense',
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
                ? _errorState()
                : _form(),
      );

  Widget _errorState() => Center(
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

  Widget _form() => Form(
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
                            const Text(
                              'Transaction Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (_readOnly) ...[
                              _notice(
                                'Approved expenses cannot be changed.',
                                error: false,
                              ),
                              const SizedBox(height: 14),
                            ],
                            _twoFields(_branchField(), _dateField()),
                            const SizedBox(height: 14),
                            _twoFields(_paymentModeField(), _transactionTypeField()),
                            const SizedBox(height: 14),
                            _amountField(),
                            const SizedBox(height: 14),
                            _attachmentSection(),
                            const SizedBox(height: 14),
                            _descriptionField(),
                            if (widget.isEdit &&
                                _controller.branchError.value.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _notice(
                                'Branch options could not be refreshed. The '
                                'existing branch is retained; changing it is '
                                'temporarily unavailable.',
                                error: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _saveButton(),
            ],
          ),
        ),
      );

  Widget _branchField() {
    final branches = _controller.branches.toList(growable: false);
    return DropdownButtonFormField<String>(
      initialValue: branches.any((branch) => branch.id == _branchId)
          ? _branchId
          : null,
      isExpanded: true,
      decoration: _decoration('Branch'),
      hint: const Text('Select branch'),
      items: [
        for (final branch in branches)
          DropdownMenuItem(
            value: branch.id,
            child: Text(branch.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _readOnly || _controller.branchError.value.isNotEmpty
          ? null
          : (value) => setState(() => _branchId = value),
      validator: (value) =>
          value == null || value.isEmpty ? 'Select a branch.' : null,
    );
  }

  Widget _dateField() => TextFormField(
        controller: _date,
        readOnly: true,
        onTap: _readOnly ? null : _pickDate,
        decoration: _decoration('Date').copyWith(
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        validator: (value) {
          if (DateFormat('dd/MM/yyyy').tryParseStrict(value ?? '') == null) {
            return 'Select a valid date.';
          }
          return null;
        },
      );

  Widget _paymentModeField() => DropdownButtonFormField<String>(
        initialValue: _paymentMode,
        isExpanded: true,
        decoration: _decoration('Payment Mode'),
        items: [
          const DropdownMenuItem(value: 'Cash', child: Text('Cash')),
          const DropdownMenuItem(value: 'Bank', child: Text('Bank')),
          if (_paymentMode == 'UPI')
            const DropdownMenuItem(
              value: 'UPI',
              child: Text('UPI (existing)'),
            ),
        ],
        onChanged: _readOnly
            ? null
            : (value) {
                if (value != null) setState(() => _paymentMode = value);
              },
      );

  Widget _transactionTypeField() => DropdownButtonFormField<String>(
        initialValue: _transactionType,
        isExpanded: true,
        decoration: _decoration('Transaction Type'),
        items: const [
          DropdownMenuItem(value: 'Expenses', child: Text('Expenses')),
          DropdownMenuItem(value: 'Income', child: Text('Income')),
        ],
        onChanged: _readOnly
            ? null
            : (value) {
                if (value != null) setState(() => _transactionType = value);
              },
      );

  Widget _amountField() => TextFormField(
        controller: _amount,
        readOnly: _readOnly,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        decoration: _decoration('Amount').copyWith(prefixText: '₹ '),
        validator: (value) {
          final amount = double.tryParse(value?.trim() ?? '');
          if (amount == null || !amount.isFinite || amount <= 0) {
            return 'Enter an amount greater than zero.';
          }
          return null;
        },
      );

  Widget _descriptionField() => TextFormField(
        controller: _description,
        readOnly: _readOnly,
        maxLines: 3,
        decoration: _decoration('Description (optional)'),
      );

  Widget _attachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attachments',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
        ),
        if (widget.isEdit) ...[
          const SizedBox(height: 4),
          Text(
            _attachments.isEmpty
                ? 'No attachments selected.'
                : 'Add files or remove existing attachments before saving.',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'PNG, JPG, or PDF · up to 5 files · max 5 MiB each',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _readOnly || _pickingAttachments ? null : _pickAttachments,
          icon: _pickingAttachments
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.attach_file),
          label: Text(_pickingAttachments ? 'Reading files...' : 'Choose files'),
        ),
        for (var index = 0; index < _attachments.length; index++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _attachments[index].mimeType == 'application/pdf'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.image_outlined,
              color: _green,
            ),
            title: Text(
              _attachments[index].name,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _readOnly
                ? null
                : IconButton(
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
        withData: true,
      );
      if (!mounted || result == null) return;
      if (_attachments.length + result.files.length > 5) {
        throw const FormatException('You can attach up to 5 files.');
      }
      final selected = <CashBankExpenseAttachment>[];
      for (final file in result.files) {
        if (file.size > _maxFileBytes) {
          throw FormatException('${file.name} exceeds the 5 MiB file limit.');
        }
        final mimeType = _mimeTypeForName(file.name);
        if (mimeType == null) {
          throw FormatException('Unsupported attachment type: ${file.name}');
        }
        final bytes = file.bytes ?? await file.xFile.readAsBytes();
        if (bytes.isEmpty || bytes.length > _maxFileBytes) {
          throw FormatException('Could not read a valid file: ${file.name}.');
        }
        selected.add(
          CashBankExpenseAttachment(
            name: file.name,
            mimeType: mimeType,
            data: 'data:$mimeType;base64,${base64Encode(bytes)}',
          ),
        );
      }
      if (mounted) setState(() => _attachments.addAll(selected));
    } catch (error) {
      if (mounted) setState(() => _attachmentError = error.toString());
    } finally {
      if (mounted) setState(() => _pickingAttachments = false);
    }
  }

  Widget _saveButton() => SafeArea(
        top: false,
        child: Obx(
          () {
            final blocked = _controller.isSaving.value ||
                _readOnly ||
                (widget.isEdit &&
                    (_existingExpense?.hasAttachmentField != true ||
                        _existingExpense?.hasValidAttachmentData != true));
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              color: Colors.white,
              child: ElevatedButton(
                onPressed: blocked ? null : _save,
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
                    : Text(widget.isEdit ? 'Save Changes' : 'Save'),
              ),
            );
          },
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final date = DateFormat('dd/MM/yyyy').parseStrict(_date.text.trim());
    final expense = CashBankExpense(
      id: _existingExpense?.id ?? '',
      organizationId: _existingExpense?.organizationId ?? '',
      branchId: _branchId ?? '',
      branch: _existingExpense?.branch ?? '',
      date: DateFormat('yyyy-MM-dd').format(date),
      paymentMode: _paymentMode,
      transactionType: _transactionType,
      amount: double.parse(_amount.text.trim()),
      description: _description.text.trim(),
      attachments: _attachments.toList(growable: false),
      hasAttachmentField: !widget.isEdit ||
          (_existingExpense?.hasAttachmentField ?? false),
      hasValidAttachmentData: !widget.isEdit ||
          (_existingExpense?.hasValidAttachmentData ?? false),
      approved: _existingExpense?.approved ?? false,
      createdAt: _existingExpense?.createdAt ?? '',
    );
    final saved = widget.isEdit
        ? await _controller.updateExpense(expense)
        : await _controller.createExpense(expense);
    if (saved && mounted) Get.back<bool>(result: true);
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
      setState(() => _date.text = DateFormat('dd/MM/yyyy').format(selected));
    }
  }

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

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _green),
        ),
      );

  Widget _notice(String message, {required bool error}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: error ? const Color(0xFFFFF1F0) : const Color(0xFFE7F3E4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: error ? const Color(0xFFF1C7C4) : const Color(0xFFC9E0C4),
          ),
        ),
        child: Text(
          message,
          style: TextStyle(color: error ? const Color(0xFFB3261E) : _ink),
        ),
      );

  String _displayDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _formatAmount(double value) =>
      NumberFormat('0.##').format(value);

  String? _mimeTypeForName(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'pdf' => 'application/pdf',
      _ => null,
    };
  }
}
