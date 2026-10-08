import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/purchaseinvoice/purchase_invoice_controller.dart';
import '../../helpers/flutter_toast.dart';
import '../../models/lookup_option.dart';
import '../../models/purchase_invoice.dart';
import '../../models/purchase_invoice_line.dart';
import '../../models/purchase_order.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _kMint = Color(0xFFE7F3E4);
const _kFieldFill = Color(0xFFF6F8F6);

/// New / Edit Purchase Invoice screen (mobile adaptation of the web Purchase
/// Invoice form).
///
/// When [invoice] is provided the form runs in edit mode.
class NewPurchaseInvoiceView extends StatefulWidget {
  const NewPurchaseInvoiceView({super.key, this.invoice});

  /// When provided, the form runs in edit mode for this Purchase Invoice.
  final PurchaseInvoice? invoice;

  @override
  State<NewPurchaseInvoiceView> createState() => _NewPurchaseInvoiceViewState();
}

class _NewPurchaseInvoiceViewState extends State<NewPurchaseInvoiceView> {
  final PurchaseInvoiceController _controller =
      Get.find<PurchaseInvoiceController>();

  final _invoiceNoController = TextEditingController();
  final _dateController = TextEditingController();
  final _loadingCostController = TextEditingController();
  final _marketCessController = TextEditingController();
  final _bagsSticksController = TextEditingController();
  final _freightController = TextEditingController();

  String? _branch;
  String? _supplier;
  String? _purchaseOrder;

  String _mode = 'Tonnage';
  bool _piecesPercentage = false;

  /// True when the lines were copied from a Purchase Order. In that case item
  /// selection and line removal are locked, mirroring the web behaviour.
  bool _fromPurchaseOrder = false;

  final List<_LineItem> _lineItems = [];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _lineItems.add(_LineItem());

    final invoice = widget.invoice;
    if (invoice != null) {
      _prefillFromInvoice(invoice);
      _controller.loadLookups();
    } else {
      _controller.prepareCreate().then((invoiceNo) {
        if (!mounted) return;
        setState(() {
          if (_invoiceNoController.text.trim().isEmpty) {
            _invoiceNoController.text = invoiceNo;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _dateController.dispose();
    _loadingCostController.dispose();
    _marketCessController.dispose();
    _bagsSticksController.dispose();
    _freightController.dispose();
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
                        const SizedBox(height: 12),
                        _buildChargesCard(),
                        const SizedBox(height: 12),
                        _buildTotalsCard(),
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
    final isEdit = widget.invoice != null;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Purchase Invoice' : 'New Purchase Invoice',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEdit ? 'Update purchase invoice' : 'Create a purchase invoice',
                  style: const TextStyle(fontSize: 13, color: _kMuted),
                ),
              ],
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
          _fieldLabel('Invoice No', required: true),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _invoiceNoController,
            hint: 'Invoice No',
          ),
          const SizedBox(height: 14),
          _fieldLabel('Branch', required: true),
          const SizedBox(height: 6),
          _buildDropdown(
            value: _branch,
            hint: 'Select branch',
            options: _controller.branches,
            onChanged: (v) => setState(() => _branch = v),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Invoice Date', required: true),
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
          _fieldLabel('Supplier', required: true),
          const SizedBox(height: 6),
          _buildDropdown(
            value: _supplier,
            hint: 'Select supplier',
            options: _controller.suppliers,
            onChanged: (v) => setState(() => _supplier = v),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Purchase Order'),
          const SizedBox(height: 6),
          _buildPurchaseOrderDropdown(),
          const SizedBox(height: 14),
          _fieldLabel('Quantity Mode'),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildModeOption('Tonnage'),
              const SizedBox(width: 10),
              _buildModeOption('Lessing'),
            ],
          ),
          if (_mode != 'Lessing') ...[
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
                      onChanged: (v) => setState(
                        () => _piecesPercentage = v ?? false,
                      ),
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
                if (!_fromPurchaseOrder) _buildAddLineButton(),
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
                  'Lines Total',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _kMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${_formatAmount(_linesTotal())}/-',
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

  Widget _buildChargesCard() {
    return _buildCard(
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
          _twoColumnRow(
            left: _labeledNumField('Loading Cost', _loadingCostController),
            right: _labeledNumField('Market Cess', _marketCessController),
          ),
          const SizedBox(height: 12),
          _twoColumnRow(
            left: _labeledNumField('Bags & Sticks', _bagsSticksController),
            right: _labeledNumField('Freight', _freightController),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _totalsRow('Lines Total', _linesTotal()),
          const SizedBox(height: 10),
          _totalsRow('Additional Total', _additionalTotal()),
          const Divider(height: 22, color: _kLine),
          _totalsRow('Grand Total', _grandTotal(), emphasize: true),
          const SizedBox(height: 10),
          _totalsRow(
            'Outstanding Amount',
            _grandTotal(),
            emphasize: true,
            color: _kGreen,
          ),
        ],
      ),
    );
  }

  Widget _totalsRow(
    String label,
    double value, {
    bool emphasize = false,
    Color color = _kInk,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasize ? 14.5 : 13.5,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: emphasize ? color : _kMuted,
          ),
        ),
        const Spacer(),
        Text(
          '₹${_formatAmount(value)}/-',
          style: TextStyle(
            fontSize: emphasize ? 15 : 13.5,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: emphasize ? color : _kInk,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // Save bar
  // ------------------------------------------------------------

  Widget _buildSaveBar() {
    final isEdit = widget.invoice != null;

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
            Text(
              isEdit
                  ? 'Save changes, or approve the invoice when final.'
                  : 'Save to keep the purchase invoice as a draft.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: _kMuted),
            ),
            const SizedBox(height: 10),
            if (isEdit) _buildEditActions() else _buildCreateAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateAction() {
    return _buildActionButton(
      label: 'Save',
      color: _kGreen,
      onPressed: _onSave,
    );
  }

  Widget _buildEditActions() {
    return Column(
      children: [
        _buildActionButton(
          label: 'Save Changes',
          color: _kGreen,
          onPressed: _onSave,
        ),
        const SizedBox(height: 10),
        _buildActionButton(
          label: 'Approve',
          color: const Color(0xFF0E8F86),
          onPressed: _onApprove,
        ),
      ],
    );
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
              if (!_fromPurchaseOrder)
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
              right: _labeledNumField('Purchase Cost', item.purchaseCost),
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
              'Purchase Amount',
              '₹${_formatAmount(_purchaseAmount(item))}/-',
            ),
          ] else ...[
            _twoColumnRow(
              left: _labeledNumField(_quantityLabel, item.quantity),
              right: _labeledDiscountField(item),
            ),
            const SizedBox(height: 12),
            _twoColumnRow(
              left: _labeledNumField('Purchase Cost', item.purchaseCost),
              right: _labeledNumField('Pieces', item.pieces),
            ),
            const SizedBox(height: 12),
            _twoColumnRow(
              left: _labeledComputedField(
                'Actual Qty',
                _formatAmount(_actualQuantity(item)),
              ),
              right: _labeledComputedField(
                'Purchase Amount',
                '₹${_formatAmount(_purchaseAmount(item))}/-',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemDropdown(int index) {
    return Obx(
      () => DropdownButtonFormField<String>(
        key: ValueKey('item-$index-${_lineItems[index].item ?? ''}'),
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
        onChanged: _fromPurchaseOrder
            ? null
            : (v) => setState(() => _lineItems[index].item = v),
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
        key: ValueKey(value),
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
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: _kInk),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPurchaseOrderDropdown() {
    return Obx(
      () => DropdownButtonFormField<String>(
        key: ValueKey(_purchaseOrder),
        initialValue: _purchaseOrder,
        isExpanded: true,
        hint: const Text(
          'Select purchase order (optional)',
          style: TextStyle(fontSize: 14, color: Color(0xFF9AA69F)),
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
        items: _controller.purchaseOrderOptions
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.id,
                child: Text(
                  option.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: _kInk),
                ),
              ),
            )
            .toList(),
        onChanged: _onPurchaseOrderChanged,
      ),
    );
  }

  Widget _buildModeOption(String label) {
    final selected = _mode == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _mode = label;
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
          onChanged: (_) => setState(() {}),
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

  // ------------------------------------------------------------
  // Actions & computation
  // ------------------------------------------------------------

  void _removeLineItem(int index) {
    final item = _lineItems.removeAt(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => item.dispose());
  }

  void _onPurchaseOrderChanged(String? id) {
    final po = _controller.eligiblePurchaseOrders
        .where((e) => e.id == id)
        .firstOrNull;

    setState(() {
      _purchaseOrder = id;
      if (po != null) {
        if (po.supplierId.isNotEmpty) _supplier = po.supplierId;
        if (po.branchId.isNotEmpty) _branch = po.branchId;
        _dateController.text = _displayDate(po.date);
        _mode = po.mode == 'lessing' ? 'Lessing' : 'Tonnage';
        _piecesPercentage = false;
        _fromPurchaseOrder = true;
        _applyLinesFromPurchaseOrder(po);
      } else {
        _fromPurchaseOrder = false;
      }
    });
  }

  void _applyLinesFromPurchaseOrder(PurchaseOrder po) {
    // Dispose the old controllers after this frame so the widgets that are
    // being unmounted never touch a disposed controller.
    final oldItems = List<_LineItem>.from(_lineItems);
    _lineItems.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final item in oldItems) {
        item.dispose();
      }
    });

    for (final line in po.lines) {
      _lineItems.add(
        _LineItem()
          ..item = line.itemId.isEmpty ? null : line.itemId
          ..quantity.text = _formatNumber(line.quantity)
          ..discount.text = _formatNumber(line.discount)
          ..piecesPercentage.text = _formatNumber(line.piecesPercentage)
          ..pieces.text = _formatNumber(line.pieces)
          ..purchaseCost.text = _formatNumber(line.purchaseCost),
      );
    }

    if (_lineItems.isEmpty) {
      _lineItems.add(_LineItem());
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
  // Save / validation
  // ------------------------------------------------------------

  String _apiMode() => _mode == 'Lessing' ? 'lessing' : 'tonage';

  String get _quantityLabel =>
      _apiMode() == 'lessing' ? 'Qty (Pieces)' : 'Qty (Tons)';

  String get _discountLabel =>
      _apiMode() == 'lessing' ? 'Disc (Pieces)' : 'Disc (Kgs)';

  double _linePiecesPercentage(_LineItem item) {
    return (_apiMode() == 'tonage' && _piecesPercentage)
        ? PurchaseInvoiceController.clampNum(
            _parse(item.piecesPercentage),
            0,
            100,
          )
        : 0;
  }

  PurchaseInvoiceLine _buildLinePayload(_LineItem item) {
    final actual = _actualQuantity(item);
    final amount = _purchaseAmount(item);
    final base = _baseCost(item);

    return PurchaseInvoiceLine(
      itemId: item.item ?? '',
      quantityTons: _parse(item.quantity),
      discount: _parse(item.discount),
      piecesPercentage: _linePiecesPercentage(item),
      pieces: _parse(item.pieces),
      baseCost: base,
      actualQuantity: actual,
      purchaseCost: _parse(item.purchaseCost),
      purchaseAmount: amount,
    );
  }

  bool _validate() {
    if (_invoiceNoController.text.trim().isEmpty) {
      errorToast('Please enter the invoice number.');
      return false;
    }
    if ((_branch?.trim() ?? '').isEmpty) {
      errorToast('Please select a branch.');
      return false;
    }
    if ((_supplier?.trim() ?? '').isEmpty) {
      errorToast('Please select a supplier.');
      return false;
    }
    if (_dateController.text.trim().isEmpty) {
      errorToast('Please select the invoice date.');
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
    final grandTotal = _round2(_grandTotal());

    final invoice = widget.invoice;
    bool success;
    if (invoice != null) {
      success = await _controller.updatePurchaseInvoice(
        id: invoice.id,
        status: 'Draft',
        invoiceNo: _invoiceNoController.text.trim(),
        supplierId: _supplier?.trim() ?? '',
        branchId: _branch?.trim() ?? '',
        purchaseOrderId: _purchaseOrder?.trim() ?? '',
        date: _dateController.text.trim(),
        mode: _apiMode(),
        loadingCost: _parse(_loadingCostController),
        marketCess: _parse(_marketCessController),
        bagsAndSticks: _parse(_bagsSticksController),
        freight: _parse(_freightController),
        grandTotal: grandTotal,
        outstandingAmount: grandTotal,
        lines: lines,
      );
    } else {
      success = await _controller.createPurchaseInvoice(
        invoiceNo: _invoiceNoController.text.trim(),
        supplierId: _supplier?.trim() ?? '',
        branchId: _branch?.trim() ?? '',
        purchaseOrderId: _purchaseOrder?.trim() ?? '',
        date: _dateController.text.trim(),
        mode: _apiMode(),
        loadingCost: _parse(_loadingCostController),
        marketCess: _parse(_marketCessController),
        bagsAndSticks: _parse(_bagsSticksController),
        freight: _parse(_freightController),
        grandTotal: grandTotal,
        outstandingAmount: grandTotal,
        lines: lines,
      );

      if (success && mounted) {
        Get.back();
      }
    }
  }

  Future<void> _onApprove() async {
    final invoice = widget.invoice;
    if (invoice == null) return;
    if (!_validate()) return;

    final lines = _lineItems.map(_buildLinePayload).toList();
    final grandTotal = _round2(_grandTotal());

    await _controller.updatePurchaseInvoice(
      id: invoice.id,
      status: 'Approved',
      invoiceNo: _invoiceNoController.text.trim(),
      supplierId: _supplier?.trim() ?? '',
      branchId: _branch?.trim() ?? '',
      purchaseOrderId: _purchaseOrder?.trim() ?? '',
      date: _dateController.text.trim(),
      mode: _apiMode(),
      loadingCost: _parse(_loadingCostController),
      marketCess: _parse(_marketCessController),
      bagsAndSticks: _parse(_bagsSticksController),
      freight: _parse(_freightController),
      grandTotal: grandTotal,
      outstandingAmount: grandTotal,
      lines: lines,
    );
  }

  void _prefillFromInvoice(PurchaseInvoice invoice) {
    _invoiceNoController.text = invoice.invoiceNumber;
    _dateController.text = invoice.date.isEmpty
        ? DateFormat('dd/MM/yyyy').format(DateTime.now())
        : invoice.date;
    _branch = invoice.branchId.isEmpty ? null : invoice.branchId;
    _supplier = invoice.supplierId.isEmpty ? null : invoice.supplierId;
    _purchaseOrder =
        invoice.purchaseOrderId.isEmpty ? null : invoice.purchaseOrderId;
    _fromPurchaseOrder = invoice.purchaseOrderId.isNotEmpty;
    _mode = invoice.mode == 'lessing' ? 'Lessing' : 'Tonnage';
    _piecesPercentage = invoice.lines.any((line) => line.piecesPercentage > 0);

    _loadingCostController.text = _formatNumber(invoice.loadingCost);
    _marketCessController.text = _formatNumber(invoice.marketCess);
    _bagsSticksController.text = _formatNumber(invoice.bagsAndSticks);
    _freightController.text = _formatNumber(invoice.freight);

    // Dispose the initial empty line before replacing with saved lines.
    final oldItems = List<_LineItem>.from(_lineItems);
    _lineItems.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final item in oldItems) {
        item.dispose();
      }
    });

    for (final line in invoice.lines) {
      _lineItems.add(
        _LineItem()
          ..item = line.itemId.isEmpty ? null : line.itemId
          ..quantity.text = _formatNumber(line.quantityTons)
          ..discount.text = _formatNumber(line.discount)
          ..piecesPercentage.text = _formatNumber(line.piecesPercentage)
          ..pieces.text = _formatNumber(line.pieces)
          ..purchaseCost.text = _formatNumber(line.purchaseCost),
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

  // ------------------------------------------------------------
  // Computation helpers
  // ------------------------------------------------------------

  double _parse(TextEditingController c) {
    final value = double.tryParse(c.text.trim());
    return (value == null || !value.isFinite) ? 0 : value;
  }

  double _actualQuantity(_LineItem item) {
    return PurchaseInvoiceController.calculateActualQuantity(
      mode: _apiMode(),
      quantity: _parse(item.quantity),
      discount: _parse(item.discount),
      piecesPercentage: _linePiecesPercentage(item),
    );
  }

  double _purchaseAmount(_LineItem item) {
    return PurchaseInvoiceController.calculatePurchaseAmount(
      _parse(item.purchaseCost),
      _actualQuantity(item),
    );
  }

  double _baseCost(_LineItem item) {
    return PurchaseInvoiceController.calculateBaseCost(
      _purchaseAmount(item),
      _parse(item.pieces),
    );
  }

  double _linesTotal() =>
      _lineItems.fold(0.0, (sum, e) => sum + _purchaseAmount(e));

  double _additionalTotal() {
    return _parse(_loadingCostController) +
        _parse(_marketCessController) +
        _parse(_bagsSticksController) +
        _parse(_freightController);
  }

  double _grandTotal() => _linesTotal() + _additionalTotal();

  double _round2(double value) {
    if (!value.isFinite) return 0;
    return (value * 100).roundToDouble() / 100;
  }

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
  final TextEditingController pieces;
  final TextEditingController purchaseCost;

  _LineItem()
      : quantity = TextEditingController(),
        discount = TextEditingController(),
        piecesPercentage = TextEditingController(),
        pieces = TextEditingController(),
        purchaseCost = TextEditingController();

  void dispose() {
    quantity.dispose();
    discount.dispose();
    piecesPercentage.dispose();
    pieces.dispose();
    purchaseCost.dispose();
  }
}
