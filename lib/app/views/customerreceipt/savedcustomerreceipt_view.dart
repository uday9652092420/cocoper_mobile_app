import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/customerreceipt/customer_receipt_controller.dart';
import '../../custome_widgets/custome_confirmation_dialog.dart';
import '../../models/customer_receipt.dart';
import '../../routes/app_routes.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _kMint = Color(0xFFE7F3E4);

/// Saved Customer Receipts screen.
class SavedCustomerReceiptsView extends StatefulWidget {
  const SavedCustomerReceiptsView({super.key});

  @override
  State<SavedCustomerReceiptsView> createState() =>
      _SavedCustomerReceiptsViewState();
}

class _SavedCustomerReceiptsViewState extends State<SavedCustomerReceiptsView> {
  final CustomerReceiptController _controller =
      Get.find<CustomerReceiptController>();
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.loadCustomerReceipts();
    _controller.loadCustomers();
  }

  @override
  void dispose() {
    _search.dispose();
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
              colors: [
                Color(0xFFE9F3E6),
                Color(0xFFFDFEFC),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: _controller.loadCustomerReceipts,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildNewReceiptButton(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 24),
                    _buildSavedReceiptsSection(),
                  ],
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
                'Customer Receipt',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Saved customer receipts',
                style: TextStyle(
                  fontSize: 13,
                  color: _kMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewReceiptButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Get.toNamed<void>(Routes.newCustomerReceipt),
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
          'New Customer Receipt',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
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
          const Icon(
            Icons.search,
            size: 19,
            color: _kMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (value) => _controller.searchQuery.value = value,
              textAlign: TextAlign.start,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search by receipt no, customer, invoice…',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: _kMuted,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Obx(
            () => _controller.searchQuery.value.isEmpty
                ? const SizedBox.shrink()
                : InkWell(
                    onTap: () {
                      _search.clear();
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

  Widget _buildSavedReceiptsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SAVED CUSTOMER RECEIPTS',
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
                  'Saved Receipts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '${_controller.filteredReceipts.length} receipts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Obx(() {
          if (_controller.isLoadingList.value && _controller.receipts.isEmpty) {
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
            return _stateContainer(
              icon: Icons.error_outline,
              iconColor: const Color(0xFFB3261E),
              title: _controller.listError.value,
              description: 'Check your connection and try again.',
              action: TextButton(
                onPressed: _controller.loadCustomerReceipts,
                child: const Text('Retry'),
              ),
            );
          }
          final receipts = _controller.filteredReceipts;
          if (receipts.isEmpty) {
            return _stateContainer(
              icon: Icons.description_outlined,
              iconColor: _kGreen,
              title: _controller.searchQuery.value.isEmpty
                  ? 'No saved customer receipts'
                  : 'No matching receipts',
              description: _controller.searchQuery.value.isEmpty
                  ? 'Your saved customer receipts will appear here once you create one.'
                  : 'Try a different receipt number, customer or invoice.',
            );
          }
          return Column(children: receipts.map(_receiptCard).toList());
        }),
      ],
    );
  }

  Widget _receiptCard(CustomerReceipt receipt) {
    final editable = receipt.status.trim().toLowerCase() == 'draft';
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
                  receipt.receiptNumber.isEmpty
                      ? 'Receipt'
                      : receipt.receiptNumber,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ),
              _buildPaymentBadge(receipt.paymentMode),
              const SizedBox(width: 4),
              _buildStatusBadge(receipt.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _controller.customerName(receipt.customerId),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: _kMuted),
          ),
          if (receipt.invoiceNumber.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              receipt.invoiceMode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _kMuted),
            ),
            Text(
              'Invoice ${receipt.invoiceNumber}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
              Expanded(
                child: Text(
                  _formatDisplayDate(receipt.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: _kMuted),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '₹${_formatAmount(receipt.amount)}/-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _kLine),
          const SizedBox(height: 10),
          Obx(() {
            final busy = _controller.isSaving.value;
            return Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _buildAction(
                  Icons.visibility_outlined,
                  'View',
                  _kGreen,
                  () => _showReceipt(receipt),
                ),
                if (editable) ...[
                  if (!busy && receipt.id.isNotEmpty)
                    _buildAction(
                      Icons.edit_outlined,
                      'Edit',
                      _kGreen,
                      () => Get.toNamed<void>(
                        Routes.editCustomerReceipt,
                        arguments: receipt.id,
                      ),
                    ),
                  if (!busy && receipt.id.isNotEmpty)
                    _buildAction(
                      Icons.check_circle_outline,
                      'Approve',
                      const Color(0xFF0E8F86),
                      () => _confirmApprove(receipt),
                    ),
                  if (!busy && receipt.id.isNotEmpty)
                    _buildAction(
                      Icons.delete_outline,
                      'Delete',
                      const Color(0xFFB3261E),
                      () => _confirmDelete(receipt),
                    ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  void _showReceipt(CustomerReceipt receipt) {
    Get.dialog<void>(
      AlertDialog(
        title: Text(
          receipt.receiptNumber.isEmpty
              ? 'Customer Receipt'
              : receipt.receiptNumber,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail('Date', receipt.date),
              _detail('Customer', _controller.customerName(receipt.customerId)),
              _detail('Invoice Mode', receipt.invoiceMode),
              _detail('Invoice No', receipt.invoiceNumber),
              _detail('Payment Mode', receipt.paymentMode),
              _detail('Amount', receipt.amount.toStringAsFixed(2)),
              _detail('Status',
                  receipt.status.isEmpty ? 'Unknown' : receipt.status),
              _detail('Remarks', receipt.remarks),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: const TextStyle(fontSize: 13, color: _kInk),
              ),
            ),
          ],
        ),
      );

  Future<void> _confirmApprove(CustomerReceipt receipt) async {
    final confirmed = await Get.dialog<bool>(
      CustomConfirmationDialog(
        header: 'Approve Customer Receipt',
        body:
            'Are you sure you want to approve ${receipt.receiptNumber.isEmpty ? 'this receipt' : receipt.receiptNumber}?',
        yesText: 'Approve',
        noText: 'Cancel',
        onYes: () => Get.back<bool>(result: true),
        onNo: () => Get.back<bool>(result: false),
      ),
    );
    if (confirmed == true) {
      await _controller.approveReceipt(receipt);
    }
  }

  Future<void> _confirmDelete(CustomerReceipt receipt) async {
    final confirmed = await Get.dialog<bool>(
      CustomConfirmationDialog(
        header: 'Delete Customer Receipt',
        body: 'Receipt ${receipt.receiptNumber} will be permanently deleted.',
        yesText: 'Delete',
        noText: 'Cancel',
        onYes: () => Get.back<bool>(result: true),
        onNo: () => Get.back<bool>(result: false),
      ),
    );
    if (confirmed == true) {
      await _controller.deleteReceipt(receipt);
    }
  }

  Widget _buildPaymentBadge(String paymentMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kMint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        paymentMode.isEmpty ? 'Payment' : paymentMode,
        style: const TextStyle(
          color: _kGreen,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final normalized = status.trim();
    final isApproved = normalized.toLowerCase() == 'approved';
    final isDraft = normalized.toLowerCase() == 'draft';
    final color = isApproved
        ? _kGreen
        : isDraft
            ? const Color(0xFFE9A23B)
            : _kMuted;
    final tint = isApproved
        ? _kMint
        : isDraft
            ? const Color(0xFFFDF2E2)
            : const Color(0xFFF1F3F1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        normalized.isEmpty ? 'Unknown' : normalized,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
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

  Widget _stateContainer({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    Widget? action,
    Color background = Colors.white,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 32,
        horizontal: 24,
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
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: background == Colors.white ? _kMint : background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: iconColor),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: _kMuted,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            action,
          ],
        ],
      ),
    );
  }
}
