import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/loading&dispatch/loading_dispatch_controller.dart';
import '../../models/loading_dispatch.dart';
import '../../models/lookup_option.dart';

const _ink = Color(0xFF14342B);
const _muted = Color(0xFF5C6B66);
const _line = Color(0xFFE4EBE4);
const _green = Color(0xFF2D8135);

class LoadingDispatchFormView extends StatefulWidget {
  const LoadingDispatchFormView({
    super.key,
    required this.isEdit,
    this.dispatchId = '',
  });

  final bool isEdit;
  final String dispatchId;

  @override
  State<LoadingDispatchFormView> createState() =>
      _LoadingDispatchFormViewState();
}

class _LoadingDispatchFormViewState extends State<LoadingDispatchFormView> {
  final LoadingDispatchController _controller =
      Get.find<LoadingDispatchController>();
  final _formKey = GlobalKey<FormState>();
  final _dispatchNumber = TextEditingController();
  final _lorryNumber = TextEditingController();
  final _driverName = TextEditingController();
  final _driverMobile = TextEditingController();
  final List<_DispatchLineEditor> _lines = [];
  String? _customerId;
  LoadingDispatch? _existingDispatch;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _dispatchNumber.dispose();
    _lorryNumber.dispose();
    _driverName.dispose();
    _driverMobile.dispose();
    for (final line in _lines) {
      line.dispose();
    }
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
      final dispatch = await _controller.loadDispatchById(widget.dispatchId);
      if (!mounted) return;
      if (dispatch == null) {
        setState(() {
          _loading = false;
          _loadError = _controller.detailError.value.isNotEmpty
              ? _controller.detailError.value
              : 'Loading dispatch is unavailable.';
        });
        return;
      }
      _existingDispatch = dispatch;
      _dispatchNumber.text = dispatch.dispatchNumber;
      _customerId = dispatch.customerId;
      _lorryNumber.text = dispatch.lorryNumber;
      _driverName.text = dispatch.driverName;
      _driverMobile.text = dispatch.driverMobile;
      for (final line in dispatch.lines) {
        _lines.add(_DispatchLineEditor.fromLine(line));
      }
    } else {
      _lines.add(_DispatchLineEditor());
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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F6F4),
        appBar: AppBar(
          title: Text(
            widget.isEdit
                ? 'Edit Loading & Dispatch'
                : 'New Loading & Dispatch',
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
                      constraints: const BoxConstraints(maxWidth: 860),
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
                            _sectionTitle('Dispatch Details'),
                            const SizedBox(height: 14),
                            _twoFields(
                                _dispatchNumberField(), _customerField()),
                            const SizedBox(height: 14),
                            _twoFields(_lorryField(), _driverNameField()),
                            const SizedBox(height: 14),
                            _driverMobileField(),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Expanded(child: _sectionTitle('Loading Lines')),
                                OutlinedButton.icon(
                                  onPressed: _addLine,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Line'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            for (var index = 0; index < _lines.length; index++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == _lines.length - 1 ? 0 : 12,
                                ),
                                child: _lineCard(index, _lines[index]),
                              ),
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

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      );

  Widget _dispatchNumberField() => TextFormField(
        controller: _dispatchNumber,
        textCapitalization: TextCapitalization.characters,
        decoration: _decoration('Dispatch Number').copyWith(
          helperText: widget.isEdit
              ? null
              : 'Enter the number assigned for this dispatch.',
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter a dispatch number.'
            : null,
      );

  Widget _customerField() {
    final options = _withExistingOption(_controller.customers, _customerId);
    return DropdownButtonFormField<String>(
      initialValue: _contains(options, _customerId) ? _customerId : null,
      isExpanded: true,
      decoration: _decoration('Customer'),
      hint: const Text('Select customer'),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option.id,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => setState(() => _customerId = value),
      validator: (value) =>
          value == null || value.isEmpty ? 'Select a customer.' : null,
    );
  }

  Widget _lorryField() => TextFormField(
        controller: _lorryNumber,
        textCapitalization: TextCapitalization.characters,
        decoration: _decoration('Lorry Number'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter a lorry number.'
            : null,
      );

  Widget _driverNameField() => TextFormField(
        controller: _driverName,
        textCapitalization: TextCapitalization.words,
        decoration: _decoration('Driver Name'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter the driver name.'
            : null,
      );

  Widget _driverMobileField() => TextFormField(
        controller: _driverMobile,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
        ],
        decoration: _decoration('Driver Mobile'),
        validator: (value) {
          if (!RegExp(r'^\+?[0-9][0-9\s-]{5,17}$')
              .hasMatch(value?.trim() ?? '')) {
            return 'Enter a valid driver mobile number.';
          }
          return null;
        },
      );

  Widget _lineCard(int index, _DispatchLineEditor line) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBF9),
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Loading Line ${index + 1}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove loading line ${index + 1}',
                  onPressed:
                      _lines.length == 1 ? null : () => _removeLine(line),
                  icon: const Icon(Icons.delete_outline, color: _muted),
                ),
              ],
            ),
            _twoFields(_branchField(line), _lineDateField(line)),
            const SizedBox(height: 12),
            _twoFields(_itemField(line), _bharthiField(line)),
            const SizedBox(height: 12),
            _quantityField(line),
          ],
        ),
      );

  Widget _branchField(_DispatchLineEditor line) {
    final options = _withExistingOption(_controller.branches, line.branchId);
    return DropdownButtonFormField<String>(
      initialValue: _contains(options, line.branchId) ? line.branchId : null,
      isExpanded: true,
      decoration: _decoration('Branch'),
      hint: const Text('Select branch'),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option.id,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => setState(() => line.branchId = value),
      validator: (value) =>
          value == null || value.isEmpty ? 'Select a branch.' : null,
    );
  }

  Widget _itemField(_DispatchLineEditor line) {
    final options = _withExistingOption(_controller.items, line.itemId);
    return DropdownButtonFormField<String>(
      initialValue: _contains(options, line.itemId) ? line.itemId : null,
      isExpanded: true,
      decoration: _decoration('Item'),
      hint: const Text('Select item'),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option.id,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => setState(() => line.itemId = value),
      validator: (value) =>
          value == null || value.isEmpty ? 'Select an item.' : null,
    );
  }

  Widget _lineDateField(_DispatchLineEditor line) => TextFormField(
        controller: line.date,
        readOnly: true,
        onTap: () => _pickLineDate(line),
        decoration: _decoration('Date').copyWith(
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        validator: (value) =>
            DateFormat('dd/MM/yyyy').tryParseStrict(value ?? '') == null
                ? 'Select a valid date.'
                : null,
      );

  Widget _bharthiField(_DispatchLineEditor line) => TextFormField(
        controller: line.bharthi,
        textCapitalization: TextCapitalization.sentences,
        decoration: _decoration('Gunny Bag (Bharathi)'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter Gunny Bag (Bharathi).'
            : null,
      );

  Widget _quantityField(_DispatchLineEditor line) => TextFormField(
        controller: line.quantity,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        decoration: _decoration('Quantity'),
        validator: (value) {
          final quantity = double.tryParse(value?.trim() ?? '');
          if (quantity == null || !quantity.isFinite || quantity <= 0) {
            return 'Enter a quantity greater than zero.';
          }
          return null;
        },
      );

  Widget _saveButton() => SafeArea(
        top: false,
        child: Obx(
          () => Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            color: Colors.white,
            child: ElevatedButton(
              onPressed: _controller.isSaving.value ? null : _save,
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
                  : Text(widget.isEdit ? 'Save Changes' : 'Save Draft'),
            ),
          ),
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final lineModels = <LoadingDispatchLine>[];
    for (final line in _lines) {
      final parsedDate =
          DateFormat('dd/MM/yyyy').parseStrict(line.date.text.trim());
      final quantity = double.parse(line.quantity.text.trim());
      lineModels.add(
        LoadingDispatchLine(
          id: line.id,
          branchId: line.branchId ?? '',
          date: DateFormat('yyyy-MM-dd').format(parsedDate),
          itemId: line.itemId ?? '',
          bharthi: line.bharthi.text.trim(),
          quantity: quantity,
          loadedQuantity: line.loadedQuantity,
          pendingQuantity:
              (quantity - line.loadedQuantity).clamp(0, quantity).toDouble(),
        ),
      );
    }
    final dispatch = LoadingDispatch(
      id: _existingDispatch?.id ?? '',
      dispatchNumber: _dispatchNumber.text.trim(),
      customerId: _customerId ?? '',
      lorryNumber: _lorryNumber.text.trim(),
      driverName: _driverName.text.trim(),
      driverMobile: _driverMobile.text.trim(),
      dispatchDate: lineModels.first.date,
      dispatchStatus: _existingDispatch?.dispatchStatus ?? 'Draft',
      invoiceGenerated: _existingDispatch?.invoiceGenerated ?? false,
      lines: lineModels,
    );
    final saved = await _controller.saveDispatch(dispatch);
    if (saved && mounted) Get.back<bool>(result: true);
  }

  Future<void> _pickLineDate(_DispatchLineEditor line) async {
    final current = DateFormat('dd/MM/yyyy').tryParseStrict(line.date.text) ??
        DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (selected != null && mounted) {
      setState(
        () => line.date.text = DateFormat('dd/MM/yyyy').format(selected),
      );
    }
  }

  void _addLine() => setState(() => _lines.add(_DispatchLineEditor()));

  void _removeLine(_DispatchLineEditor line) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
  }

  Widget _twoFields(Widget first, Widget second) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, const SizedBox(height: 12), second],
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

  List<LookupOption> _withExistingOption(
    List<LookupOption> options,
    String? selectedId,
  ) {
    final result = options.toList(growable: true);
    if (selectedId != null &&
        selectedId.isNotEmpty &&
        result.every((option) => option.id != selectedId)) {
      result.add(LookupOption(id: selectedId, label: selectedId));
    }
    return result;
  }

  bool _contains(List<LookupOption> options, String? id) =>
      id != null && options.any((option) => option.id == id);
}

class _DispatchLineEditor {
  String id = '';
  String? branchId;
  String? itemId;
  double loadedQuantity = 0;
  late final TextEditingController date;
  late final TextEditingController bharthi;
  late final TextEditingController quantity;

  _DispatchLineEditor() {
    date = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(DateTime.now()),
    );
    bharthi = TextEditingController();
    quantity = TextEditingController();
  }

  _DispatchLineEditor.fromLine(LoadingDispatchLine line) {
    id = line.id;
    branchId = line.branchId;
    itemId = line.itemId;
    loadedQuantity = line.loadedQuantity;
    date = TextEditingController(text: _displayDate(line.date));
    bharthi = TextEditingController(text: line.bharthi);
    quantity = TextEditingController(
      text: line.quantity == 0 ? '' : line.quantity.toString(),
    );
  }

  void dispose() {
    date.dispose();
    bharthi.dispose();
    quantity.dispose();
  }

  static String _displayDate(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? value : DateFormat('dd/MM/yyyy').format(date);
  }
}
