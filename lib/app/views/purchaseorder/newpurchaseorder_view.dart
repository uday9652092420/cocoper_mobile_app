import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/purchaseorder/purchase_order_controller.dart';
import '../../helpers/flutter_toast.dart';
import '../../models/lookup_option.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_order_line.dart';
import '../../routes/app_routes.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _kMint = Color(0xFFE7F3E4);
const _kFieldFill = Color(0xFFF6F8F6);

class NewPurchaseOrderView extends StatefulWidget {
  const NewPurchaseOrderView({super.key, this.order});

  /// When provided, the form runs in edit mode for this Purchase Order.
  final PurchaseOrder? order;

  @override
  State<NewPurchaseOrderView> createState() => _NewPurchaseOrderViewState();
}

class _NewPurchaseOrderViewState extends State<NewPurchaseOrderView> {
  final PurchaseOrderController _controller =
      Get.find<PurchaseOrderController>();

  final _poNumberController = TextEditingController();
  final _dateController = TextEditingController();
  final _remarksController = TextEditingController();

  String? _branch;
  String? _supplier;

  String _quantityMode = 'Tonnage';
  bool _piecesPercentage = false;

  // Guards against a feedback loop while Pieces % echoes into Discount (Kgs).
  bool _syncingDiscount = false;

  // Edit-mode action flow: Draft -> Save Changes -> Approve -> Convert.
  String _currentStatus = 'Draft';
  bool _hasSavedChanges = false;

  final List<_LineItem> _lineItems = [];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _lineItems.add(_LineItem());

    final order = widget.order;
    if (order != null) {
      _prefillFromOrder(order);
      _controller.loadLookups();
    } else {
      _controller.prepareCreate().then((poNumber) {
        if (!mounted) return;
        setState(() {
          if (_poNumberController.text.trim().isEmpty) {
            _poNumberController.text = poNumber;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _poNumberController.dispose();
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
                        _buildQuantityModeCard(),
                        const SizedBox(height: 12),
                        _buildRemarksCard(),
                        const SizedBox(height: 12),
                        _buildLineItemsCard(),
                      ],
                    ),
                  ),
                ),
                _buildSaveBar(),
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
          Expanded(
            child: Text(
              widget.order != null
                  ? 'Edit Purchase Order'
                  : 'New Purchase Order',
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

  // ------------------------------------------------------------
  // Section cards
  // ------------------------------------------------------------

  Widget _buildBasicDetailsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('PO Number', required: true),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _poNumberController,
            hint: 'PO Number',
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
          _fieldLabel('Branch'),
          const SizedBox(height: 6),
          _buildDropdown(
            value: _branch,
            hint: 'Select branch',
            options: _controller.branches,
            onChanged: (v) => setState(() => _branch = v),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Supplier', required: true),
          const SizedBox(height: 6),
          _buildDropdown(
            value: _supplier,
            hint: 'Select supplier',
            options: _controller.suppliers,
            onChanged: (v) => setState(() => _supplier = v),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityModeCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Quantity Mode'),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildModeOption('Tonnage'),
              const SizedBox(width: 10),
              _buildModeOption('Lessing'),
            ],
          ),
          // Pieces % is only available for Tonnage, not Lessing.
          if (_quantityMode != 'Lessing') ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(
                () => _piecesPercentage = !_piecesPercentage,
              ),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _piecesPercentage,
                      onChanged: (v) =>
                          setState(() => _piecesPercentage = v ?? false),
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
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRemarksCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Remarks'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _remarksController,
            hint: 'Add remarks',
            maxLines: 4,
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
                  'Line Items',
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
            child: Row(
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
                  '₹${_formatAmount(_totalAmount())}/-',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Save bar
  // ------------------------------------------------------------

  Widget _buildSaveBar() {
    final isEdit = widget.order != null;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Save to keep PO as draft, or approve when final — then convert '
              'to Sales Order.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: _kMuted),
            ),
            const SizedBox(height: 10),
            if (isEdit)
              _buildEditAction()
            else
              _buildActionButton(
                label: 'Save',
                color: _kGreen,
                onPressed: _onSave,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditAction() {
    switch (_currentStatus.toLowerCase()) {
      case 'approved':
        return _buildActionButton(
          label: 'Convert to Sales Order',
          color: const Color(0xFF0E8F86),
          onPressed: _onConvert,
        );
      case 'invoiced':
        return const SizedBox.shrink();
      case 'draft':
      default:
        if (_hasSavedChanges) {
          return _buildActionButton(
            label: 'Approve',
            color: const Color(0xFF0E8F86),
            onPressed: _onApprove,
          );
        }
        return _buildActionButton(
          label: 'Save Changes',
          color: _kGreen,
          onPressed: _onSave,
        );
    }
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Obx(
        () => ElevatedButton(
          onPressed: _controller.isSaving.value ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withValues(alpha: 0.6),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
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
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
          _buildItemDropdown(index),
          const SizedBox(height: 12),
          if (_piecesPercentage) ...[
            _twoColumnRow(
              left: _labeledNumField(_quantityLabel, item.quantity),
              right: _labeledPiecesPercentageField(item),
            ),
            const SizedBox(height: 12),
            _twoColumnRow(
              left: _labeledDiscountField(item),
              right: _labeledNumField('Cost', item.cost),
            ),
            const SizedBox(height: 12),
            _twoColumnRow(
              left: _labeledNumField('Pieces', item.pieces),
              right: _labeledComputedField(
                'Actual Qty',
                _formatAmount(_actualQuantity(item)),
              ),
            ),
            const SizedBox(height: 12),
            _labeledComputedField(
              'Amount',
              '₹${_formatAmount(_itemAmount(item))}/-',
            ),
          ] else ...[
            _twoColumnRow(
              left: _labeledNumField(_quantityLabel, item.quantity),
              right: _labeledDiscountField(item),
            ),
            const SizedBox(height: 12),
            _twoColumnRow(
              left: _labeledNumField('Cost', item.cost),
              right: _labeledNumField('Pieces', item.pieces),
            ),
            const SizedBox(height: 12),
            _twoColumnRow(
              left: _labeledComputedField(
                'Actual Qty',
                _formatAmount(_actualQuantity(item)),
              ),
              right: _labeledComputedField(
                'Amount',
                '₹${_formatAmount(_itemAmount(item))}/-',
              ),
            ),
          ],
        ],
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13, color: _kInk),
          decoration: _compactInputDecoration(),
        ),
      ],
    );
  }

  Widget _labeledDiscountField(_LineItem item) {
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

  Widget _labeledPiecesPercentageField(_LineItem item) {
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

  Widget _buildItemDropdown(int index) {
    return Obx(
      () => DropdownButtonFormField<String>(
        initialValue: _lineItems[index].item,
        isExpanded: true,
        hint: const Text(
          'Select item',
          style: TextStyle(fontSize: 13, color: Color(0xFF9AA69F)),
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: _kMuted,
        ),
        decoration: _compactInputDecoration(),
        items: _controller.items
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.id,
                child: Text(
                  option.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _kInk),
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _lineItems[index].item = v),
      ),
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
      onTap: () => setState(() => _lineItems.add(_LineItem())),
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
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
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
    required RxList<LookupOption> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Obx(
      () => DropdownButtonFormField<String>(
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
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
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.id,
                child: Text(
                  option.label,
                  style: const TextStyle(fontSize: 14, color: _kInk),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildModeOption(String label) {
    final selected = _quantityMode == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _quantityMode = label;
          if (label == 'Lessing') {
            _piecesPercentage = false;
          }
        }),
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

  // ------------------------------------------------------------
  // Line item actions & computation
  // ------------------------------------------------------------

  void _removeLineItem(int index) {
    final item = _lineItems.removeAt(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => item.dispose());
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
  // Save / validation
  // ------------------------------------------------------------

  String _apiMode() {
    if (_piecesPercentage) return 'tonagePercentage';
    if (_quantityMode == 'Lessing') return 'lessing';
    return 'tonage';
  }

  String get _quantityLabel {
    return _apiMode() == 'lessing' ? 'Qty (Pieces)' : 'Qty (Tons)';
  }

  String get _discountLabel {
    return _apiMode() == 'lessing' ? 'Disc (Pieces)' : 'Disc (Kgs)';
  }

  double _linePiecesPercentage(_LineItem item) {
    return _apiMode() == 'tonagePercentage' ? _parse(item.piecesPercentage) : 0;
  }

  void _onPiecesPercentageChanged(_LineItem item) {
    if (_apiMode() != 'tonagePercentage') {
      setState(() {});
      return;
    }

    var percentage = _parse(item.piecesPercentage);
    final clamped = PurchaseOrderController.clampNum(percentage, 0, 100);
    if (clamped != percentage) {
      item.piecesPercentage.text = _formatNumber(clamped);
      percentage = clamped;
    }

    // Echo the calculated kg value back into Discount (Kgs), rounded to 0
    // decimals (matches the web Pieces % editing behaviour).
    final quantity = _parse(item.quantity);
    final discountValue = PurchaseOrderController.roundValue(
      PurchaseOrderController.percentageDiscount(quantity, percentage),
      0,
    );

    _syncingDiscount = true;
    item.discount.text = _formatNumber(discountValue);
    _syncingDiscount = false;

    setState(() {});
  }

  PurchaseOrderLine _buildLinePayload(_LineItem item) {
    final mode = _apiMode();
    final quantity = _parse(item.quantity);
    final discount = _parse(item.discount);
    final cost = _parse(item.cost);
    final pieces = _parse(item.pieces);
    final piecesPercentage = mode == 'tonagePercentage'
        ? PurchaseOrderController.clampNum(
            _parse(item.piecesPercentage),
            0,
            100,
          )
        : 0.0;
    final actual = PurchaseOrderController.calculateActualQuantity(
      mode: mode,
      quantity: quantity,
      discount: discount,
      piecesPercentage: piecesPercentage,
    );
    final amount = PurchaseOrderController.calculatePurchaseAmount(
      cost,
      actual,
    );
    final base = PurchaseOrderController.calculateBaseCost(amount, pieces);

    return PurchaseOrderLine(
      itemId: item.item ?? '',
      quantity: quantity,
      discount: discount,
      piecesPercentage: piecesPercentage,
      pieces: pieces,
      baseCost: base,
      actualQuantity: actual,
      purchaseCost: cost,
      purchaseAmount: amount,
      amount: amount,
    );
  }

  bool _validate() {
    final poNumber = _poNumberController.text.trim();
    final supplierId = _supplier?.trim() ?? '';

    if (poNumber.isEmpty) {
      errorToast('Please enter the PO number.');
      return false;
    }
    if (supplierId.isEmpty) {
      errorToast('Please select a supplier.');
      return false;
    }
    if (_lineItems.isEmpty) {
      errorToast('Please add at least one line item.');
      return false;
    }
    for (final item in _lineItems) {
      if ((item.item ?? '').isEmpty) {
        errorToast('Please select an item for every line.');
        return false;
      }
    }
    return true;
  }

  Future<void> _onSave() async {
    if (!_validate()) return;

    final lines = _lineItems.map(_buildLinePayload).toList();
    final date = _apiDate();

    final order = widget.order;
    bool success;
    if (order != null) {
      success = await _controller.updatePurchaseOrder(
        id: order.id,
        status: 'Draft',
        poNumber: _poNumberController.text.trim(),
        supplierId: _supplier?.trim() ?? '',
        branchId: _branch?.trim() ?? '',
        date: date,
        mode: _apiMode(),
        remarks: _remarksController.text.trim(),
        lines: lines,
      );

      if (success && mounted) {
        setState(() {
          _currentStatus = 'Draft';
          _hasSavedChanges = true;
        });
      }
    } else {
      success = await _controller.createPurchaseOrder(
        poNumber: _poNumberController.text.trim(),
        supplierId: _supplier?.trim() ?? '',
        branchId: _branch?.trim() ?? '',
        date: date,
        mode: _apiMode(),
        remarks: _remarksController.text.trim(),
        lines: lines,
      );

      if (success && mounted) {
        Get.back();
      }
    }
  }

  Future<void> _onApprove() async {
    final order = widget.order;
    if (order == null) return;
    if (!_validate()) return;

    final lines = _lineItems.map(_buildLinePayload).toList();
    final date = _apiDate();

    final success = await _controller.updatePurchaseOrder(
      id: order.id,
      status: 'Approved',
      poNumber: _poNumberController.text.trim(),
      supplierId: _supplier?.trim() ?? '',
      branchId: _branch?.trim() ?? '',
      date: date,
      mode: _apiMode(),
      remarks: _remarksController.text.trim(),
      lines: lines,
    );

    if (success && mounted) {
      setState(() {
        _currentStatus = 'Approved';
        _hasSavedChanges = true;
      });
    }
  }

  void _onConvert() {
    final order = widget.order;
    if (order == null) return;
    Get.toNamed(Routes.newSaleOrder, arguments: order);
  }

  void _prefillFromOrder(PurchaseOrder order) {
    _currentStatus =
        order.status.trim().isEmpty ? 'Draft' : order.status.trim();
    _hasSavedChanges = false;

    _poNumberController.text = order.poNumber;
    _dateController.text = _displayDate(order.date);
    _branch = order.branchId.isEmpty ? null : order.branchId;
    _supplier = order.supplierId.isEmpty ? null : order.supplierId;
    _remarksController.text = order.remarks;

    switch (order.mode) {
      case 'lessing':
        _quantityMode = 'Lessing';
        _piecesPercentage = false;
        break;
      case 'tonagePercentage':
        _quantityMode = 'Tonnage';
        _piecesPercentage = true;
        break;
      case 'tonage':
      default:
        _quantityMode = 'Tonnage';
        _piecesPercentage = false;
    }

    _lineItems.clear();
    for (final line in order.lines) {
      _lineItems.add(
        _LineItem()
          ..item = line.itemId.isEmpty ? null : line.itemId
          ..quantity.text = _formatNumber(line.quantity)
          ..discount.text = _formatNumber(line.discount)
          ..piecesPercentage.text = _formatNumber(line.piecesPercentage)
          ..cost.text = _formatNumber(line.purchaseCost)
          ..pieces.text = _formatNumber(line.pieces),
      );
    }
    if (_lineItems.isEmpty) {
      _lineItems.add(_LineItem());
    }
  }

  String _displayDate(String value) {
    final parsed = DateFormat('yyyy-MM-dd').tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _apiDate() {
    final parsed =
        DateFormat('dd/MM/yyyy').tryParse(_dateController.text.trim());
    if (parsed == null) return _dateController.text.trim();
    return DateFormat('yyyy-MM-dd').format(parsed);
  }

  // ------------------------------------------------------------
  // Computation helpers (delegated to the controller)
  // ------------------------------------------------------------

  double _parse(TextEditingController c) {
    final value = double.tryParse(c.text.trim());
    return (value == null || !value.isFinite) ? 0 : value;
  }

  double _actualQuantity(_LineItem item) {
    return PurchaseOrderController.calculateActualQuantity(
      mode: _apiMode(),
      quantity: _parse(item.quantity),
      discount: _parse(item.discount),
      piecesPercentage: _linePiecesPercentage(item),
    );
  }

  double _itemAmount(_LineItem item) {
    return PurchaseOrderController.calculatePurchaseAmount(
      _parse(item.cost),
      _actualQuantity(item),
    );
  }

  double _totalAmount() =>
      _lineItems.fold(0.0, (sum, e) => sum + _itemAmount(e));

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}

class _LineItem {
  String? item;
  final TextEditingController quantity;
  final TextEditingController discount;
  final TextEditingController piecesPercentage;
  final TextEditingController cost;
  final TextEditingController pieces;

  _LineItem()
      : quantity = TextEditingController(),
        discount = TextEditingController(),
        piecesPercentage = TextEditingController(),
        cost = TextEditingController(),
        pieces = TextEditingController();

  void dispose() {
    quantity.dispose();
    discount.dispose();
    piecesPercentage.dispose();
    cost.dispose();
    pieces.dispose();
  }
}
