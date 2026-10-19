import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../controllers/directsales/direct_sales_controller.dart';
import '../../controllers/salesorders/sales_order_controller.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/direct_sale.dart';
import '../../models/lookup_option.dart';
import '../../theme/app_theme.dart';

const _kInk = AppColors.textDefaultLight;
const _kMuted = AppColors.textLightGrayLight;
const _kLine = AppColors.borderLightGrayLight;
const _kGreen = AppColors.primaryLight;
const _kMint = AppColors.surfaceTint;
const _kFieldFill = AppColors.fieldFill;

class NewDirectSaleView extends StatefulWidget {
  const NewDirectSaleView({super.key, this.sale});

  final DirectSale? sale;

  @override
  State<NewDirectSaleView> createState() => _NewDirectSaleViewState();
}

class _NewDirectSaleViewState extends State<NewDirectSaleView> {
  final DirectSalesController _controller = Get.find<DirectSalesController>();
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _additionalChargesController = TextEditingController();
  final _loadingChargesController = TextEditingController();
  final List<_SaleLineEditor> _lines = [];
  final List<_BagEditor> _bags = [];

  String? _customerId;
  String? _branchId;
  late String _mode;
  bool _piecesPercentageEnabled = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.sale?.mode == SalesOrderController.modeLessing
        ? SalesOrderController.modeLessing
        : SalesOrderController.modeTonage;
    _piecesPercentageEnabled = _mode == SalesOrderController.modeTonage &&
        (widget.sale?.lines.any((line) => line.piecesPercentage > 0) ?? false);
    if (widget.sale != null) {
      _customerId = widget.sale!.customerId;
      _branchId = widget.sale!.branchId;
      _dateController.text = _formatInvoiceDate(widget.sale!.invoiceDate);
      _controller.lastCreatedDirectSaleNo.value = widget.sale!.directSaleNo;
      _seedFromSale(widget.sale!);
    } else {
      _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
      _controller.lastCreatedDirectSaleNo.value = '';
      _lines.add(_SaleLineEditor());
      _bags.add(_BagEditor());
      _loadPreviewNumber();
    }
    _loadLookups();
  }

  Future<void> _loadPreviewNumber() async {
    final preview = await _controller.generateDirectSaleNumber();
    if (!mounted) return;
    _controller.lastCreatedDirectSaleNo.value = preview;
  }

  String _formatInvoiceDate(String value) {
    if (value.isEmpty) return DateFormat('dd/MM/yyyy').format(DateTime.now());

    final parsed = DateTime.tryParse(value);
    if (parsed != null) return DateFormat('dd/MM/yyyy').format(parsed);

    return value;
  }

  void _seedFromSale(DirectSale sale) {
    _lines.clear();
    _bags.clear();

    for (final line in sale.lines) {
      final editor = _SaleLineEditor();
      editor.itemId = line.itemId;
      editor.quantity.text = line.quantity.toString();
      editor.discount.text = line.discount.toString();
      editor.manualDiscountText = line.discount.toString();
      editor.piecesPercentage.text = line.piecesPercentage.toString();
      editor.pieces.text = line.pieces.toString();
      editor.salesPrice.text = line.salesPrice.toString();
      _lines.add(editor);
    }

    if (_lines.isEmpty) {
      _lines.add(_SaleLineEditor());
    }

    for (final bag in sale.gunnyBags) {
      final editor = _BagEditor();
      editor.bagTypeId = bag.bagTypeId;
      editor.bharthiTypeId = bag.bharthiTypeId;
      editor.bagBharthi = bag.bagBharthi;
      editor.quantity.text = bag.quantity.toString();
      editor.rate.text = bag.rate.toString();
      _bags.add(editor);
    }

    if (_bags.isEmpty) {
      _bags.add(_BagEditor());
    }
  }

  void _setPiecesPercentageEnabled(bool enabled) {
    if (_piecesPercentageEnabled == enabled) return;

    setState(() => _updatePiecesPercentageState(enabled));
  }

  void _updatePiecesPercentageState(bool enabled) {
    _piecesPercentageEnabled = enabled;
    for (final line in _lines) {
      if (enabled) {
        line.manualDiscountText = line.discount.text;
        _syncEffectiveDiscount(line);
      } else {
        final manualDiscount = line.manualDiscountText;
        if (manualDiscount != null) {
          line.discount.text = manualDiscount;
        }
        line.manualDiscountText = null;
      }
    }
  }

  void _selectMode(String mode) {
    if (_mode == mode) return;
    setState(() {
      if (mode == SalesOrderController.modeLessing &&
          _piecesPercentageEnabled) {
        _updatePiecesPercentageState(false);
      }
      _mode = mode;
    });
  }

  void _addLine() {
    setState(() {
      final line = _SaleLineEditor();
      if (_piecesPercentageEnabled) {
        line.manualDiscountText = '';
        _syncEffectiveDiscount(line);
      }
      _lines.add(line);
    });
  }

  void _onLineValueChanged(_SaleLineEditor line) {
    if (_piecesPercentageEnabled && _mode == SalesOrderController.modeTonage) {
      _syncEffectiveDiscount(line);
    }
    setState(() {});
  }

  void _syncEffectiveDiscount(_SaleLineEditor line) {
    final text = _lineValues(line).discount.toString();
    if (line.discount.text == text) return;
    line.discount.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  DirectSaleLineValues _lineValues(_SaleLineEditor editor) {
    return DirectSalesController.calculateLineValues(
      mode: _mode,
      quantity: _number(editor.quantity),
      discount: _number(editor.discount),
      piecesPercentage: DirectSalesController.parsePiecesPercentage(
            editor.piecesPercentage.text,
          ) ??
          0,
      piecesPercentageEnabled: _piecesPercentageEnabled,
      salesPrice: _number(editor.salesPrice),
    );
  }

  String? _validatePiecesPercentage(String? value) {
    return DirectSalesController.parsePiecesPercentage(value) == null
        ? 'Enter a valid percentage.'
        : null;
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
    _additionalChargesController.dispose();
    _loadingChargesController.dispose();
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
            gradient: AppGradients.pageBackground,
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
    final isEditMode = widget.sale != null;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditMode ? 'Edit Sales' : 'Add New Sales',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEditMode
                      ? 'Update direct sales invoice'
                      : 'Create a direct sales invoice',
                  style: const TextStyle(fontSize: 13, color: _kMuted),
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
          Obx(
            () => _readOnlyField(
              _controller.lastCreatedDirectSaleNo.value.isEmpty
                  ? 'Assigned by server when saved'
                  : _controller.lastCreatedDirectSaleNo.value,
            ),
          ),
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
          _disabledSalesOrderField(
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
              _buildModeOption('Pieces'),
            ],
          ),
          if (_mode == SalesOrderController.modeTonage) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _piecesPercentageEnabled,
                    onChanged: (value) =>
                        _setPiecesPercentageEnabled(value ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pieces %',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeOption(String label) {
    final mode = label == 'Pieces'
        ? SalesOrderController.modeLessing
        : SalesOrderController.modeTonage;
    final selected = _mode == mode;

    return Expanded(
      child: InkWell(
        onTap: () => _selectMode(mode),
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
            onAdd: _addLine,
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
    final values = _lineValues(line);
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
                  onChanged: (_) => _onLineValueChanged(line),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberField(
                  label: _mode == SalesOrderController.modeLessing
                      ? 'Discount (pieces)'
                      : 'Discount (kg)',
                  controller: line.discount,
                  readOnly: _piecesPercentageEnabled &&
                      _mode == SalesOrderController.modeTonage,
                  onChanged: (_) => _onLineValueChanged(line),
                ),
              ),
            ],
          ),
          if (_piecesPercentageEnabled &&
              _mode == SalesOrderController.modeTonage) ...[
            const SizedBox(height: 12),
            _numberField(
              label: 'Pieces %',
              controller: line.piecesPercentage,
              validator: _validatePiecesPercentage,
              onChanged: (_) => _onLineValueChanged(line),
            ),
          ],
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
                  onChanged: (_) => _onLineValueChanged(line),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _computed(
                    'Actual Quantity', _format(values.actualQuantity)),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: _computed('Sales Amount', _money(values.salesAmount))),
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
          _numberField(
            label: 'Additional Charges',
            controller: _additionalChargesController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _numberField(
            label: 'Loading Charges',
            controller: _loadingChargesController,
            onChanged: (_) => setState(() {}),
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
          _totalRow('Charges Total', _chargesTotal()),
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

  Widget _disabledSalesOrderField(String hint) {
    return DropdownButtonFormField<String>(
      initialValue: null,
      isExpanded: true,
      disabledHint: Text(hint, overflow: TextOverflow.ellipsis),
      decoration: _decoration(),
      items: const [],
      onChanged: null,
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
    Widget saveButton(
        {required VoidCallback? onPressed, required String label}) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _kGreen.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label),
      );
    }

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
              child: widget.sale != null
                  ? saveButton(onPressed: null, label: 'Save Changes')
                  : Obx(
                      () => saveButton(
                        onPressed: _controller.isSaving.value ? null : _save,
                        label: _controller.isSaving.value
                            ? 'Saving…'
                            : 'Save Sales',
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
    bool readOnly = false,
    ValueChanged<String>? onChanged,
    FormFieldValidator<String>? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: readOnly ? TextAlign.right : TextAlign.start,
          textDirection: readOnly ? null : TextDirection.ltr,
          readOnly: readOnly,
          onChanged: onChanged ?? (_) => setState(() {}),
          validator: validator ??
              (required
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
                    }),
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
    if (widget.sale != null) {
      Get.snackbar(
        'Edit not supported',
        'Direct sale updates are not available in the current backend contract.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

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
      additionalCharges: _number(_additionalChargesController),
      loadingCharges: _number(_loadingChargesController),
    );
    if (saved && mounted) Get.back<dynamic>(result: true);
  }

  DirectSaleLine _buildLine(_SaleLineEditor editor) {
    final values = _lineValues(editor);
    final pieces = _number(editor.pieces);
    return DirectSaleLine(
      itemId: editor.itemId,
      quantity: _number(editor.quantity),
      discount: values.discount,
      piecesPercentage: values.piecesPercentage,
      pieces: pieces,
      actualQuantity: values.actualQuantity,
      salesPrice: _number(editor.salesPrice),
      salesAmount: values.salesAmount,
      baseCost: SalesOrderController.calculateBaseCost(
        values.salesAmount,
        pieces,
      ),
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
    return _lineValues(editor).actualQuantity;
  }

  double _salesAmount(_SaleLineEditor editor) {
    return _lineValues(editor).salesAmount;
  }

  double _invoiceTotal() {
    return DirectSalesController.calculateInvoiceTotal(
      salesAmount: _salesLinesTotal(),
      gunnyBagAmount: _gunnyBagsTotal(),
      additionalCharges: _number(_additionalChargesController),
      loadingCharges: _number(_loadingChargesController),
    );
  }

  double _chargesTotal() {
    return SalesOrderController.roundValue(
      _number(_additionalChargesController) +
          _number(_loadingChargesController),
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
  String? manualDiscountText;
  final quantity = TextEditingController();
  final discount = TextEditingController();
  final piecesPercentage = TextEditingController();
  final pieces = TextEditingController();
  final salesPrice = TextEditingController();

  void dispose() {
    quantity.dispose();
    discount.dispose();
    piecesPercentage.dispose();
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
