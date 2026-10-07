import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/purchaseorder/purchase_order_controller.dart';
import '../../custome_widgets/custome_confirmation_dialog.dart';
import '../../models/purchase_order.dart';
import '../../routes/app_routes.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _kMint = Color(0xFFE7F3E4);

class PurchaseOrderView extends StatefulWidget {
  const PurchaseOrderView({super.key});

  @override
  State<PurchaseOrderView> createState() => _PurchaseOrderViewState();
}

class _PurchaseOrderViewState extends State<PurchaseOrderView> {
  final PurchaseOrderController _controller =
      Get.find<PurchaseOrderController>();

  @override
  void initState() {
    super.initState();
    _controller.loadPurchaseOrders();
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildNewPurchaseOrderButton(),
                  const SizedBox(height: 26),
                  _buildSavedOrdersSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Purchase Order',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Create and track purchase orders',
                style: TextStyle(fontSize: 13, color: _kMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewPurchaseOrderButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Get.toNamed(Routes.newPurchaseOrder),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.add_circle_outline, size: 20),
        label: const Text(
          'New Purchase Order',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildSavedOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SAVED PURCHASE ORDERS',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: _kMuted,
          ),
        ),
        const SizedBox(height: 6),
        Obx(
          () => Row(
            children: [
              const Text(
                'Saved Orders',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              const Spacer(),
              Text(
                '${_controller.purchaseOrders.length} orders',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Obx(() => _buildListBody()),
      ],
    );
  }

  Widget _buildListBody() {
    if (_controller.isLoadingList.value) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kLine),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: _kGreen),
        ),
      );
    }

    if (_controller.hasListError.value) {
      return _buildErrorState(_controller.listError.value);
    }

    if (_controller.purchaseOrders.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        for (final po in _controller.purchaseOrders) _buildOrderCard(po),
      ],
    );
  }

  Widget _buildOrderCard(PurchaseOrder po) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  po.poNumber.isEmpty ? 'Purchase Order' : po.poNumber,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ),
              _buildStatusBadge(po.status),
              const SizedBox(width: 2),
              _buildEditButton(po),
              if (_isDraft(po)) _buildDeleteButton(po),
            ],
          ),
          if (po.supplierName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              po.supplierName,
              style: const TextStyle(fontSize: 13, color: _kMuted),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: _kMuted,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDisplayDate(po.date),
                style: const TextStyle(fontSize: 12.5, color: _kMuted),
              ),
              const Spacer(),
              Text(
                '₹${_formatAmount(po.totalAmount)}/-',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isDraft(PurchaseOrder po) {
    return po.status.trim().isEmpty || po.status.toLowerCase() == 'draft';
  }

  Widget _buildEditButton(PurchaseOrder po) {
    return InkWell(
      onTap: () => Get.toNamed(Routes.editPurchaseOrder, arguments: po),
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(Icons.edit_outlined, size: 19, color: _kGreen),
      ),
    );
  }

  Widget _buildDeleteButton(PurchaseOrder po) {
    return InkWell(
      onTap: () => _confirmDelete(po),
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(Icons.delete_outline, size: 19, color: Color(0xFFB3261E)),
      ),
    );
  }

  void _confirmDelete(PurchaseOrder po) {
    Get.dialog(
      CustomConfirmationDialog(
        header: 'Delete Purchase Order',
        body: 'Are you sure you want to delete ${po.poNumber}?',
        yesText: 'Delete',
        noText: 'Cancel',
        onYes: () {
          Get.back();
          _controller.deletePurchaseOrder(po.id);
        },
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
      case 'invoiced':
        color = const Color(0xFF0C8CE9);
        tint = const Color(0xFFE3F1FC);
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

  Widget _buildErrorState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
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
        children: [
          const Icon(
            Icons.error_outline,
            size: 40,
            color: Color(0xFFB3261E),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: _kMuted),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _controller.loadPurchaseOrders,
            child: const Text(
              'Retry',
              style: TextStyle(
                color: _kGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
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
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _kMint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 28,
              color: _kGreen,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No saved purchase orders',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your saved purchase orders will appear here once you create one.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _kMuted),
          ),
        ],
      ),
    );
  }

  String _formatDisplayDate(String value) {
    final parts = value.split('-');
    if (parts.length == 3 &&
        parts[0].length == 4 &&
        parts[1].length == 2 &&
        parts[2].length == 2) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return value;
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
