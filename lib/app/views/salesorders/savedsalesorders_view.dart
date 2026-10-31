import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/salesorders/sales_order_controller.dart';
import '../../custome_widgets/app_status_badge.dart';
import '../../custome_widgets/custome_confirmation_dialog.dart';
import '../../models/sales_order.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

const _kInk = AppColors.textDefaultLight;
const _kMuted = AppColors.textLightGrayLight;
const _kLine = AppColors.borderLightGrayLight;
const _kGreen = AppColors.primaryLight;
const _kMint = AppColors.surfaceTint;

/// Saved / converted Sales Orders list screen, opened from the Operations
/// dashboard when the "Sales Order" transaction is tapped.
class SavedSalesOrdersView extends StatefulWidget {
  const SavedSalesOrdersView({super.key});

  @override
  State<SavedSalesOrdersView> createState() => _SavedSalesOrdersViewState();
}

class _SavedSalesOrdersViewState extends State<SavedSalesOrdersView> {
  final SalesOrderController _controller = Get.find<SalesOrderController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.loadSalesOrders();
      _controller.loadLookups();
    });
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales Order',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Converted sales orders',
                style: TextStyle(fontSize: 13, color: _kMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSavedOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SAVED SALES ORDERS',
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
              const Expanded(
                child: Text(
                  'Saved Orders',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_controller.salesOrders.length} orders',
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

    if (_controller.hasListError.value && _controller.salesOrders.isEmpty) {
      return _buildErrorState();
    }

    if (_controller.salesOrders.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        if (_controller.hasListError.value)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Unable to refresh. Showing the most recently saved orders.',
              style: TextStyle(fontSize: 12, color: _kMuted),
            ),
          ),
        for (final so in _controller.salesOrders) _buildOrderCard(so),
      ],
    );
  }

  Widget _buildOrderCard(SalesOrder so) {
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
                  so.soNumber.isEmpty ? 'Sales Order' : so.soNumber,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ),
              _buildStatusBadge(so.status),
              const SizedBox(width: 2),
              _buildActionIcon(
                icon: Icons.visibility_outlined,
                label: 'View Sales Order',
                onTap: () => Get.toNamed<void>(
                  Routes.viewSalesOrder,
                  arguments: so.id,
                ),
              ),
              if (_isDraft(so) &&
                  SalesOrderController.hasSalesOrderActionPermission('edit'))
                _buildActionIcon(
                  icon: Icons.edit_outlined,
                  label: 'Edit Sales Order',
                  onTap: () => Get.toNamed<void>(
                    Routes.editSalesOrder,
                    arguments: so.id,
                  ),
                ),
              if (_isDraft(so) &&
                  SalesOrderController.hasSalesOrderActionPermission('delete'))
                _buildActionIcon(
                  icon: Icons.delete_outline,
                  label: 'Delete Sales Order',
                  color: const Color(0xFFB3261E),
                  onTap: () => _confirmDelete(so),
                ),
            ],
          ),
          if (_customerName(so).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _customerName(so),
              style: const TextStyle(fontSize: 13, color: _kMuted),
            ),
          ],
          if (so.poNumber.isNotEmpty || so.sourcePoId.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Converted from ${so.poNumber.isNotEmpty ? so.poNumber : so.sourcePoId}',
              style: const TextStyle(fontSize: 12, color: _kMuted),
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
                _formatDisplayDate(so.date),
                style: const TextStyle(fontSize: 12.5, color: _kMuted),
              ),
              const Spacer(),
              Text(
                '₹${_formatAmount(so.totalAmount)}/-',
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

  bool _isDraft(SalesOrder so) =>
      SalesOrderController.normalizedStatus(so.status) == 'draft';

  void _confirmDelete(SalesOrder order) {
    Get.dialog<void>(
      CustomConfirmationDialog(
        header: 'Delete Sales Order',
        body: 'Are you sure you want to delete ${order.soNumber}?',
        yesText: 'Delete',
        noText: 'Cancel',
        onYes: () {
          Get.back<void>();
          _controller.deleteSalesOrder(order.id);
        },
      ),
    );
  }

  String _customerName(SalesOrder order) {
    if (order.customerName.isNotEmpty) return order.customerName;
    for (final customer in _controller.customers) {
      if (customer.id == order.customerId) return customer.label;
    }
    return order.customerId;
  }

  Widget _buildActionIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = _kGreen,
  }) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 19, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return AppStatusBadge(status: status);
  }

  Widget _buildErrorState() {
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
          const Text(
            'Unable to load sales orders.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: _kMuted),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _controller.loadSalesOrders,
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
              Icons.local_shipping_outlined,
              size: 28,
              color: _kGreen,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No saved sales orders',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Converted sales orders will appear here once you create one.',
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
