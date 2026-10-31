import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/purchaseorder/purchase_order_controller.dart';
import '../../controllers/salesorders/sales_order_controller.dart';
import '../../custome_widgets/app_status_badge.dart';
import '../../custome_widgets/custome_confirmation_dialog.dart';
import '../../models/purchase_order.dart';
import '../../models/sales_order.dart';
import '../../routes/app_routes.dart';
import '../../services/mobile_app_permissions.dart';
import '../../theme/app_theme.dart';

const _kInk = AppColors.textDefaultLight;
const _kMuted = AppColors.textLightGrayLight;
const _kLine = AppColors.borderLightGrayLight;
const _kGreen = AppColors.primaryLight;
const _kMint = AppColors.surfaceTint;

class PurchaseOrderView extends StatefulWidget {
  const PurchaseOrderView({super.key});

  @override
  State<PurchaseOrderView> createState() => _PurchaseOrderViewState();
}

class _PurchaseOrderViewState extends State<PurchaseOrderView> {
  final PurchaseOrderController _controller =
      Get.find<PurchaseOrderController>();
  final SalesOrderController _salesOrderController =
      Get.find<SalesOrderController>();

  @override
  void initState() {
    super.initState();
    _controller.loadPurchaseOrders();
    _salesOrderController.loadSalesOrders(showErrors: false);
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
        onPressed: () => Get.toNamed<void>(Routes.newPurchaseOrder),
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
    final linkedSalesOrder =
        _salesOrderController.salesOrderByPurchaseOrderReference(
      purchaseOrderId: po.id,
      poNumber: po.poNumber,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openPurchaseOrder(po, readOnly: true),
              child: Ink(
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
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              po.poNumber.isEmpty
                                  ? 'Purchase Order'
                                  : po.poNumber,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _kInk,
                              ),
                            ),
                          ),
                          _buildStatusBadge(po.status),
                        ],
                      ),
                      if (po.supplierName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          po.supplierName,
                          style: const TextStyle(fontSize: 13, color: _kMuted),
                        ),
                      ],
                      if (linkedSalesOrder != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Converted to ${linkedSalesOrder.soNumber}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _kMuted,
                                ),
                              ),
                            ),
                            if (_hasPermission('purchase-order.read'))
                              TextButton(
                                onPressed: () => Get.toNamed<void>(
                                  Routes.viewSalesOrder,
                                  arguments: linkedSalesOrder.id,
                                ),
                                child: const Text('View Sales Order'),
                              ),
                          ],
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
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: _kMuted,
                            ),
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
                ),
              ),
            ),
          ),
          _buildOrderActions(po, linkedSalesOrder),
        ],
      ),
    );
  }

  bool _isDraft(PurchaseOrder po) {
    return po.status.trim().isEmpty || po.status.toLowerCase() == 'draft';
  }

  bool _hasPermission(String permission) {
    final permissions = MobileAppPermissions.current;
    if (permissions == null) return false;
    if (permissions.hasPermission(permission)) return true;

    final hasPurchaseOrderPermissions = permissions.modulePermissions.any(
      (configuredPermission) =>
          configuredPermission.startsWith('purchase-order.'),
    );
    return permissions.canAccessMainApp && !hasPurchaseOrderPermissions;
  }

  Widget _buildOrderActions(PurchaseOrder po, SalesOrder? linkedSalesOrder) {
    final conversionStatusVerified =
        !_salesOrderController.isLoadingList.value &&
            !_salesOrderController.hasListError.value;
    final isUnconvertedDraft =
        _isDraft(po) && conversionStatusVerified && linkedSalesOrder == null;
    final canEdit = isUnconvertedDraft && _hasPermission('purchase-order.edit');
    final canDelete =
        isUnconvertedDraft && _hasPermission('purchase-order.delete');
    final canView = _hasPermission('purchase-order.read') ||
        _hasPermission('purchase-order.edit');
    if (!canView && !canEdit && !canDelete) return const SizedBox.shrink();

    if (!canView && !canEdit && !canDelete) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canView)
            IconButton(
              tooltip: 'View Purchase Order',
              onPressed: () => _openPurchaseOrder(po, readOnly: true),
              icon: const Icon(Icons.visibility_outlined),
              color: _kGreen,
            ),
          if (canEdit)
            IconButton(
              tooltip: 'Edit Purchase Order',
              onPressed: () => _openPurchaseOrder(po, readOnly: false),
              icon: const Icon(Icons.edit_outlined),
              color: _kGreen,
            ),
          if (canDelete)
            IconButton(
              tooltip: 'Delete Purchase Order',
              onPressed: () => _confirmDelete(po),
              icon: const Icon(Icons.delete_outline),
              color: const Color(0xFFB3261E),
            ),
        ],
      ),
    );
  }

  void _openPurchaseOrder(PurchaseOrder po, {required bool readOnly}) {
    Get.toNamed<void>(
      Routes.editPurchaseOrder,
      arguments: {'order': po, 'readOnly': readOnly},
    );
  }

  void _confirmDelete(PurchaseOrder po) {
    Get.dialog<void>(
      CustomConfirmationDialog(
        header: 'Delete Purchase Order',
        body: 'Are you sure you want to delete ${po.poNumber}?',
        yesText: 'Delete',
        noText: 'Cancel',
        onYes: () {
          Get.back<void>();
          _controller.deletePurchaseOrder(po.id);
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return AppStatusBadge(status: status, emptyLabel: 'Draft');
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
