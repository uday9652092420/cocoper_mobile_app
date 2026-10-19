import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/directsales/direct_sales_controller.dart';
import '../../custome_widgets/custome_confirmation_dialog.dart';
import '../../models/direct_sale.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

const _kInk = AppColors.textDefaultLight;
const _kMuted = AppColors.textLightGrayLight;
const _kLine = AppColors.borderLightGrayLight;
const _kGreen = AppColors.primaryLight;
const _kMint = AppColors.surfaceTint;

class SavedSalesView extends StatefulWidget {
  const SavedSalesView({super.key});

  @override
  State<SavedSalesView> createState() => _SavedSalesViewState();
}

class _SavedSalesViewState extends State<SavedSalesView> {
  final DirectSalesController _controller = Get.find<DirectSalesController>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.loadDirectSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildAddNewSalesButton(),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 22),
                  _buildSavedSalesSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddNewSalesButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _openCreateForm,
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
          'Add New Sales',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
                'Direct Sales',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Saved direct sales',
                style: TextStyle(fontSize: 13, color: _kMuted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh direct sales',
          onPressed: _controller.loadDirectSales,
          icon: const Icon(Icons.refresh, color: _kGreen),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 19, color: _kMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _controller.searchQuery.value = value,
              textAlign: TextAlign.start,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search by customer, branch or direct sale no…',
                hintStyle: TextStyle(fontSize: 13.5, color: _kMuted),
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Obx(
            () => _controller.searchQuery.value.isEmpty
                ? const SizedBox.shrink()
                : InkWell(
                    onTap: () {
                      _searchController.clear();
                      _controller.searchQuery.value = '';
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child:
                          Icon(Icons.close_rounded, size: 18, color: _kMuted),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedSalesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SAVED DIRECT SALES',
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
                'Saved Sales',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              const Spacer(),
              Text(
                '${_controller.filteredSales.length} sales',
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
        Obx(_buildListBody),
      ],
    );
  }

  Widget _buildListBody() {
    if (_controller.isLoadingList.value) {
      return _stateContainer(
        const Center(child: CircularProgressIndicator(color: _kGreen)),
        verticalPadding: 40,
      );
    }

    if (_controller.hasListError.value) {
      return _buildErrorState();
    }

    final sales = _controller.filteredSales;
    if (sales.isEmpty) {
      return _buildEmptyState(_controller.searchQuery.value.isNotEmpty);
    }

    return Column(children: [for (final sale in sales) _buildSaleCard(sale)]);
  }

  Widget _buildSaleCard(DirectSale sale) {
    final customer = _controller.customerName(sale);
    final branch = _controller.branchName(sale);

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
                  sale.directSaleNo.isEmpty
                      ? _formatDisplayDate(sale.invoiceDate)
                      : sale.directSaleNo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ),
              Text(
                '₹${_formatAmount(sale.invoiceTotal)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            customer.isEmpty ? 'Customer unavailable' : customer,
            style: const TextStyle(fontSize: 13, color: _kMuted),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _metadata('Mode', sale.mode),
              _metadata('Branch', branch),
            ],
          ),
          if (sale.status.isNotEmpty || sale.approved != null) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                if (sale.status.isNotEmpty) _metadata('Status', sale.status),
                if (sale.approved != null)
                  _metadata(
                      'Approval', sale.approved! ? 'Approved' : 'Pending'),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: _kLine),
          const SizedBox(height: 8),
          _buildSaleActions(sale),
        ],
      ),
    );
  }

  Future<void> _openCreateForm() async {
    final created = await Get.toNamed<dynamic>(Routes.newDirectSale);
    if (created == true) await _controller.loadDirectSales();
  }

  Future<void> _openEdit(DirectSale sale) async {
    final refreshed = await Get.toNamed<dynamic>(
      Routes.editDirectSale,
      arguments: sale,
    );
    if (refreshed == true) await _controller.loadDirectSales();
  }

  void _openView(DirectSale sale) {
    Get.toNamed<void>(Routes.viewDirectSale, arguments: sale);
  }

  Widget _buildSaleActions(DirectSale sale) {
    final canManage = sale.approved == false && sale.id.isNotEmpty;
    return Obx(() {
      final actionBusy = _controller.actionInProgressId.value.isNotEmpty;
      final thisSaleBusy = _controller.actionInProgressId.value == sale.id;
      final enabled = !actionBusy;

      return Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _buildAction(
            Icons.visibility_outlined,
            'View',
            _kGreen,
            () => _openView(sale),
          ),
          if (canManage)
            _buildAction(
              Icons.edit_outlined,
              'Edit',
              _kGreen,
              () => _openEdit(sale),
              enabled: !actionBusy,
            ),
          if (canManage)
            _buildAction(
              Icons.check_circle_outline,
              'Approve',
              const Color(0xFF0E8F86),
              () => _confirmApprove(sale),
              enabled: enabled,
              showProgress: thisSaleBusy,
            ),
          if (canManage)
            _buildAction(
              Icons.delete_outline,
              'Delete',
              const Color(0xFFB3261E),
              () => _confirmDelete(sale),
              enabled: enabled,
            ),
        ],
      );
    });
  }

  Widget _buildAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap, {
    bool enabled = true,
    bool showProgress = false,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showProgress)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 16, color: enabled ? color : _kMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: enabled ? color : _kMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmApprove(DirectSale sale) {
    Get.dialog<void>(
      CustomConfirmationDialog(
        header: 'Approve Direct Sale',
        body:
            'Approve ${sale.directSaleNo.isEmpty ? 'this direct sale' : sale.directSaleNo}?',
        yesText: 'Approve',
        noText: 'Cancel',
        onYes: () {
          Get.back<void>();
          _controller.approveSale(sale);
        },
      ),
    );
  }

  void _confirmDelete(DirectSale sale) {
    Get.dialog<void>(
      CustomConfirmationDialog(
        header: 'Delete Direct Sale',
        body:
            'Delete ${sale.directSaleNo.isEmpty ? 'this direct sale' : sale.directSaleNo}?',
        yesText: 'Delete',
        noText: 'Cancel',
        onYes: () {
          Get.back<void>();
          _controller.deleteSale(sale);
        },
      ),
    );
  }

  Widget _metadata(String label, String value) {
    return Text(
      '$label: ${value.isEmpty ? '—' : value}',
      style: const TextStyle(fontSize: 12, color: _kMuted),
    );
  }

  Widget _buildErrorState() {
    return _stateContainer(
      Column(
        children: [
          const Icon(Icons.error_outline, size: 40, color: Color(0xFFB3261E)),
          const SizedBox(height: 12),
          Text(
            _controller.listError.value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: _kMuted),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _controller.loadDirectSales,
            child: const Text(
              'Retry',
              style: TextStyle(color: _kGreen, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      verticalPadding: 32,
      horizontalPadding: 24,
    );
  }

  Widget _buildEmptyState(bool isSearch) {
    return _stateContainer(
      Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _kMint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.point_of_sale_outlined,
                size: 28, color: _kGreen),
          ),
          const SizedBox(height: 14),
          Text(
            isSearch ? 'No matching sales' : 'No saved direct sales',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          if (!isSearch) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _openCreateForm,
              icon: const Icon(Icons.add),
              label: const Text('Add New Sales'),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            isSearch
                ? 'Try a different customer, branch or direct sale number.'
                : 'Saved direct sales will appear here once available.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _kMuted),
          ),
        ],
      ),
      verticalPadding: 40,
      horizontalPadding: 24,
    );
  }

  Widget _stateContainer(
    Widget child, {
    required double verticalPadding,
    double horizontalPadding = 16,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: horizontalPadding,
      ),
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

  String _formatDisplayDate(String value) {
    final parsed = DateTime.tryParse(value) ??
        DateFormat('dd/MM/yyyy').tryParse(value) ??
        DateFormat('d MMM yyyy').tryParse(value);
    return parsed == null ? value : DateFormat('dd MMM yyyy').format(parsed);
  }

  String _formatAmount(double value) {
    return NumberFormat('#,##,##0.00', 'en_IN').format(value);
  }
}
