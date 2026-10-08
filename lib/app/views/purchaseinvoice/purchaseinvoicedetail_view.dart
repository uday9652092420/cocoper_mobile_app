import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/purchase_invoice.dart';
import '../../models/purchase_invoice_line.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _kMint = Color(0xFFE7F3E4);

/// Read-only Purchase Invoice detail screen.
///
/// The [PurchaseInvoice] to display is passed as a route argument. The list
/// response already contains the invoice lines, so no extra GET is required.
class PurchaseInvoiceDetailView extends StatelessWidget {
  const PurchaseInvoiceDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final invoice = Get.arguments as PurchaseInvoice?;

    if (invoice == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text(
            'Purchase invoice not found.',
            style: TextStyle(color: _kMuted),
          ),
        ),
      );
    }

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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailsCard(invoice),
                        const SizedBox(height: 12),
                        _buildLinesCard(invoice),
                        const SizedBox(height: 12),
                        _buildTotalsCard(invoice),
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
              'Purchase Invoice',
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

  Widget _buildDetailsCard(PurchaseInvoice invoice) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.invoiceNumber.isEmpty
                      ? 'Purchase Invoice'
                      : invoice.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ),
              _buildStatusBadge(invoice.status),
            ],
          ),
          const SizedBox(height: 12),
          _detailRow('Invoice Date', invoice.date),
          _detailRow('Supplier', invoice.supplierName),
          _detailRow('Branch', invoice.branchName),
          _detailRow('Quantity Mode', _modeLabel(invoice.mode)),
          _detailRow(
            'Payment Receipt',
            invoice.supplierPaymentReceiptStatus ? 'Received' : 'Pending',
          ),
        ],
      ),
    );
  }

  Widget _buildLinesCard(PurchaseInvoice invoice) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Line Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 12),
          if (invoice.lines.isEmpty)
            const Text(
              'No line items.',
              style: TextStyle(fontSize: 13, color: _kMuted),
            )
          else
            Column(
              children: [
                for (int i = 0; i < invoice.lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildLineCard(invoice.lines[i], i + 1),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLineCard(PurchaseInvoiceLine line, int index) {
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
                'Line $index',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _kGreen,
                ),
              ),
              const Spacer(),
              Expanded(
                child: Text(
                  line.itemName.isEmpty ? 'Item' : line.itemName,
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
          _detailRow('Quantity', _formatAmount(line.quantityTons)),
          _detailRow('Discount', _formatAmount(line.discount)),
          _detailRow('Pieces %', _formatAmount(line.piecesPercentage)),
          _detailRow('Pieces', _formatAmount(line.pieces)),
          _detailRow('Actual Quantity', _formatAmount(line.actualQuantity)),
          _detailRow('Purchase Cost', '₹${_formatAmount(line.purchaseCost)}/-'),
          _detailRow(
            'Purchase Amount',
            '₹${_formatAmount(line.purchaseAmount)}/-',
          ),
          _detailRow('Base Cost', '₹${_formatAmount(line.baseCost)}/-'),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(PurchaseInvoice invoice) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('Lines Total', '₹${_formatAmount(invoice.linesTotal)}/-'),
          _detailRow(
              'Loading Cost', '₹${_formatAmount(invoice.loadingCost)}/-'),
          _detailRow('Market Cess', '₹${_formatAmount(invoice.marketCess)}/-'),
          _detailRow(
            'Bags & Sticks',
            '₹${_formatAmount(invoice.bagsAndSticks)}/-',
          ),
          _detailRow('Freight', '₹${_formatAmount(invoice.freight)}/-'),
          const Divider(height: 22, color: _kLine),
          Row(
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              const Spacer(),
              Text(
                '₹${_formatAmount(invoice.grandTotal)}/-',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Outstanding Amount',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _kGreen,
                ),
              ),
              const Spacer(),
              Text(
                '₹${_formatAmount(invoice.outstandingAmount)}/-',
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

  Widget _buildCard({required Widget child}) {
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: _kMuted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
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

  Widget _buildStatusBadge(String status) {
    Color color;
    Color tint;

    switch (status.toLowerCase()) {
      case 'approved':
        color = const Color(0xFF2D8135);
        tint = const Color(0xFFE7F3E4);
        break;
      default:
        color = const Color(0xFFE9A23B);
        tint = const Color(0xFFFDF2E2);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty ? 'Draft' : status,
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
      case 'lessing':
        return 'Lessing';
      case 'tonage':
      default:
        return 'Tonnage';
    }
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
