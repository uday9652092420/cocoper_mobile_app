import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/purchaseinvoice/purchase_invoice_controller.dart';
import '../../custome_widgets/custome_confirmation_dialog.dart';
import '../../models/purchase_invoice.dart';
import '../../routes/app_routes.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _kMint = Color(0xFFE7F3E4);

/// Saved Purchase Invoices list screen (mobile adaptation of the web
/// Purchase Invoice table), opened from the Operations dashboard.
class SavedPurchaseInvoicesView extends StatefulWidget {
  const SavedPurchaseInvoicesView({super.key});

  @override
  State<SavedPurchaseInvoicesView> createState() =>
      _SavedPurchaseInvoicesViewState();
}

class _SavedPurchaseInvoicesViewState extends State<SavedPurchaseInvoicesView> {
  final PurchaseInvoiceController _controller =
      Get.find<PurchaseInvoiceController>();

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.loadPurchaseInvoices();
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
                  _buildNewPurchaseInvoiceButton(),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 24),
                  _buildSavedInvoicesSection(),
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
                'Purchase Invoice',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Saved purchase invoices',
                style: TextStyle(fontSize: 13, color: _kMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewPurchaseInvoiceButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _onNewPurchaseInvoice,
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
          'New Purchase Invoice',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
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
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search by invoice no, supplier, branch…',
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
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: _kMuted,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedInvoicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SAVED PURCHASE INVOICES',
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
                'Saved Invoices',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              const Spacer(),
              Text(
                '${_controller.filteredInvoices.length} invoices',
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
      return _buildErrorState();
    }

    final invoices = _controller.filteredInvoices;
    if (invoices.isEmpty) {
      return _buildEmptyState(_controller.searchQuery.value.isNotEmpty);
    }

    return Column(
      children: [
        for (final invoice in invoices) _buildInvoiceCard(invoice),
      ],
    );
  }

  Widget _buildInvoiceCard(PurchaseInvoice invoice) {
    final isDraft = _isDraft(invoice);

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
                  invoice.invoiceNumber.isEmpty
                      ? 'Purchase Invoice'
                      : invoice.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ),
              _buildPaymentBadge(invoice),
              const SizedBox(width: 4),
              _buildStatusBadge(invoice.status),
            ],
          ),
          if (invoice.supplierName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              invoice.supplierName,
              style: const TextStyle(fontSize: 13, color: _kMuted),
            ),
          ],
          if (invoice.branchName.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              invoice.branchName,
              style: const TextStyle(fontSize: 12.5, color: _kMuted),
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
                _formatDisplayDate(invoice.date),
                style: const TextStyle(fontSize: 12.5, color: _kMuted),
              ),
              const Spacer(),
              Text(
                '₹${_formatAmount(invoice.grandTotal)}/-',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _kLine),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildAction(
                Icons.visibility_outlined,
                'View',
                _kGreen,
                () => _openDetail(invoice),
              ),
              if (isDraft) ...[
                const SizedBox(width: 18),
                _buildAction(
                  Icons.edit_outlined,
                  'Edit',
                  _kGreen,
                  () => _openEdit(invoice),
                ),
                const SizedBox(width: 18),
                _buildAction(
                  Icons.check_circle_outline,
                  'Approve',
                  const Color(0xFF0E8F86),
                  () => _confirmApprove(invoice),
                ),
                const SizedBox(width: 18),
                _buildAction(
                  Icons.delete_outline,
                  'Delete',
                  const Color(0xFFB3261E),
                  () => _confirmDelete(invoice),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  bool _isDraft(PurchaseInvoice invoice) {
    return invoice.status.trim().isEmpty ||
        invoice.status.toLowerCase() == 'draft';
  }

  Widget _buildPaymentBadge(PurchaseInvoice invoice) {
    final received = invoice.supplierPaymentReceiptStatus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: received ? const Color(0xFFE7F3E4) : const Color(0xFFFDF2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        received ? 'Received' : 'Pending',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: received ? const Color(0xFF2D8135) : const Color(0xFFE9A23B),
        ),
      ),
    );
  }

  Widget _buildAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(PurchaseInvoice invoice) {
    Get.toNamed(Routes.purchaseInvoiceDetail, arguments: invoice);
  }

  void _openEdit(PurchaseInvoice invoice) {
    Get.toNamed(Routes.editPurchaseInvoice, arguments: invoice);
  }

  void _confirmDelete(PurchaseInvoice invoice) {
    Get.dialog(
      CustomConfirmationDialog(
        header: 'Delete Purchase Invoice',
        body: 'Are you sure you want to delete ${invoice.invoiceNumber}?',
        yesText: 'Delete',
        noText: 'Cancel',
        onYes: () {
          Get.back();
          _controller.deletePurchaseInvoice(invoice.id);
        },
      ),
    );
  }

  void _confirmApprove(PurchaseInvoice invoice) {
    Get.dialog(
      CustomConfirmationDialog(
        header: 'Approve Purchase Invoice',
        body: 'Are you sure you want to approve ${invoice.invoiceNumber}?',
        yesText: 'Approve',
        noText: 'Cancel',
        onYes: () {
          Get.back();
          _controller.approvePurchaseInvoice(invoice.id);
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final text = status.trim().isEmpty ? 'Draft' : status;

    Color color;
    Color tint;

    switch (text.toLowerCase()) {
      case 'approved':
        color = const Color(0xFF2D8135);
        tint = const Color(0xFFE7F3E4);
        break;
      case 'draft':
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
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
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
            'Unable to load purchase invoices.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: _kMuted),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _controller.loadPurchaseInvoices,
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

  Widget _buildEmptyState(bool isSearch) {
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
              Icons.description_outlined,
              size: 28,
              color: _kGreen,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isSearch ? 'No matching invoices' : 'No saved purchase invoices',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isSearch
                ? 'Try a different invoice number, supplier or branch.'
                : 'Your saved purchase invoices will appear here once you create one.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _kMuted),
          ),
        ],
      ),
    );
  }

  void _onNewPurchaseInvoice() {
    Get.toNamed(Routes.newPurchaseInvoice);
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
