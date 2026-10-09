import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/directsales/direct_sales_controller.dart';
import '../../controllers/salesorders/sales_order_controller.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/direct_sale.dart';
import '../../models/lookup_option.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _kMint = Color(0xFFE7F3E4);
const _kFieldFill = Color(0xFFF6F8F6);

class NewDirectSaleView extends StatefulWidget {
  const NewDirectSaleView({super.key});

  @override
  State<NewDirectSaleView> createState() => _NewDirectSaleViewState();
}

class _NewDirectSaleViewState extends State<NewDirectSaleView> {
  final DirectSalesController _controller = Get.find<DirectSalesController>();
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final List<_SaleLineEditor> _lines = [];
  final List<_BagEditor> _bags = [];

  String? _customerId;
  String? _branchId;
  String _mode = SalesOrderController.modeTonage;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _lines.add(_SaleLineEditor());
    _bags.add(_BagEditor());
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    await _controller.loadCreateLookups();
    if (!mounted) return;
    final branch = await SharedPrefsHelper.getString(
      SharedPrefsHelper.selectedBranchId,
    );
    setState(() {
      if (_controller.branches.any((option) => option.id == branch)) {
        _branchId = branch;
      } else if (_controller.branches.length == 1) {
        _branchId = _controller.branches.first.id;
      }
    });
  }

  @override
  void dispose() {
    _dateController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    for (final bag in _bags) {
      bag.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(
        child: Container(
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
                  child: Obx(
                    () => _controller.isLoadingLookups.value
                        ? const Center(
                            child: CircularProgressIndicator(color: _kGreen),
                          )
                        : _controller.hasLookupError.value
                            ? _buildLookupError()
                            : _buildFormBody(),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add New Sales',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Create a direct sales invoice',
                  style: TextStyle(fontSize: 13, color: _kMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormBody() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailsCard(),
            const SizedBox(height: 12),
            _buildLinesCard(),
            const SizedBox(height: 12),
            _buildBagsCard(),
            const SizedBox(height: 12),
            _buildChargesCard(),
            const SizedBox(height: 12),
            _buildTotalCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Direct Sale No'),
          const SizedBox(height: 6),
          _readOnlyField('Assigned by server on save'),
          const SizedBox(height: 14),
          _label('Invoice Date', required: true),
          const SizedBox(height: 6),
          TextFormField(
            controller: _dateController,
            readOnly: true,
            onTap: _pickDate,
            validator: (value) => value == null || value.isEmpty
                ? 'Select an invoice date.'
                : null,
            decoration: _decoration(
              hint: 'dd/MM/yyyy',
              suffix: const Icon(Icons.date_range_outlined, color: _kMuted),
            ),
          ),
          const SizedBox(height: 14),
          _label('Customer', required: true),
          const SizedBox(height: 6),
          _dropdown(
            value: _customerId,
            hint: 'Select customer',
            options: _controller.customers,
            onChanged: (value) => setState(() => _customerId = value),
          ),
          const SizedBox(height: 14),
          _label('Sales Order No'),
          const SizedBox(height: 6),
          _readOnlyField(
            _customerId == null
                ? 'Select customer first'
                : 'Order linking unavailable',
          ),
          const SizedBox(height: 14),
          _label('Branch', required: true),
          const SizedBox(height: 6),
          _dropdown(
            value: _branchId,
            hint: 'Select branch',
            options: _controller.branches,
            onChanged: (value) => setState(() => _branchId = value),
          ),
          const SizedBox(height: 14),
          _label('Quantity Mode'),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildModeOption('Tonnage'),
              const SizedBox(width: 10),
              _buildModeOption('Lessing'),
            ],
          ),
          const SizedBox(height: 8),
          Tooltip(
            message:
                'Pieces percentage is unavailable until its Direct Sales calculation is verified.',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(value: false, onChanged: null),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pieces %',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _kMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(String label) {
    final mode = label == 'Lessing'
        ? SalesOrderController.modeLessing
        : SalesOrderController.modeTonage;
    final selected = _mode == mode;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mode = mode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? _kMint : _kFieldFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _kGreen : _kLine,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 16,
                color: selected ? _kGreen : _kMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? _kGreen : _kInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinesCard() {
    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Sales Line Items',
            addLabel: 'Add Line',
            onAdd: () => setState(() => _lines.add(_SaleLineEditor())),
          ),
          const Divider(height: 1, color: _kLine),
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add at least one item to continue.'),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (var index = 0; index < _lines.length; index++)
                    _buildLineEditor(index),
                ],
              ),
            ),
          const Divider(height: 1, color: _kLine),
          Padding(
            padding: const EdgeInsets.all(14),
            child: _totalRow('Total Sales Line Amount', _salesLinesTotal()),
          ),
        ],
      ),
    );
  }

  Widget _buildLineEditor(int index) {
    final line = _lines[index];
    final actualQuantity = _actualQuantity(line);
    final amount = _salesAmount(line);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _label('Item', required: true)),
              IconButton(
                tooltip: 'Remove item',
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeLine(index),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          _dropdown(
            value: line.itemId.isEmpty ? null : line.itemId,
            hint: 'Select item',
            options: _controller.items,
            onChanged: (value) => setState(() => line.itemId = value ?? ''),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  label: _mode == SalesOrderController.modeLessing
                      ? 'Quantity (pieces)'
                      : 'Quantity (tons)',
                  controller: line.quantity,
                  required: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberField(
                  label: _mode == SalesOrderController.modeLessing
                      ? 'Discount (pieces)'
                      : 'Discount (kg)',
                  controller: line.discount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  label: 'Pieces',
                  controller: line.pieces,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberField(
                  label: 'Sales Price',
                  controller: line.salesPrice,
                  required: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _computed('Actual Quantity', _format(actualQuantity)),
              ),
              const SizedBox(width: 10),
              Expanded(child: _computed('Sales Amount', _money(amount))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBagsCard() {
    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Gunny Bags',
            addLabel: 'Add Bag',
            onAdd: _controller.gunnyBagTypes.isEmpty
                ? null
                : () => setState(() => _bags.add(_BagEditor())),
          ),
          const Divider(height: 1, color: _kLine),
          if (_controller.gunnyBagTypes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No gunny bag types are available.',
                style: TextStyle(fontSize: 13, color: _kMuted),
              ),
            )
          else if (_bags.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No gunny bags added.',
                style: TextStyle(fontSize: 13, color: _kMuted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (var index = 0; index < _bags.length; index++)
                    _buildBagEditor(index),
                ],
              ),
            ),
          const Divider(height: 1, color: _kLine),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _totalRow(
                  'Total Gunny Bags Quantity',
                  _gunnyBagsQuantity(),
                  currency: false,
                ),
                const SizedBox(height: 8),
                _totalRow('Total Gunny Bag Line Amount', _gunnyBagsTotal()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Additional Charges',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 12),
          _label('Loading Charges'),
          const SizedBox(height: 6),
          _readOnlyField(
            'Unavailable',
            helperText: 'Direct Sales charge payload format is unverified.',
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return _card(
      child: Column(
        children: [
          _totalRow('Total Sales Lines Amount', _salesLinesTotal()),
          const SizedBox(height: 8),
          _totalRow('Charges Total', 0),
          const Divider(height: 22, color: _kLine),
          _totalRow('Invoice Total', _invoiceTotal(), emphasize: true),
        ],
      ),
    );
  }

  Widget _totalRow(
    String label,
    double value, {
    bool emphasize = false,
    bool currency = true,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: emphasize ? 15 : 13,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: emphasize ? _kInk : _kMuted,
            ),
          ),
        ),
        Text(
          currency ? _money(value) : _format(value),
          style: TextStyle(
            fontSize: emphasize ? 17 : 13,
            fontWeight: FontWeight.w800,
            color: emphasize ? _kGreen : _kInk,
          ),
        ),
      ],
    );
  }

  Widget _readOnlyField(String value, {String? helperText}) {
    return TextFormField(
      initialValue: value,
      enabled: false,
      style: const TextStyle(fontSize: 14, color: _kMuted),
      decoration: _decoration().copyWith(helperText: helperText),
    );
  }

  Widget _buildBagEditor(int index) {
    final bag = _bags[index];
    final amount = _number(bag.quantity) * _number(bag.rate);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Bag Type',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              IconButton(
                tooltip: 'Remove bag line',
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeBag(index),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: bag.bagTypeId.isEmpty ? null : bag.bagTypeId,
            isExpanded: true,
            hint: const Text('Select bag type'),
            decoration: _decoration(),
            items: _controller.gunnyBagTypes
                .map((option) => DropdownMenuItem<String>(
                      value: option.id,
                      child:
                          Text(option.label, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (id) {
              final selected = _controller.gunnyBagTypes.firstWhereOrNull(
                (option) => option.id == id,
              );
              setState(() {
                bag.bagTypeId = id ?? '';
                bag.bharthiTypeId = selected?.bharthiTypeId ?? '';
                bag.bagBharthi = selected?.bagBharthi ?? 0;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _computed('Bag Bharthi', _format(bag.bagBharthi)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberField(
                  label: 'Quantity',
                  controller: bag.quantity,
                  required: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  label: 'Rate',
                  controller: bag.rate,
                  required: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _computed('Amount', _money(amount))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Get.back<void>(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kGreen,
                  side: const BorderSide(color: _kGreen),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Obx(
                () => ElevatedButton(
                  onPressed: _controller.isSaving.value ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _kGreen.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                      _controller.isSaving.value ? 'Saving…' : 'Save Sales'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLookupError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(_controller.lookupError.value, textAlign: TextAlign.center),
            TextButton(onPressed: _loadLookups, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    String title, {
    VoidCallback? onAdd,
    String addLabel = 'Add',
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _kInk)),
          ),
          if (onAdd != null)
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
            ),
        ],
      ),
    );
  }

  Widget _card(
      {required Widget child,
      EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: child,
    );
  }

  Widget _label(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w700, color: _kInk),
        children: required
            ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
            : const [],
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required String hint,
    required List<LookupOption> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      validator: (selected) =>
          selected == null || selected.isEmpty ? 'Required.' : null,
      decoration: _decoration(),
      hint: Text(hint, overflow: TextOverflow.ellipsis),
      items: options
          .map((option) => DropdownMenuItem<String>(
                value: option.id,
                child: Text(option.label, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          onChanged: (_) => setState(() {}),
          validator: required
              ? (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null || !parsed.isFinite || parsed <= 0) {
                    return 'Enter a value above zero.';
                  }
                  return null;
                }
              : (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || !parsed.isFinite || parsed < 0) {
                    return 'Enter zero or more.';
                  }
                  return null;
                },
          decoration: _decoration(),
        ),
      ],
    );
  }

  Widget _computed(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
              color: _kMint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8)),
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _kInk)),
        ),
      ],
    );
  }

  InputDecoration _decoration({String? hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffix,
      isDense: true,
      filled: true,
      fillColor: _kFieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kLine)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kLine)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kGreen, width: 1.2)),
    );
  }

  Future<void> _pickDate() async {
    final initial = DateFormat('dd/MM/yyyy').tryParse(_dateController.text) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(
          () => _dateController.text = DateFormat('dd/MM/yyyy').format(picked));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      _showValidation('Add at least one sales line.');
      return;
    }

    for (final line in _lines) {
      if (line.itemId.isEmpty) {
        _showValidation('Select an item for every sales line.');
        return;
      }
      if (_actualQuantity(line) <= 0) {
        _showValidation('Each line must have a positive actual quantity.');
        return;
      }
    }
    for (final bag in _bags) {
      if (bag.bagTypeId.isEmpty ||
          _number(bag.quantity) <= 0 ||
          _number(bag.rate) <= 0) {
        _showValidation('Complete every gunny bag line or remove it.');
        return;
      }
    }

    final parsedDate =
        DateFormat('dd/MM/yyyy').parseStrict(_dateController.text);
    final saved = await _controller.createDirectSale(
      customerId: _customerId!,
      branchId: _branchId!,
      invoiceDate: DateFormat('yyyy-MM-dd').format(parsedDate),
      mode: _mode,
      lines: _lines.map(_buildLine).toList(),
      gunnyBags: _bags.map(_buildBag).toList(),
    );
    if (saved && mounted) Get.back<dynamic>(result: true);
  }

  DirectSaleLine _buildLine(_SaleLineEditor editor) {
    final actual = _actualQuantity(editor);
    final amount = _salesAmount(editor);
    final pieces = _number(editor.pieces);
    return DirectSaleLine(
      itemId: editor.itemId,
      quantity: _number(editor.quantity),
      discount: _number(editor.discount),
      piecesPercentage: 0,
      pieces: pieces,
      actualQuantity: actual,
      salesPrice: _number(editor.salesPrice),
      salesAmount: amount,
      baseCost: SalesOrderController.calculateBaseCost(amount, pieces),
    );
  }

  DirectSaleGunnyBag _buildBag(_BagEditor editor) {
    final quantity = _number(editor.quantity);
    final rate = _number(editor.rate);
    return DirectSaleGunnyBag(
      bagTypeId: editor.bagTypeId,
      bharthiTypeId: editor.bharthiTypeId,
      bagBharthi: editor.bagBharthi,
      quantity: quantity,
      rate: rate,
      amount: quantity * rate,
    );
  }

  double _actualQuantity(_SaleLineEditor editor) {
    return SalesOrderController.calculateActualQuantity(
      mode: _mode,
      quantity: _number(editor.quantity),
      discount: _number(editor.discount),
      piecesPercentage: 0,
    );
  }

  double _salesAmount(_SaleLineEditor editor) {
    return SalesOrderController.calculateSaleAmount(
      _number(editor.salesPrice),
      _actualQuantity(editor),
    );
  }

  double _invoiceTotal() {
    return SalesOrderController.roundValue(
      _salesLinesTotal() + _gunnyBagsTotal(),
      2,
    );
  }

  double _salesLinesTotal() {
    return _lines.fold<double>(0, (sum, line) => sum + _salesAmount(line));
  }

  double _gunnyBagsQuantity() {
    return _bags.fold<double>(
      0,
      (sum, bag) => sum + _number(bag.quantity),
    );
  }

  double _gunnyBagsTotal() {
    return _bags.fold<double>(
      0,
      (sum, bag) => sum + _number(bag.quantity) * _number(bag.rate),
    );
  }

  double _number(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim());
    return value != null && value.isFinite ? value : 0;
  }

  String _format(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _money(double value) {
    return '₹${NumberFormat('#,##,##0.00', 'en_IN').format(value)}';
  }

  void _removeLine(int index) {
    final line = _lines.removeAt(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  void _removeBag(int index) {
    final bag = _bags.removeAt(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => bag.dispose());
  }

  void _showValidation(String message) {
    Get.snackbar('Check sales details', message,
        snackPosition: SnackPosition.BOTTOM);
  }
}

class _SaleLineEditor {
  String itemId = '';
  final quantity = TextEditingController();
  final discount = TextEditingController();
  final pieces = TextEditingController();
  final salesPrice = TextEditingController();

  void dispose() {
    quantity.dispose();
    discount.dispose();
    pieces.dispose();
    salesPrice.dispose();
  }
}

class _BagEditor {
  String bagTypeId = '';
  String bharthiTypeId = '';
  double bagBharthi = 0;
  final quantity = TextEditingController();
  final rate = TextEditingController();

  void dispose() {
    quantity.dispose();
    rate.dispose();
  }
}
