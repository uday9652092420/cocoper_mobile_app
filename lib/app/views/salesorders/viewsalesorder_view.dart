import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/salesorders/sales_order_controller.dart';
import '../../models/sales_order.dart';
import '../../models/sales_order_line.dart';
import '../../theme/app_theme.dart';

const _kInk = AppColors.textDefaultLight;
const _kMuted = AppColors.textLightGrayLight;
const _kLine = AppColors.borderLightGrayLight;
const _kGreen = AppColors.primaryLight;

class ViewSalesOrderView extends StatefulWidget {
  const ViewSalesOrderView({super.key, this.orderId = ''});

  final String orderId;

  @override
  State<ViewSalesOrderView> createState() => _ViewSalesOrderViewState();
}

class _ViewSalesOrderViewState extends State<ViewSalesOrderView> {
  final SalesOrderController _controller = Get.find<SalesOrderController>();
  late final String _orderId;
  Future<SalesOrder?>? _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderId = widget.orderId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(_loadOrder);
    });
  }

  void _loadOrder() {
    _orderFuture = _orderId.isEmpty
        ? Future<SalesOrder?>.value(null)
        : _loadOrderWithLookups();
  }

  Future<SalesOrder?> _loadOrderWithLookups() async {
    await _controller.loadLookups();
    return _controller.fetchSalesOrderById(_orderId);
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
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(color: _kGreen),
                        );
                      }
                      if (snapshot.hasError) {
                        return _buildUnavailable(
                          message: 'Unable to load this Sales Order.',
                        );
                      }
                      final order = snapshot.data;
                      if (order == null) return _buildUnavailable();
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: _buildDetails(order),
                      );
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
              'View Sales Order',
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

  Widget _buildUnavailable({String? message}) {
    message ??= _controller.hasListError.value
        ? 'Unable to load this Sales Order.'
        : 'This Sales Order is not available in the refreshed list.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: _kMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kMuted),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => setState(_loadOrder),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(SalesOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          children: [
            _detail('Sales Order Number', order.soNumber),
            _detail('Status', order.status),
            _detail('Date', _displayDate(order.date)),
            _detail('Customer', _customerName(order)),
            if (order.poNumber.isNotEmpty || order.sourcePoId.isNotEmpty)
              _detail(
                'Source Purchase Order',
                order.poNumber.isNotEmpty ? order.poNumber : order.sourcePoId,
              ),
            _detail('Remarks', order.remarks),
            _detail(
                'Total Lines Amount', _formatCurrency(order.lineTotalAmount)),
            _detail('Saved Total Amount', _formatCurrency(order.totalAmount)),
            if (order.savedTotalAmount != null &&
                (order.savedTotalAmount! - order.lineTotalAmount).abs() >=
                    0.005)
              _detail(
                'Saved/line difference',
                _formatCurrency(
                    order.savedTotalAmount! - order.lineTotalAmount),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          children: [
            const Text(
              'Sales Line Items',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 10),
            if (order.lines.isEmpty)
              const Text(
                'No line items are available.',
                style: TextStyle(color: _kMuted),
              )
            else
              for (final line in order.lines) ...[
                const Divider(height: 16, color: _kLine),
                Text(
                  _itemName(line),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Quantity: ${_formatQuantity(line.quantity)}  ·  '
                  'Discount: ${_formatQuantity(line.discount)}',
                  style: const TextStyle(fontSize: 12, color: _kMuted),
                ),
                Text(
                  'Actual quantity: ${_formatQuantity(line.actualQuantity)}  ·  '
                  'Pieces: ${_formatQuantity(line.pieces)}',
                  style: const TextStyle(fontSize: 12, color: _kMuted),
                ),
                Text(
                  'Sale Price: ${_formatCurrency(line.salePrice)}  ·  '
                  'Base cost: ${_formatCurrency(line.baseCost)}',
                  style: const TextStyle(fontSize: 12, color: _kMuted),
                ),
                Text(
                  'Sale amount: ${_formatCurrency(line.effectiveSaleAmount)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
          ],
        ),
      ],
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _detail(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: _kMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _displayDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _customerName(SalesOrder order) {
    if (order.customerName.isNotEmpty) return order.customerName;
    for (final customer in _controller.customers) {
      if (customer.id == order.customerId) return customer.label;
    }
    return order.customerId;
  }

  String _itemName(SalesOrderLine line) {
    if (line.itemName.isNotEmpty) return line.itemName;
    for (final item in _controller.items) {
      if (item.id == line.itemId) return item.label;
    }
    return line.itemId;
  }

  String _formatCurrency(double value) =>
      '₹${NumberFormat('#,##,##0.##', 'en_IN').format(value)}/-';

  String _formatQuantity(double value) =>
      NumberFormat('#,##,##0.######', 'en_IN').format(value);
}
