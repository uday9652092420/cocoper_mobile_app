import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/salesorders/sales_order_controller.dart';
import '../../models/sales_order.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);

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
        : _controller.fetchSalesOrderById(_orderId);
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
            _detail('Customer', order.customerName),
            if (order.poNumber.isNotEmpty || order.sourcePoId.isNotEmpty)
              _detail(
                'Source Purchase Order',
                order.poNumber.isNotEmpty ? order.poNumber : order.sourcePoId,
              ),
            _detail('Remarks', order.remarks),
            _detail('Total', '₹${_formatAmount(order.totalAmount)}/-'),
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
                  line.itemName.isEmpty ? line.itemId : line.itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Quantity: ${_formatAmount(line.quantity)}  ·  '
                  'Sale cost: ₹${_formatAmount(line.saleCost)}  ·  '
                  'Amount: ₹${_formatAmount(line.saleAmount != 0 ? line.saleAmount : line.amount)}',
                  style: const TextStyle(fontSize: 12, color: _kMuted),
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

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
