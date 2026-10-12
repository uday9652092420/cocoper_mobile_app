import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/direct_sale.dart';
import '../../controllers/salesorders/sales_order_controller.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _kMint = Color(0xFFE7F3E4);

class ViewSavedSaleView extends StatelessWidget {
  const ViewSavedSaleView({super.key});

  @override
  Widget build(BuildContext context) {
    final argument = Get.arguments;
    final sale = argument is DirectSale ? argument : null;

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
                if (sale == null)
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Direct sale details are unavailable. Return to Saved Sales and open a sale again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _kMuted),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailsCard(sale),
                          const SizedBox(height: 12),
                          _buildLinesCard(sale),
                          const SizedBox(height: 12),
                          _buildGunnyBagsCard(sale),
                          const SizedBox(height: 12),
                          _buildTotalsCard(sale),
                        ],
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
              'Direct Sale Details',
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

  Widget _buildDetailsCard(DirectSale sale) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _value(sale.directSaleNo),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ),
              _statusBadge(sale),
            ],
          ),
          const SizedBox(height: 12),
          _detailRow('Direct Sale No', sale.directSaleNo),
          _detailRow('Invoice Date', _formatDate(sale.invoiceDate)),
          _detailRow('Customer', sale.customerName, fallback: sale.customerId),
          _detailRow('Sales Order No', sale.salesOrderNo),
          _detailRow('Branch', sale.branchName, fallback: sale.branchId),
          _detailRow('Quantity Mode', _modeLabel(sale.mode)),
          _detailRow('Status', sale.status),
          _detailRow(
            'Approval',
            sale.approved == null
                ? ''
                : sale.approved!
                    ? 'Approved'
                    : 'Pending',
          ),
        ],
      ),
    );
  }

  Widget _buildLinesCard(DirectSale sale) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 12),
          if (sale.lines.isEmpty)
            const Text(
              'No sales items.',
              style: TextStyle(fontSize: 13, color: _kMuted),
            )
          else
            Column(
              children: [
                for (var index = 0; index < sale.lines.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child:
                        _buildLineCard(sale.lines[index], index + 1, sale.mode),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLineCard(DirectSaleLine line, int index, String mode) {
    final piecesMode = mode == SalesOrderController.modeLessing;
    final itemName = line.itemName.isEmpty ? line.itemId : line.itemName;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kMint.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Item $index',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _kGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _value(itemName),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _detailRow(
            piecesMode ? 'Quantity (Pieces)' : 'Quantity (Tons)',
            _formatAmount(line.quantity),
          ),
          _detailRow(
            piecesMode ? 'Discount (Pieces)' : 'Discount (Kg)',
            _formatAmount(line.discount),
          ),
          _detailRow('Pieces %', '${_formatAmount(line.piecesPercentage)}%'),
          _detailRow('Actual Quantity', _formatAmount(line.actualQuantity)),
          _detailRow('Sales Price', _currency(line.salesPrice)),
          _detailRow('Pieces', _formatAmount(line.pieces)),
          _detailRow('Sales Amount', _currency(line.salesAmount)),
          _detailRow('Base Cost', _currency(line.baseCost)),
        ],
      ),
    );
  }

  Widget _buildGunnyBagsCard(DirectSale sale) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gunny Bags',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 12),
          if (sale.gunnyBags.isEmpty)
            const Text(
              'No gunny bags.',
              style: TextStyle(fontSize: 13, color: _kMuted),
            )
          else
            Column(
              children: [
                for (var index = 0; index < sale.gunnyBags.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildBagCard(sale.gunnyBags[index], index + 1),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBagCard(DirectSaleGunnyBag bag, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kMint.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gunny Bag $index',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _kGreen,
            ),
          ),
          const SizedBox(height: 10),
          _detailRow('Bag Type', bag.bagTypeId),
          _detailRow('Bharthi Type', bag.bharthiTypeId),
          _detailRow('Bag Bharthi', _formatAmount(bag.bagBharthi)),
          _detailRow('Quantity', _formatAmount(bag.quantity)),
          _detailRow('Rate', _currency(bag.rate)),
          _detailRow('Amount', _currency(bag.amount)),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(DirectSale sale) {
    final linesTotal = sale.lines.fold<double>(
      0,
      (sum, line) => sum + line.salesAmount,
    );
    final bagsTotal = sale.gunnyBags.fold<double>(
      0,
      (sum, bag) => sum + bag.amount,
    );
    final bagsQuantity = sale.gunnyBags.fold<double>(
      0,
      (sum, bag) => sum + bag.quantity,
    );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('Total Sales Lines Amount', _currency(linesTotal)),
          _detailRow('Total Gunny Bags Quantity', _formatAmount(bagsQuantity)),
          _detailRow('Total Gunny Bags Amount', _currency(bagsTotal)),
          const Divider(height: 22, color: _kLine),
          Row(
            children: [
              const Text(
                'Invoice Total',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              const Spacer(),
              Text(
                _currency(sale.invoiceTotal),
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
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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

  Widget _detailRow(String label, String value, {String fallback = ''}) {
    final displayValue = value.trim().isNotEmpty ? value.trim() : fallback;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: _kMuted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _value(displayValue),
              textAlign: TextAlign.right,
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

  Widget _statusBadge(DirectSale sale) {
    final approved = sale.approved;
    final color = approved == true
        ? _kGreen
        : approved == false
            ? const Color(0xFFE9A23B)
            : _kMuted;
    final tint = approved == true
        ? _kMint
        : approved == false
            ? const Color(0xFFFDF2E2)
            : const Color(0xFFF0F2F0);
    final label = approved == null
        ? _value(sale.status)
        : approved
            ? 'Approved'
            : 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case SalesOrderController.modeLessing:
        return 'Pieces';
      case SalesOrderController.modeTonage:
        return 'Tonnage';
      default:
        return _value(mode);
    }
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null
        ? _value(value)
        : DateFormat('dd MMM yyyy').format(parsed);
  }

  String _formatAmount(double value) {
    if (!value.isFinite) return '—';
    return NumberFormat('#,##0.######', 'en_IN').format(value);
  }

  String _currency(double value) {
    if (!value.isFinite) return '—';
    return '₹${NumberFormat('#,##,##0.00', 'en_IN').format(value)}';
  }

  String _value(String value) => value.trim().isEmpty ? '—' : value.trim();
}
