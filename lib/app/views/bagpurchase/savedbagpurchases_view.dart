import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/bagpurchase/bag_purchase_controller.dart';
import '../../custome_widgets/custome_confirmation_dialog.dart';
import '../../models/bag_purchase.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

const _kInk = AppColors.textDefaultLight;
const _kMuted = AppColors.textLightGrayLight;
const _kLine = AppColors.borderLightGrayLight;
const _kGreen = AppColors.primaryLight;

class SavedBagPurchasesView extends StatefulWidget {
  const SavedBagPurchasesView({super.key});

  @override
  State<SavedBagPurchasesView> createState() => _SavedBagPurchasesViewState();
}

class _SavedBagPurchasesViewState extends State<SavedBagPurchasesView> {
  final BagPurchaseController _controller = Get.find<BagPurchaseController>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.loadPurchases();
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildNewPurchaseButton(),
                      const SizedBox(height: 16),
                      _buildSearchBar(),
                      const SizedBox(height: 20),
                      _buildSavedPurchases(),
                    ],
                  ),
                ),
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
                'Saved Bag Purchases',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'View and manage bag purchases',
                style: TextStyle(fontSize: 13, color: _kMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewPurchaseButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _onNewPurchase,
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
          'New Bag Purchase',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _onNewPurchase() async {
    await Get.toNamed<void>(Routes.newBagPurchase);
    await _controller.loadPurchases();
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
                hintText: 'Search purchase no, supplier or remarks',
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _controller.loadPurchases,
            icon: const Icon(Icons.refresh, color: _kMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPurchases() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(
          () => Row(
            children: [
              const Expanded(
                child: Text(
                  'SAVED BAG PURCHASES',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: _kMuted,
                  ),
                ),
              ),
              Text(
                '${_controller.filteredPurchases.length} purchases',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Obx(_buildListBody),
      ],
    );
  }

  Widget _buildListBody() {
    if (_controller.isLoadingList.value) {
      return _stateCard(
        const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: CircularProgressIndicator(color: _kGreen),
          ),
        ),
      );
    }
    if (_controller.hasListError.value) {
      return _stateCard(
        Column(
          children: [
            const Icon(Icons.error_outline, size: 38, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(_controller.listError.value, textAlign: TextAlign.center),
            TextButton(
              onPressed: _controller.loadPurchases,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final records = _controller.filteredPurchases;
    if (records.isEmpty) {
      return _stateCard(
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Icon(
                _controller.searchQuery.value.isEmpty
                    ? Icons.inventory_2_outlined
                    : Icons.search_off,
                size: 36,
                color: _kMuted,
              ),
              const SizedBox(height: 8),
              Text(
                _controller.searchQuery.value.isEmpty
                    ? 'No bag purchases found.'
                    : 'No purchases match your search.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kMuted),
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 680) {
          return _buildWideList(records);
        }
        return Column(
          children: [
            for (final record in records) _buildPurchaseCard(record),
          ],
        );
      },
    );
  }

  Widget _buildWideList(List<BagPurchase> records) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Purchase No')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Supplier')),
            DataColumn(label: Text('Remarks')),
            DataColumn(label: Text('Lines')),
            DataColumn(label: Text('Total Amount')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final record in records)
              DataRow(
                cells: [
                  DataCell(Text(record.purchaseNumber)),
                  DataCell(Text(_formatDate(record.purchaseDate))),
                  DataCell(Text(record.supplierName)),
                  DataCell(Text(record.remarks)),
                  DataCell(Text('${record.lineCount}')),
                  DataCell(Text(_currency(record.totalAmount))),
                  DataCell(_buildActions(record)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseCard(BagPurchase record) {
    return Container(
      width: double.infinity,
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
                  record.purchaseNumber.isEmpty
                      ? 'Bag Purchase'
                      : record.purchaseNumber,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ),
              Text(
                _currency(record.totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _kGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(record.supplierName, style: const TextStyle(color: _kMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _meta(Icons.calendar_today_outlined,
                  _formatDate(record.purchaseDate)),
              _meta(Icons.list_alt_outlined, '${record.lineCount} lines'),
            ],
          ),
          if (record.remarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(record.remarks, style: const TextStyle(color: _kMuted)),
          ],
          const Divider(height: 20, color: _kLine),
          Align(
            alignment: Alignment.centerRight,
            child: _buildActions(record),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BagPurchase record) {
    return Wrap(
      spacing: 4,
      children: [
        IconButton(
          tooltip: 'View',
          onPressed: () => _openRecord(Routes.viewBagPurchase, record),
          icon: const Icon(Icons.visibility_outlined, color: _kMuted),
        ),
        IconButton(
          tooltip: 'Edit',
          onPressed: () => _openRecord(Routes.editBagPurchase, record),
          icon: const Icon(Icons.edit_outlined, color: _kGreen),
        ),
        Obx(
          () => IconButton(
            tooltip: 'Delete',
            onPressed: _controller.deletingId.value == record.id
                ? null
                : () => _confirmDelete(record),
            icon: _controller.deletingId.value == record.id
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline, color: Color(0xFFB3261E)),
          ),
        ),
      ],
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: _kMuted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: _kMuted)),
      ],
    );
  }

  Widget _stateCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: child,
    );
  }

  Future<void> _openRecord(String route, BagPurchase record) async {
    await Get.toNamed<void>(route, arguments: record);
    await _controller.loadPurchases();
  }

  void _confirmDelete(BagPurchase record) {
    Get.dialog<void>(
      CustomConfirmationDialog(
        header: 'Delete Bag Purchase',
        body: 'Delete ${record.purchaseNumber}? This permanently removes the '
            'purchase and cannot be undone.',
        yesText: 'Delete',
        noText: 'Cancel',
        onYes: () {
          Get.back<void>();
          _controller.deletePurchase(record);
        },
      ),
    );
  }

  String _formatDate(String value) {
    final date = BagPurchase.parsePurchaseDate(value);
    return date == null ? value : DateFormat('d/M/yyyy').format(date);
  }

  String _currency(double value) =>
      '₹${NumberFormat('#,##0.##').format(value)}';
}
