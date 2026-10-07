import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../helpers/flutter_toast.dart';
import '../../models/purchase_order.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _kMint = Color(0xFFE7F3E4);
const _kFieldFill = Color(0xFFF6F8F6);

/// Sales Order (Conversion) screen, opened from an approved Purchase Order.
class NewSaleOrderView extends StatefulWidget {
  const NewSaleOrderView({super.key});

  @override
  State<NewSaleOrderView> createState() => _NewSaleOrderViewState();
}

class _NewSaleOrderViewState extends State<NewSaleOrderView> {
  final _soNumberController = TextEditingController();
  final _dateController = TextEditingController();
  final _remarksController = TextEditingController();

  String? _customer;

  final List<_SaleLineItem> _lineItems = [];
  double _totalPurchaseAmount = 0;

  @override
  void initState() {
    super.initState();

    final order = Get.arguments as PurchaseOrder?;
    if (order != null) {
      _prefillFromOrder(order);
    } else {
      _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
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
          _fieldLabel('Customer'),
          const SizedBox(height: 6),
          _buildDropdown(
            value: _customer,
            hint: 'Select customer',
            onChanged: (v) => setState(() => _customer = v),
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
                      '₹${_formatAmount(_totalSaleAmount())}/-',
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
                      '₹${_formatAmount(_profitAmount())}/-',
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
              child: ElevatedButton(
                onPressed: _onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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
          _buildItemDisplay(item),
          const SizedBox(height: 12),
          _twoColumnRow(
            left: _labeledNumField('Qty (Pieces)', item.quantity),
            right: _labeledNumField('Disc (Pieces)', item.discount),
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
              _formatAmount(_actualQuantity(item)),
            ),
            right: _labeledComputedField(
              'Sale Amount',
              '₹${_formatAmount(_saleAmount(item))}/-',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemDisplay(_SaleLineItem item) {
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kLine),
      ),
      child: Text(
        item.itemName.isEmpty ? item.itemId : item.itemName,
        style: const TextStyle(fontSize: 13, color: _kInk),
      ),
    );
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: Text(
        hint,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
      // Customer options are loaded when the Sales Order API integration is
      // wired up (GET /customers).
      items: const <DropdownMenuItem<String>>[],
      onChanged: onChanged,
    );
  }

  // ------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------

  void _onSave() {
    // No confirmed Sales Order conversion endpoint exists in the supplied
    // backend, so Save is a placeholder until the contract is provided.
    errorToast('Sales order save is coming soon.');
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
    _soNumberController.text = _deriveSoNumber(order.poNumber);
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
          saleCost: line.purchaseCost,
          pieces: line.pieces,
        ),
      );
    }
  }

  String _deriveSoNumber(String poNumber) {
    if (poNumber.isEmpty) return '';
    return poNumber.replaceFirst('PO', 'SO');
  }

  String _displayDate(String value) {
    final parsed = DateFormat('yyyy-MM-dd').tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  double _parse(TextEditingController c) {
    final value = double.tryParse(c.text.trim());
    return (value == null || !value.isFinite) ? 0 : value;
  }

  double _actualQuantity(_SaleLineItem item) {
    return _parse(item.quantity) - _parse(item.discount);
  }

  double _saleAmount(_SaleLineItem item) {
    return _parse(item.saleCost) * _actualQuantity(item);
  }

  double _totalSaleAmount() =>
      _lineItems.fold(0.0, (sum, e) => sum + _saleAmount(e));

  double _profitAmount() => _totalSaleAmount() - _totalPurchaseAmount;

  void _removeLineItem(int index) {
    final item = _lineItems.removeAt(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => item.dispose());
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class _SaleLineItem {
  final String itemId;
  final String itemName;
  final double purchaseAmount;
  final TextEditingController quantity;
  final TextEditingController discount;
  final TextEditingController saleCost;
  final TextEditingController pieces;

  _SaleLineItem({
    required this.itemId,
    required this.itemName,
    required this.purchaseAmount,
    required double quantity,
    required double discount,
    required double saleCost,
    required double pieces,
  })  : quantity = TextEditingController(text: _text(quantity)),
        discount = TextEditingController(text: _text(discount)),
        saleCost = TextEditingController(text: _text(saleCost)),
        pieces = TextEditingController(text: _text(pieces));

  _SaleLineItem.empty()
      : itemId = '',
        itemName = '',
        purchaseAmount = 0,
        quantity = TextEditingController(),
        discount = TextEditingController(),
        saleCost = TextEditingController(),
        pieces = TextEditingController();

  static String _text(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  void dispose() {
    quantity.dispose();
    discount.dispose();
    saleCost.dispose();
    pieces.dispose();
  }
}
