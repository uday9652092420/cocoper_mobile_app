import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/salesorders/sales_order_controller.dart';
import '../../helpers/flutter_toast.dart';
import '../../models/purchase_order.dart';
import '../../models/sales_order_line.dart';
import '../../routes/app_routes.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _kMint = Color(0xFFE7F3E4);
const _kFieldFill = Color(0xFFF6F8F6);

/// Sales Order (Conversion) screen, opened from an approved Purchase Order.
///
/// Matches the web Sales Order conversion flow: the SO number is generated
/// client-side, converted lines keep the PO item/quantity locked, sale cost is
/// pre-filled from purchase cost, actual quantity is kept to 6 decimals and
/// profit = total sale amount - total purchase amount (frontend only).
class NewSaleOrderView extends StatefulWidget {
  const NewSaleOrderView({super.key});

  @override
  State<NewSaleOrderView> createState() => _NewSaleOrderViewState();
}

class _NewSaleOrderViewState extends State<NewSaleOrderView> {
  final _controller = Get.find<SalesOrderController>();

  final _soNumberController = TextEditingController();
  final _dateController = TextEditingController();
  final _remarksController = TextEditingController();

  String? _customerId;

  final List<_SaleLineItem> _lineItems = [];
  double _totalPurchaseAmount = 0;

  PurchaseOrder? _order;
  String _mode = SalesOrderController.modeTonage;

  // Guards against a feedback loop while Pieces % echoes into Discount.
  bool _syncingDiscount = false;

  @override
  void initState() {
    super.initState();

    final order = Get.arguments as PurchaseOrder?;
    _order = order;
    if (order != null) {
      _mode = order.mode.trim().isEmpty
          ? SalesOrderController.modeTonage
          : order.mode;
      _prefillFromOrder(order);
    } else {
      _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    }

    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      _controller.loadLookups(),
      _controller.loadSalesOrders(),
    ]);

    if (_order != null) {
      _soNumberController.text = await _controller.generateSoNumber();
    }
  }

  @override
  void dispose() {
    _soNumberController.dispose();
    _dateController.dispose();
    _remarksController.dispose();
    for (final item in _lineItems) {
      item.dispose();
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
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBasicDetailsCard(),
                        const SizedBox(height: 12),
                        _buildLineItemsCard(),
                      ],
                    ),
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

  // ------------------------------------------------------------
  // Header
  // ------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Get.back(),
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
            child: Text(
              'Sales Order',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF2E2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Draft',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE9A23B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Section cards
  // ------------------------------------------------------------

  Widget _buildBasicDetailsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('SO Number', required: true),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _soNumberController,
            hint: 'SO Number',
          ),
          const SizedBox(height: 14),
          _fieldLabel('Date', required: true),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _dateController,
            hint: 'dd/mm/yyyy',
            readOnly: true,
            onTap: _pickDate,
            suffixIcon: const Icon(
              Icons.date_range_outlined,
              size: 20,
              color: _kMuted,
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Customer', required: true),
          const SizedBox(height: 6),
          Obx(
            () => _buildDropdown(
              value: _customerId,
              hint: _controller.isLoadingLookups.value
                  ? 'Loading customers…'
                  : 'Select customer',
              items: _controller.customers
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(
                        c.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _customerId = v),
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Remarks'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _remarksController,
            hint: 'Add remarks',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemsCard() {
    return _buildCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Text(
                  'Sales Line Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
                const Spacer(),
                _buildAddLineButton(),
              ],
            ),
          ),
          const Divider(height: 1, color: _kLine),
          if (_lineItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Text(
                'No line items added yet.',
                style: TextStyle(fontSize: 13, color: _kMuted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                children: [
                  for (int i = 0; i < _lineItems.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildLineItemCard(i),
                    ),
                ],
              ),
            ),
          const Divider(height: 1, color: _kLine),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Total Lines Amount',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _kMuted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹${_formatMoney(_totalSaleAmount())}/-',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      'Profit Amount',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _kMuted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹${_formatMoney(_profitAmount())}/-',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Bottom bar
  // ------------------------------------------------------------

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kGreen,
                  side: const BorderSide(color: _kGreen),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Obx(
                () => ElevatedButton(
                  onPressed: _controller.isSaving.value ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _kGreen.withValues(alpha: 0.6),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _controller.isSaving.value ? 'Saving…' : 'Save',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Line item cards
  // ------------------------------------------------------------

  Widget _buildLineItemCard(int index) {
    final item = _lineItems[index];
    final showPiecesPercentage =
        _apiMode() == SalesOrderController.modeTonagePercentage;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kFieldFill.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _kMint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Line ${index + 1}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _kGreen,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _removeLineItem(index),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Color(0xFFB3261E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _fieldLabel('Item'),
          const SizedBox(height: 6),
          _buildItemField(item),
          const SizedBox(height: 12),
          if (showPiecesPercentage) ...[
            _twoColumnRow(
              left: _labeledQuantityField(item),
              right: _labeledPiecesPercentageField(item),
            ),
            const SizedBox(height: 12),
            _twoColumnRow(
              left: _labeledDiscountField(item),
              right: _labeledNumField('Sale Cost', item.saleCost),
            ),
            const SizedBox(height: 12),
            _twoColumnRow(
              left: _labeledNumField('Pieces', item.pieces),
              right: _labeledComputedField(
                'Actual Qty',
                _formatQuantity(_actualQuantity(item)),
              ),
            ),
            const SizedBox(height: 12),
            _labeledComputedField(
              'Sale Amount',
              '₹${_formatMoney(_saleAmount(item))}/-',
            ),
          ] else ...[
            _twoColumnRow(
              left: _labeledQuantityField(item),
              right: _labeledDiscountField(item),
            ),
            const SizedBox(height: 12),
            _twoColumnRow(
              left: _labeledNumField('Sale Cost', item.saleCost),
              right: _labeledNumField('Pieces', item.pieces),
            ),
            const SizedBox(height: 12),
            _twoColumnRow(
              left: _labeledComputedField(
                'Actual Qty',
                _formatQuantity(_actualQuantity(item)),
              ),
              right: _labeledComputedField(
                'Sale Amount',
                '₹${_formatMoney(_saleAmount(item))}/-',
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Converted PO lines keep their item locked; manually added lines let the
  /// user pick an item from the loaded master list.
  Widget _buildItemField(_SaleLineItem item) {
    if (item.isConverted) {
      return Obx(
        () => Container(
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: _kMint.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kLine),
          ),
          child: Text(
            _resolveItemLabel(item),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kInk,
            ),
          ),
        ),
      );
    }

    return Obx(
      () => _buildDropdown(
        value: item.itemId.isEmpty ? null : item.itemId,
        hint: 'Select item',
        items: _controller.items
            .map(
              (it) => DropdownMenuItem<String>(
                value: it.id,
                child: Text(it.label, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (v) => setState(
          () => item.select(v, _itemLabelFromId(v)),
        ),
      ),
    );
  }

  /// Resolves a line's display name from its stored name, or by matching its
  /// id against the loaded items master (PO lines only carry the item id).
  String _resolveItemLabel(_SaleLineItem item) {
    if (item.itemName.isNotEmpty) return item.itemName;
    final resolved = _itemLabelFromId(item.itemId);
    return resolved.isNotEmpty ? resolved : item.itemId;
  }

  String _itemLabelFromId(String? id) {
    if (id == null || id.isEmpty) return '';
    for (final option in _controller.items) {
      if (option.id == id) return option.label;
    }
    return '';
  }

  Widget _twoColumnRow({
    required Widget left,
    required Widget right,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  Widget _labeledQuantityField(_SaleLineItem item) {
    if (item.isConverted) {
      return _labeledComputedField(
        _quantityLabel,
        _formatQuantity(_parse(item.quantity)),
      );
    }
    return _labeledNumField(_quantityLabel, item.quantity);
  }

  Widget _labeledNumField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          textAlign: TextAlign.right,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13, color: _kInk),
          decoration: _compactInputDecoration(),
        ),
      ],
    );
  }

  Widget _labeledDiscountField(_SaleLineItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(_discountLabel),
        const SizedBox(height: 6),
        TextField(
          controller: item.discount,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          textAlign: TextAlign.right,
          onChanged: (_) {
            if (_syncingDiscount) return;
            setState(() {});
          },
          style: const TextStyle(fontSize: 13, color: _kInk),
          decoration: _compactInputDecoration(),
        ),
      ],
    );
  }

  Widget _labeledPiecesPercentageField(_SaleLineItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Pieces %'),
        const SizedBox(height: 6),
        TextField(
          controller: item.piecesPercentage,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          textAlign: TextAlign.right,
          onChanged: (_) => _onPiecesPercentageChanged(item),
          style: const TextStyle(fontSize: 13, color: _kInk),
          decoration: _compactInputDecoration(),
        ),
      ],
    );
  }

  Widget _labeledComputedField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _kMint.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _compactInputDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kGreen, width: 1.1),
      ),
    );
  }

  Widget _buildAddLineButton() {
    return InkWell(
      onTap: () => setState(() => _lineItems.add(_SaleLineItem.empty())),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _kMint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: _kGreen),
            SizedBox(width: 4),
            Text(
              'Add Line',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _kGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Shared field builders
  // ------------------------------------------------------------

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: _kInk,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(color: Colors.red, fontSize: 15),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hint,
    Widget? suffixIcon,
    VoidCallback? onTap,
    bool readOnly = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: _kInk),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9AA69F)),
        suffixIcon: suffixIcon,
        isDense: true,
        filled: true,
        fillColor: _kFieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
          borderSide: const BorderSide(color: _kGreen, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: Text(
        hint,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, color: Color(0xFF9AA69F)),
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: _kMuted,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: _kFieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
          borderSide: const BorderSide(color: _kGreen, width: 1.2),
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  // ------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------

  Future<void> _onSave() async {
    if (!_validate()) return;

    final lines = _lineItems.map(_buildLinePayload).toList();
    final date = _apiDate();

    final order = _order;
    final success = await _controller.createSalesOrder(
      soNumber: _soNumberController.text.trim(),
      date: date,
      customerId: _customerId?.trim() ?? '',
      remarks: _remarksController.text.trim(),
      mode: _apiMode(),
      sourcePoId: order?.id ?? '',
      poNumber: order?.poNumber ?? '',
      lines: lines,
    );

    if (success && mounted) {
      // Return to the saved purchase orders list, clearing the edit +
      // conversion screens from the stack (dashboard stays as the root).
      Get.offNamedUntil(
        Routes.purchaseOrder,
        (route) => route.isFirst,
      );
    }
  }

  void _pickDate() async {
    final now = DateTime.now();
    final initial = _dateController.text.isNotEmpty
        ? (DateFormat('dd/MM/yyyy').tryParse(_dateController.text) ?? now)
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(
        () => _dateController.text = DateFormat('dd/MM/yyyy').format(picked),
      );
    }
  }

  // ------------------------------------------------------------
  // Prefill & computation
  // ------------------------------------------------------------

  void _prefillFromOrder(PurchaseOrder order) {
    _dateController.text = _displayDate(order.date);
    _remarksController.text = 'Converted from ${order.poNumber}';

    _totalPurchaseAmount = 0;
    for (final line in order.lines) {
      _totalPurchaseAmount += line.purchaseAmount;
      _lineItems.add(
        _SaleLineItem(
          itemId: line.itemId,
          itemName: line.itemName,
          purchaseAmount: line.purchaseAmount,
          quantity: line.quantity,
          discount: line.discount,
          piecesPercentage: line.piecesPercentage,
          saleCost: line.purchaseCost,
          pieces: line.pieces,
          isConverted: true,
        ),
      );
    }
  }

  String _displayDate(String value) {
    final parsed = DateFormat('yyyy-MM-dd').tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _apiDate() {
    final parsed = DateFormat('dd/MM/yyyy').tryParse(_dateController.text);
    if (parsed == null) return _dateController.text;
    return DateFormat('yyyy-MM-dd').format(parsed);
  }

  String _apiMode() => _mode;

  String get _quantityLabel {
    return _apiMode() == SalesOrderController.modeLessing
        ? 'Qty (Pieces)'
        : 'Qty (Tons)';
  }

  String get _discountLabel {
    return _apiMode() == SalesOrderController.modeLessing
        ? 'Disc (Pieces)'
        : 'Disc (Kgs)';
  }

  double _parse(TextEditingController c) {
    final value = double.tryParse(c.text.trim());
    return (value == null || !value.isFinite) ? 0 : value;
  }

  double _linePiecesPercentage(_SaleLineItem item) {
    return _apiMode() == SalesOrderController.modeTonagePercentage
        ? SalesOrderController.clampNum(_parse(item.piecesPercentage), 0, 100)
        : 0;
  }

  void _onPiecesPercentageChanged(_SaleLineItem item) {
    if (_apiMode() != SalesOrderController.modeTonagePercentage) {
      setState(() {});
      return;
    }

    var percentage = _parse(item.piecesPercentage);
    final clamped = SalesOrderController.clampNum(percentage, 0, 100);
    if (clamped != percentage) {
      item.piecesPercentage.text = _formatNumber(clamped);
      percentage = clamped;
    }

    // Echo the calculated value back into Discount (matches web behaviour).
    final quantity = _parse(item.quantity);
    final discountValue = SalesOrderController.roundValue(
      quantity * percentage / 100,
      0,
    );

    _syncingDiscount = true;
    item.discount.text = _formatNumber(discountValue);
    _syncingDiscount = false;

    setState(() {});
  }

  double _actualQuantity(_SaleLineItem item) {
    return SalesOrderController.calculateActualQuantity(
      mode: _apiMode(),
      quantity: _parse(item.quantity),
      discount: _parse(item.discount),
      piecesPercentage: _linePiecesPercentage(item),
    );
  }

  double _saleAmount(_SaleLineItem item) {
    return SalesOrderController.calculateSaleAmount(
      _parse(item.saleCost),
      _actualQuantity(item),
    );
  }

  double _baseCost(_SaleLineItem item) {
    return SalesOrderController.calculateBaseCost(
      _saleAmount(item),
      _parse(item.pieces),
    );
  }

  double _totalSaleAmount() {
    return SalesOrderController.calculateTotalAmount(
      _lineItems.map(_buildLinePayload).toList(),
    );
  }

  double _profitAmount() => SalesOrderController.calculateProfit(
        _totalSaleAmount(),
        _totalPurchaseAmount,
      );

  SalesOrderLine _buildLinePayload(_SaleLineItem item) {
    final quantity = _parse(item.quantity);
    final discount = _parse(item.discount);
    final saleCost = _parse(item.saleCost);
    final pieces = _parse(item.pieces);
    final piecesPercentage = _linePiecesPercentage(item);
    final actual = _actualQuantity(item);
    final saleAmount = _saleAmount(item);
    final baseCost = _baseCost(item);

    return SalesOrderLine(
      itemId: item.itemId,
      itemName: _resolveItemLabel(item),
      quantity: quantity,
      discount: discount,
      piecesPercentage: piecesPercentage,
      pieces: pieces,
      baseCost: baseCost,
      actualQuantity: actual,
      saleCost: saleCost,
      saleAmount: saleAmount,
      amount: saleAmount,
    );
  }

  bool _validate() {
    final soNumber = _soNumberController.text.trim();
    final customerId = _customerId?.trim() ?? '';

    if (soNumber.isEmpty) {
      errorToast('Please enter the SO number.');
      return false;
    }
    if (customerId.isEmpty) {
      errorToast('Please select a customer.');
      return false;
    }
    if (_lineItems.isEmpty) {
      errorToast('Please add at least one line item.');
      return false;
    }
    for (final item in _lineItems) {
      if (item.itemId.isEmpty) {
        errorToast('Please select an item for every line.');
        return false;
      }
    }
    return true;
  }

  void _removeLineItem(int index) {
    final item = _lineItems.removeAt(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => item.dispose());
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    var text = value.toStringAsFixed(6);
    text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    return text;
  }

  /// Actual quantity: keeps up to 6 decimals, trailing zeros trimmed.
  String _formatQuantity(double value) => _formatNumber(value);

  String _formatMoney(double value) => value.toStringAsFixed(2);
}

class _SaleLineItem {
  String itemId;
  String itemName;
  final double purchaseAmount;
  final bool isConverted;
  final TextEditingController quantity;
  final TextEditingController discount;
  final TextEditingController piecesPercentage;
  final TextEditingController saleCost;
  final TextEditingController pieces;

  _SaleLineItem({
    required this.itemId,
    required this.itemName,
    required this.purchaseAmount,
    required double quantity,
    required double discount,
    required double piecesPercentage,
    required double saleCost,
    required double pieces,
    required this.isConverted,
  })  : quantity = TextEditingController(text: _text(quantity)),
        discount = TextEditingController(text: _text(discount)),
        piecesPercentage = TextEditingController(text: _text(piecesPercentage)),
        saleCost = TextEditingController(text: _text(saleCost)),
        pieces = TextEditingController(text: _text(pieces));

  _SaleLineItem.empty()
      : itemId = '',
        itemName = '',
        purchaseAmount = 0,
        isConverted = false,
        quantity = TextEditingController(),
        discount = TextEditingController(),
        piecesPercentage = TextEditingController(),
        saleCost = TextEditingController(),
        pieces = TextEditingController();

  void select(String? id, String label) {
    itemId = id ?? '';
    itemName = label;
  }

  static String _text(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  void dispose() {
    quantity.dispose();
    discount.dispose();
    piecesPercentage.dispose();
    saleCost.dispose();
    pieces.dispose();
  }
}
