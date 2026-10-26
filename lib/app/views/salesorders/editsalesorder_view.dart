import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../controllers/salesorders/sales_order_controller.dart';
import '../../custome_widgets/app_status_badge.dart';
import '../../models/lookup_option.dart';
import '../../models/sales_order.dart';
import '../../models/sales_order_line.dart';
import '../../theme/app_theme.dart';

const _kInk = AppColors.textDefaultLight;
const _kMuted = AppColors.textLightGrayLight;
const _kLine = AppColors.borderLightGrayLight;
const _kGreen = AppColors.primaryLight;
const _kMint = AppColors.surfaceTint;
const _kFieldFill = AppColors.fieldFill;

/// Sales Order editor. Reads are refreshed from GET /sales-orders; mutation
/// controls remain disabled until the backend write contracts are verified.
class EditSalesOrderView extends StatefulWidget {
  const EditSalesOrderView({super.key, required this.orderId});

  final String orderId;

  @override
  State<EditSalesOrderView> createState() => _EditSalesOrderViewState();
}

class _EditSalesOrderViewState extends State<EditSalesOrderView> {
  final SalesOrderController _controller = Get.find<SalesOrderController>();
  final _formKey = GlobalKey<FormState>();
  final _soNumberController = TextEditingController();
  final _dateController = TextEditingController();
  final _remarksController = TextEditingController();

  Future<SalesOrder?>? _orderFuture;
  SalesOrder? _order;
  String? _customerId;
  String _mode = SalesOrderController.modeTonage;
  final List<_EditSalesOrderLine> _lines = [];

  bool get _isEditable =>
      _order != null && SalesOrderController.canEditSalesOrder(_order!);

  bool get _hasSupportedMode => const {
        SalesOrderController.modeTonage,
        SalesOrderController.modeLessing,
      }.contains(_mode);

  @override
  void initState() {
    super.initState();
    _orderFuture = _fetchOrder();
    _controller.loadLookups();
  }

  Future<SalesOrder?> _fetchOrder() async {
    final id = widget.orderId.trim();
    if (id.isEmpty) return null;
    final order = await _controller.fetchSalesOrderById(id);
    if (order != null && mounted) {
      _populate(order);
    }
    return order;
  }

  void _populate(SalesOrder order) {
    for (final line in _lines) {
      line.dispose();
    }
    _lines
      ..clear()
      ..addAll(order.lines.map(_EditSalesOrderLine.fromLine));
    _order = order;
    _soNumberController.text = order.soNumber;
    _dateController.text = _displayDate(order.date);
    _remarksController.text = order.remarks;
    _customerId = order.customerId.isEmpty ? null : order.customerId;
    _mode = order.mode;
    setState(() {});
  }

  @override
  void dispose() {
    _soNumberController.dispose();
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
                  child: FutureBuilder<SalesOrder?>(
                    future: _orderFuture,
                    builder: (context, snapshot) {
                      if (_orderFuture == null ||
                          snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(color: _kGreen),
                        );
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return _buildUnavailable();
                      }
                      return _buildOrder(snapshot.data!);
                    },
                  ),
                ),
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
            child: Text(
              'Edit Sales Order',
              style: TextStyle(
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

  Widget _buildUnavailable() {
    final message = _controller.hasListError.value
        ? 'Unable to load the latest Sales Order.'
        : 'This Sales Order is not available in the refreshed list.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: _kMuted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => setState(() => _orderFuture = _fetchOrder()),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrder(SalesOrder order) {
    final canEdit = _isEditable;
    final status = SalesOrderController.normalizedStatus(order.status);
    final statusMessage = switch (status) {
      'approved' => 'Approved Sales Orders are read-only.',
      'draft' =>
        'Changes can be reviewed here, but saving is unavailable until the '
            'backend update contract is verified.',
      _ => 'This status is not a verified editable Draft. Changes are '
          'read-only.',
    };

    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Sales Order',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _kInk,
                          ),
                        ),
                      ),
                      _statusBadge(order.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _card(
                    children: [
                      _fieldLabel('SO Number', required: true),
                      const SizedBox(height: 6),
                      _textField(
                        controller: _soNumberController,
                        enabled: canEdit,
                        validator: (value) =>
                            (value?.trim().isNotEmpty ?? false)
                                ? null
                                : 'Enter the SO number.',
                      ),
                      const SizedBox(height: 12),
                      _fieldLabel('Date', required: true),
                      const SizedBox(height: 6),
                      _textField(
                        controller: _dateController,
                        enabled: canEdit,
                        readOnly: true,
                        onTap: canEdit ? _pickDate : null,
                        validator: (value) =>
                            DateFormat('dd/MM/yyyy').tryParse(value ?? '') !=
                                    null
                                ? null
                                : 'Select a valid date.',
                        suffixIcon: const Icon(
                          Icons.date_range_outlined,
                          size: 20,
                          color: _kMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _fieldLabel('Customer', required: true),
                      const SizedBox(height: 6),
                      Obx(() => _customerDropdown(order, canEdit)),
                      const SizedBox(height: 12),
                      _fieldLabel('Mode'),
                      const SizedBox(height: 6),
                      _modeDropdown(),
                      if (order.poNumber.isNotEmpty ||
                          order.sourcePoId.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _readOnlyValue(
                          'Source Purchase Order',
                          order.poNumber.isNotEmpty
                              ? order.poNumber
                              : order.sourcePoId,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _fieldLabel('Remarks'),
                      const SizedBox(height: 6),
                      _textField(
                        controller: _remarksController,
                        enabled: canEdit,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _lineItemsCard(canEdit && _hasSupportedMode),
                  const SizedBox(height: 12),
                  _notice(statusMessage),
                  if (canEdit && !_hasSupportedMode) ...[
                    const SizedBox(height: 8),
                    _notice(_modeUnavailableMessage),
                  ],
                  if (canEdit) ...[
                    const SizedBox(height: 8),
                    _notice(
                      'Sales Order update, approval, and delete endpoints are '
                      'not verified. No changes will be sent to the server.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        _buildActions(canEdit),
      ],
    );
  }

  Widget _customerDropdown(SalesOrder order, bool canEdit) {
    final options = _controller.customers.toList();
    if (_customerId != null &&
        !options.any((option) => option.id == _customerId)) {
      options.insert(
        0,
        LookupOption(
            id: _customerId!,
            label:
                order.customerName.isEmpty ? _customerId! : order.customerName),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _customerId,
      isExpanded: true,
      decoration: _inputDecoration(),
      hint: Text(
        _controller.isLoadingLookups.value
            ? 'Loading customers…'
            : 'Select customer',
      ),
      items: [
        for (final customer in options)
          DropdownMenuItem(
            value: customer.id,
            child: Text(customer.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged:
          canEdit ? (value) => setState(() => _customerId = value) : null,
      validator: (value) =>
          (value?.trim().isNotEmpty ?? false) ? null : 'Select a customer.',
    );
  }

  Widget _modeDropdown() {
    final modes = <String>[
      SalesOrderController.modeTonage,
      SalesOrderController.modeTonagePercentage,
      SalesOrderController.modeLessing,
    ];
    if (_mode.isEmpty) modes.insert(0, '');
    if (!modes.contains(_mode)) modes.add(_mode);
    return DropdownButtonFormField<String>(
      initialValue: _mode,
      isExpanded: true,
      decoration: _inputDecoration(),
      items: [
        for (final mode in modes)
          DropdownMenuItem(value: mode, child: Text(_modeLabel(mode))),
      ],
      onChanged: null,
    );
  }

  Widget _lineItemsCard(bool canEdit) {
    final lines = _buildLinePayloads();
    final total = SalesOrderController.calculateTotalAmount(lines);
    return _card(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Sales Line Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ),
              if (canEdit)
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Add Line'),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: _kLine),
        if (_lines.isEmpty)
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
                for (var index = 0; index < _lines.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _lineEditor(index, canEdit),
                  ),
              ],
            ),
          ),
        const Divider(height: 1, color: _kLine),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Lines Amount',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _kMuted,
                  ),
                ),
              ),
              Text(
                '₹${_formatAmount(total)}/-',
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
    );
  }

  Widget _lineEditor(int index, bool canEdit) {
    final line = _lines[index];
    final items = _controller.items.toList();
    if (line.itemId.isNotEmpty &&
        !items.any((option) => option.id == line.itemId)) {
      items.insert(
        0,
        LookupOption(
          id: line.itemId,
          label: line.itemName.isEmpty ? line.itemId : line.itemName,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Line ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _kGreen,
                ),
              ),
              const Spacer(),
              if (canEdit)
                IconButton(
                  tooltip: 'Remove line ${index + 1}',
                  onPressed: () => _removeLine(index),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFB3261E),
                  ),
                ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: line.itemId.isEmpty ? null : line.itemId,
            isExpanded: true,
            decoration: _inputDecoration(label: 'Item *'),
            items: [
              for (final item in items)
                DropdownMenuItem(
                  value: item.id,
                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: canEdit
                ? (value) => setState(() {
                      line.itemId = value ?? '';
                      line.isDirty = true;
                      for (final item in items) {
                        if (item.id == value) {
                          line.itemName = item.label;
                          break;
                        }
                      }
                    })
                : null,
            validator: (value) =>
                (value?.isNotEmpty ?? false) ? null : 'Select an item.',
          ),
          const SizedBox(height: 10),
          _twoFields(
            _numberField(
              label: _mode == SalesOrderController.modeLessing
                  ? 'Qty (Pieces) *'
                  : 'Qty (Tons) *',
              controller: line.quantity,
              enabled: canEdit,
              requiredPositive: true,
              onChanged: (_) => setState(() => line.isDirty = true),
            ),
            _numberField(
              label: _mode == SalesOrderController.modeLessing
                  ? 'Disc (Pieces)'
                  : 'Disc (Kgs)',
              controller: line.discount,
              enabled: canEdit,
              allowZero: true,
              additionalValidator: (discount) {
                final actual = SalesOrderController.calculateActualQuantity(
                  mode: _mode,
                  quantity: _parse(line.quantity),
                  discount: discount,
                  piecesPercentage: _parse(line.piecesPercentage),
                );
                return actual > 0
                    ? null
                    : 'Discount leaves no actual quantity.';
              },
              onChanged: (_) => setState(() => line.isDirty = true),
            ),
          ),
          if (_mode == SalesOrderController.modeTonagePercentage) ...[
            const SizedBox(height: 10),
            _twoFields(
              _numberField(
                label: 'Pieces %',
                controller: line.piecesPercentage,
                enabled: canEdit,
                allowZero: true,
                maxValue: 100,
                onChanged: (_) => _onPiecesPercentageChanged(line),
              ),
              _numberField(
                label: 'Pieces',
                controller: line.pieces,
                enabled: canEdit,
                allowZero: true,
                onChanged: (_) => setState(() => line.isDirty = true),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            _numberField(
              label: 'Pieces',
              controller: line.pieces,
              enabled: canEdit,
              allowZero: true,
              onChanged: (_) => setState(() => line.isDirty = true),
            ),
          ],
          const SizedBox(height: 10),
          _twoFields(
            _numberField(
              label: 'Sale Cost *',
              controller: line.saleCost,
              enabled: canEdit,
              requiredPositive: true,
              onChanged: (_) => setState(() => line.isDirty = true),
            ),
            _computedField(
              'Actual Qty',
              _formatActualQuantity(_actualQuantity(line)),
            ),
          ),
          const SizedBox(height: 10),
          _twoFields(
            _computedField('Base Cost', _formatAmount(_baseCost(line))),
            _computedField(
              'Sale Amount',
              '₹${_formatAmount(_saleAmount(line))}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    bool requiredPositive = false,
    bool allowZero = false,
    double? maxValue,
    String? Function(double value)? additionalValidator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]')),
      ],
      onChanged: onChanged,
      decoration: _inputDecoration(label: label),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return requiredPositive ? 'Required' : null;
        }
        final number = double.tryParse(text);
        if (number == null || !number.isFinite) return 'Invalid number';
        if (requiredPositive && number <= 0) return 'Must be greater than 0';
        if (allowZero && number < 0) return 'Cannot be negative';
        if (!requiredPositive && !allowZero && number < 0) {
          return 'Cannot be negative';
        }
        if (maxValue != null && number > maxValue) {
          return 'Maximum ${_formatAmount(maxValue)}';
        }
        return additionalValidator?.call(number);
      },
    );
  }

  Widget _computedField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _kMuted)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: _kMint.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            textDirection: TextDirection.ltr,
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

  Widget _twoFields(Widget left, Widget right) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right),
        ],
      );

  Widget _readOnlyValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _kMint.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kLine),
          ),
          child: Text(value, style: const TextStyle(color: _kInk)),
        ),
      ],
    );
  }

  Widget _buildActions(bool canEdit) {
    if (!canEdit) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
      child: const SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null,
                child: Text('Save Changes'),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Saving is disabled until the backend update contract is verified.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: _kMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    bool enabled = true,
    bool readOnly = false,
    int maxLines = 1,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      onTap: onTap,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: _kInk),
      decoration: _inputDecoration(suffixIcon: suffixIcon),
    );
  }

  InputDecoration _inputDecoration({String? label, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
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
    );
  }

  Widget _fieldLabel(String label, {bool required = false}) {
    return Text.rich(
      TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: _kInk,
        ),
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _card({
    required List<Widget> children,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _notice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2E2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: _kMuted),
      ),
    );
  }

  Widget _statusBadge(String status) {
    return AppStatusBadge(status: status);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final selected =
        DateFormat('dd/MM/yyyy').tryParse(_dateController.text) ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 10),
    );
    if (picked != null && mounted) {
      setState(
          () => _dateController.text = DateFormat('dd/MM/yyyy').format(picked));
    }
  }

  void _addLine() => setState(() => _lines.add(_EditSalesOrderLine.empty()));

  void _removeLine(int index) {
    final line = _lines.removeAt(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  List<SalesOrderLine> _buildLinePayloads() =>
      _lines.map(_buildLinePayload).toList();

  SalesOrderLine _buildLinePayload(_EditSalesOrderLine line) {
    if (!line.isDirty && line.originalLine != null) {
      return line.originalLine!;
    }
    final quantity = _parse(line.quantity);
    final discount = _parse(line.discount);
    final percentage = _mode == SalesOrderController.modeTonagePercentage
        ? SalesOrderController.clampNum(_parse(line.piecesPercentage), 0, 100)
        : _parse(line.piecesPercentage);
    final actual = SalesOrderController.calculateActualQuantity(
      mode: _mode,
      quantity: quantity,
      discount: discount,
      piecesPercentage: percentage,
    );
    final saleCost = _parse(line.saleCost);
    final saleAmount =
        SalesOrderController.calculateSaleAmount(saleCost, actual);
    final pieces = _parse(line.pieces);
    return SalesOrderLine(
      itemId: line.itemId,
      itemName: line.itemName,
      quantity: quantity,
      discount: discount,
      piecesPercentage: percentage,
      pieces: pieces,
      baseCost: SalesOrderController.calculateBaseCost(saleAmount, pieces),
      actualQuantity: actual,
      saleCost: saleCost,
      saleAmount: saleAmount,
      amount: saleAmount,
    );
  }

  double _actualQuantity(_EditSalesOrderLine line) =>
      _buildLinePayload(line).actualQuantity;

  double _saleAmount(_EditSalesOrderLine line) {
    final payload = _buildLinePayload(line);
    return payload.saleAmount != 0 ? payload.saleAmount : payload.amount;
  }

  double _baseCost(_EditSalesOrderLine line) =>
      _buildLinePayload(line).baseCost;

  double _parse(TextEditingController controller) {
    final parsed = double.tryParse(controller.text.trim());
    return parsed != null && parsed.isFinite ? parsed : 0;
  }

  String _displayDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _modeLabel(String mode) => switch (mode) {
        '' => 'Not specified',
        SalesOrderController.modeTonage => 'Tonnage',
        SalesOrderController.modeTonagePercentage => 'Tonnage Percentage',
        SalesOrderController.modeLessing => 'Lessing',
        _ => 'Unsupported ($mode)',
      };

  String get _modeUnavailableMessage =>
      _mode == SalesOrderController.modeTonagePercentage
          ? 'Pieces % calculation is not verified. Existing line values are '
              'preserved and line editing is disabled.'
          : 'This order has no verified calculation mode. Existing line '
              'values are preserved and line editing is disabled.';

  String _formatAmount(double value) =>
      NumberFormat('#,##0.######').format(value);

  String _formatActualQuantity(double value) =>
      NumberFormat('#,##0').format(value.round());

  void _onPiecesPercentageChanged(_EditSalesOrderLine line) {
    final percentage = SalesOrderController.clampNum(
      _parse(line.piecesPercentage),
      0,
      100,
    );
    final discount = SalesOrderController.roundValue(
      _parse(line.quantity) * percentage / 100,
      0,
    );
    line.discount.text = _formatAmount(discount);
    line.isDirty = true;
    setState(() {});
  }
}

class _EditSalesOrderLine {
  String itemId;
  String itemName;
  final TextEditingController quantity;
  final TextEditingController discount;
  final TextEditingController piecesPercentage;
  final TextEditingController pieces;
  final TextEditingController saleCost;
  final SalesOrderLine? originalLine;
  bool isDirty;

  _EditSalesOrderLine({
    required this.itemId,
    required this.itemName,
    required double quantity,
    required double discount,
    required double piecesPercentage,
    required double pieces,
    required double saleCost,
    this.originalLine,
    this.isDirty = true,
  })  : quantity = TextEditingController(text: _text(quantity)),
        discount = TextEditingController(text: _text(discount)),
        piecesPercentage = TextEditingController(text: _text(piecesPercentage)),
        pieces = TextEditingController(text: _text(pieces)),
        saleCost = TextEditingController(text: _text(saleCost));

  factory _EditSalesOrderLine.fromLine(SalesOrderLine line) =>
      _EditSalesOrderLine(
        itemId: line.itemId,
        itemName: line.itemName,
        quantity: line.quantity,
        discount: line.discount,
        piecesPercentage: line.piecesPercentage,
        pieces: line.pieces,
        saleCost: line.saleCost,
        originalLine: line,
        isDirty: false,
      );

  factory _EditSalesOrderLine.empty() => _EditSalesOrderLine(
        itemId: '',
        itemName: '',
        quantity: 0,
        discount: 0,
        piecesPercentage: 0,
        pieces: 0,
        saleCost: 0,
        isDirty: true,
      );

  static String _text(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  void dispose() {
    quantity.dispose();
    discount.dispose();
    piecesPercentage.dispose();
    pieces.dispose();
    saleCost.dispose();
  }
}
