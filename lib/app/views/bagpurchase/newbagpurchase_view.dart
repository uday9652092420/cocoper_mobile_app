import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../controllers/bagpurchase/bag_purchase_controller.dart';
import '../../helpers/flutter_toast.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/bag_purchase.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _kFieldFill = Color(0xFFF6F8F6);

class NewBagPurchaseView extends StatefulWidget {
  const NewBagPurchaseView({super.key, this.purchase});

  final BagPurchase? purchase;

  @override
  State<NewBagPurchaseView> createState() => _NewBagPurchaseViewState();
}

class _NewBagPurchaseViewState extends State<NewBagPurchaseView> {
  final BagPurchaseController _controller = Get.find<BagPurchaseController>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final List<_BagPurchaseLineEditor> _lines = [];

  String? _supplierId;
  String? _branchId;
  bool get _isEditing => widget.purchase != null;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final purchase = widget.purchase;
    if (purchase == null) {
      _lines.add(_BagPurchaseLineEditor());
      _loadInitialLookups();
    } else {
      _dateController.text = _displayDate(purchase.purchaseDate);
      _supplierId = purchase.supplierId;
      _branchId = purchase.branchId;
      _remarksController.text = purchase.remarks;
      for (final line in purchase.lines) {
        _lines.add(
          _BagPurchaseLineEditor(
            bagId: line.gunnyBagId,
            quantity: line.quantity,
            rate: line.rate,
          ),
        );
      }
      if (_lines.isEmpty) _lines.add(_BagPurchaseLineEditor());
      _controller.loadLookups(branchId: purchase.branchId);
    }
  }

  Future<void> _loadInitialLookups() async {
    final branchId = await SharedPrefsHelper.getString(
      SharedPrefsHelper.selectedBranchId,
    );
    if (mounted && branchId.isNotEmpty) {
      setState(() => _branchId = branchId);
    }
    await _controller.loadLookups(branchId: branchId);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _remarksController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE9F3E6), Color(0xFFFDFEFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBackendNotice(),
                          const SizedBox(height: 12),
                          Obx(
                            () => _controller.lookupError.value.isEmpty
                                ? const SizedBox.shrink()
                                : _buildLookupRetry(),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailsCard(),
                          const SizedBox(height: 12),
                          _buildRemarksCard(),
                          const SizedBox(height: 12),
                          _buildLinesCard(),
                          const SizedBox(height: 12),
                          _buildTotals(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Get.back<void>(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kLine),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 17,
                color: _kInk,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isEditing ? 'Edit Bag Purchase' : 'New Bag Purchase',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0D9A8)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 19, color: Color(0xFF8A5B00)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Line amounts and purchase totals are recalculated by the server '
              'when the purchase is saved.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: _kInk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLookupRetry() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0D9A8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _controller.lookupError.value,
              style: const TextStyle(fontSize: 12, color: _kInk),
            ),
          ),
          TextButton(
            onPressed: _controller.isLoadingLookups.value
                ? null
                : () => _controller.loadLookups(branchId: _branchId ?? ''),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return _card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 600;
          final fieldWidth =
              wide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: fieldWidth,
                child: _buildDateField(),
              ),
              SizedBox(
                width: fieldWidth,
                child: Obx(
                  () => _buildDropdown(
                    label: 'Supplier',
                    value: _supplierId,
                    options: _controller.suppliers,
                    hint: 'Select supplier',
                    required: true,
                    onChanged: (value) => setState(() => _supplierId = value),
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: Obx(
                  () => _buildDropdown(
                    label: 'Branch',
                    value: _branchId,
                    options: _controller.branches,
                    hint: 'Select branch',
                    required: true,
                    onChanged: (value) => setState(() => _branchId = value),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Purchase Date', required: true),
        const SizedBox(height: 6),
        TextField(
          controller: _dateController,
          readOnly: true,
          onTap: _pickDate,
          decoration: _inputDecoration(
            hint: 'dd/MM/yyyy',
            suffixIcon: const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: _kMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemarksCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Remarks'),
          const SizedBox(height: 6),
          TextField(
            controller: _remarksController,
            minLines: 1,
            maxLines: 3,
            textAlign: TextAlign.start,
            decoration: _inputDecoration(hint: 'Enter remarks'),
          ),
        ],
      ),
    );
  }

  Widget _buildLinesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bag purchase lines',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 12),
          Obx(() {
            if (_controller.isLoadingLookups.value &&
                _controller.gunnyBags.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(color: _kGreen),
                ),
              );
            }
            if (_controller.lookupError.value.isNotEmpty &&
                _controller.gunnyBags.isEmpty) {
              return _buildLookupError();
            }
            return Column(
              children: [
                for (var index = 0; index < _lines.length; index++)
                  _buildLine(index, _controller.gunnyBags),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLookupError() {
    return Text(
      _controller.lookupError.value,
      style: const TextStyle(fontSize: 13, color: _kMuted),
    );
  }

  Widget _buildLine(int index, List<BagPurchaseLookup> bags) {
    final line = _lines[index];
    return Container(
      margin: EdgeInsets.only(bottom: index == _lines.length - 1 ? 0 : 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kLine),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 600;
          final children = <Widget>[
            _buildDropdown(
              label: 'Bag',
              value: line.bagId,
              options: bags,
              hint: 'Select bag',
              required: true,
              onChanged: (value) {
                setState(() {
                  line.bagId = value;
                  if (value != null) {
                    final bag =
                        bags.firstWhereOrNull((option) => option.id == value);
                    if (bag != null) {
                      line.rate.text = _initialNumber(bag.ratePerBag);
                    }
                  }
                });
              },
            ),
            _buildNumberField(
              label: 'Qty',
              controller: line.quantity,
              onChanged: (_) => setState(() {}),
            ),
            _buildNumberField(
              label: 'Rate',
              controller: line.rate,
              onChanged: (_) => setState(() {}),
            ),
            _buildAmount(line.amount),
            Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                tooltip: 'Remove line',
                onPressed: _lines.length == 1 ? null : () => _removeLine(index),
                icon: const Icon(Icons.delete_outline, color: _kMuted),
              ),
            ),
          ];
          if (wide) {
            final widths = [
              constraints.maxWidth * 0.37,
              constraints.maxWidth * 0.14,
              constraints.maxWidth * 0.14,
              constraints.maxWidth * 0.18,
              constraints.maxWidth * 0.08,
            ];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < children.length; i++)
                  SizedBox(
                    width: widths[i],
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 4 ? 0 : 8),
                      child: children[i],
                    ),
                  ),
              ],
            );
          }
          return Column(
            children: [
              children[0],
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: children[1]),
                  const SizedBox(width: 8),
                  Expanded(child: children[2]),
                  const SizedBox(width: 8),
                  Expanded(child: children[3]),
                  children[4],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.start,
          textDirection: TextDirection.ltr,
          onChanged: onChanged,
          decoration: _inputDecoration(hint: '0'),
        ),
      ],
    );
  }

  Widget _buildAmount(double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Amount'),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F6F3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kLine),
          ),
          child: Text(
            _currency(amount),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotals() {
    final quantity = _lines.fold<double>(
      0,
      (sum, line) => sum + line.quantityValue,
    );
    final amount = _lines.fold<double>(
      0,
      (sum, line) => sum + line.amount,
    );
    return _card(
      child: Wrap(
        spacing: 20,
        runSpacing: 6,
        children: [
          Text('Lines: ${_lines.length}', style: _summaryStyle),
          Text('Total Quantity: ${_number(quantity)}', style: _summaryStyle),
          Text('Lines Total: ${_currency(amount)}', style: _summaryStyle),
        ],
      ),
    );
  }

  TextStyle get _summaryStyle => const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: _kMuted,
      );

  Widget _buildActions() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _kLine)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Obx(
                      () => OutlinedButton.icon(
                        onPressed: _controller.isSaving.value ? null : _addLine,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Line'),
                      ),
                    ),
                    if (!_isEditing)
                      Obx(
                        () => OutlinedButton(
                          onPressed:
                              _controller.isSaving.value ? null : _saveAndNew,
                          child: const Text('Save & New'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Obx(
                  () => ElevatedButton(
                    onPressed: _controller.isSaving.value ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _kGreen.withValues(alpha: 0.6),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _controller.isSaving.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEditing ? 'Save Changes' : 'Save',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<BagPurchaseLookup> options,
    required String hint,
    required ValueChanged<String?> onChanged,
    bool required = false,
  }) {
    final selectedValue =
        options.any((option) => option.id == value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, required: required),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedValue,
          isExpanded: true,
          decoration: _inputDecoration(hint: hint),
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option.id,
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: options.isEmpty ? null : onChanged,
        ),
      ],
    );
  }

  Widget _fieldLabel(String label, {bool required = false}) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _kMuted,
        ),
        children: [
          TextSpan(text: label),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _kFieldFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kGreen),
      ),
    );
  }

  Future<void> _pickDate() async {
    final initialDate =
        DateFormat('dd/MM/yyyy').tryParse(_dateController.text) ??
            DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    setState(() {
      _dateController.text = DateFormat('dd/MM/yyyy').format(date);
    });
  }

  void _addLine() {
    setState(() => _lines.add(_BagPurchaseLineEditor()));
  }

  void _removeLine(int index) {
    final line = _lines.removeAt(index);
    line.dispose();
    setState(() {});
  }

  Future<void> _save() => _submit(saveAndNew: false);

  Future<void> _saveAndNew() => _submit(saveAndNew: true);

  Future<void> _submit({required bool saveAndNew}) async {
    final date = DateFormat('dd/MM/yyyy').tryParse(_dateController.text);
    if (date == null ||
        _supplierId == null ||
        _branchId == null ||
        _lines.isEmpty ||
        _lines.any(
          (line) =>
              line.bagId == null ||
              line.quantity.text.trim().isEmpty ||
              !line.quantityValue.isFinite ||
              line.quantityValue <= 0 ||
              line.rate.text.trim().isEmpty ||
              double.tryParse(line.rate.text.trim()) == null ||
              !line.rateValue.isFinite ||
              line.rateValue < 0,
        )) {
      errorToast(
        'Enter a valid purchase date, supplier, branch, bag, quantity, and rate.',
      );
      return;
    }
    final lines = _lines
        .map(
          (line) => BagPurchaseLine(
            gunnyBagId: line.bagId!,
            quantity: line.quantityValue,
            rate: line.rateValue,
            amount: line.amount,
          ),
        )
        .toList(growable: false);
    final isoDate = DateFormat('yyyy-MM-dd').format(date);

    final saved = _isEditing
        ? await _controller.updatePurchase(
            id: widget.purchase!.id,
            date: isoDate,
            supplierId: _supplierId!,
            branchId: _branchId!,
            remarks: _remarksController.text.trim(),
            lines: lines,
          )
        : await _controller.createPurchase(
            date: isoDate,
            supplierId: _supplierId!,
            branchId: _branchId!,
            remarks: _remarksController.text.trim(),
            lines: lines,
            saveAndNew: saveAndNew,
          );

    if (!saved || !mounted) return;
    if (saveAndNew && !_isEditing) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
        _supplierId = null;
        _remarksController.clear();
        for (final line in _lines) {
          line.dispose();
        }
        _lines
          ..clear()
          ..add(_BagPurchaseLineEditor());
      });
      return;
    }
    Get.back<void>();
  }

  static String _displayDate(String value) {
    final date = BagPurchase.parsePurchaseDate(value);
    return date == null ? value : DateFormat('dd/MM/yyyy').format(date);
  }

  static String _initialNumber(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  static String _currency(double value) =>
      '₹${NumberFormat('#,##0.##').format(value)}';

  static String _number(double value) => NumberFormat('#,##0.##').format(value);
}

class _BagPurchaseLineEditor {
  _BagPurchaseLineEditor({
    this.bagId,
    double quantity = 0,
    double rate = 0,
  })  : quantity = TextEditingController(text: _formatInitial(quantity)),
        rate = TextEditingController(text: _formatInitial(rate));

  String? bagId;
  final TextEditingController quantity;
  final TextEditingController rate;

  static String _formatInitial(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  double get quantityValue => double.tryParse(quantity.text.trim()) ?? 0;
  double get rateValue => double.tryParse(rate.text.trim()) ?? 0;
  double get amount => quantityValue * rateValue;

  void dispose() {
    quantity.dispose();
    rate.dispose();
  }
}
