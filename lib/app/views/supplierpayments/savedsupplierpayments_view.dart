import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/supplierpayments/supplier_payment_controller.dart';
import '../../models/supplier_payment.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

const _ink = AppColors.textDefaultLight;
const _muted = AppColors.textLightGrayLight;
const _line = AppColors.borderLightGrayLight;
const _green = AppColors.primaryLight;

class SavedSupplierPaymentsView extends StatefulWidget {
  const SavedSupplierPaymentsView({super.key});

  @override
  State<SavedSupplierPaymentsView> createState() =>
      _SavedSupplierPaymentsViewState();
}

class _SavedSupplierPaymentsViewState extends State<SavedSupplierPaymentsView> {
  final SupplierPaymentController _controller =
      Get.find<SupplierPaymentController>();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.loadSupplierPayments();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppGradients.pageBackground,
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _controller.refreshSupplierPayments,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 20),
                      _newPaymentButton(),
                      const SizedBox(height: 16),
                      _searchBar(),
                      const SizedBox(height: 24),
                      _paymentList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _header() => Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Get.back<void>(),
            icon: const Icon(Icons.arrow_back_ios_new, color: _ink),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supplier Payments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Saved supplier payments',
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _controller.loadSupplierPayments,
            icon: const Icon(Icons.refresh, color: _muted),
          ),
        ],
      );

  Widget _newPaymentButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await Get.toNamed<void>(Routes.newSupplierPayment);
            await _controller.loadSupplierPayments();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.add_circle_outline, size: 20),
          label: const Text(
            'Add New Supplier Payment',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      );

  Widget _searchBar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 19, color: _muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (value) => _controller.searchQuery.value = value,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search by payment number or supplier',
                  hintStyle: TextStyle(fontSize: 13.5, color: _muted),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            Obx(
              () => _controller.searchQuery.value.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        _controller.searchSupplierPayments('');
                      },
                      icon: const Icon(Icons.close, size: 18, color: _muted),
                    ),
            ),
          ],
        ),
      );

  Widget _paymentList() => Obx(() {
        if (_controller.isLoadingList.value && _controller.payments.isEmpty) {
          return _stateCard(
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: CircularProgressIndicator(color: _green),
              ),
            ),
          );
        }
        if (_controller.hasListError.value) {
          return _stateCard(
            Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 38,
                  color: Color(0xFFB3261E),
                ),
                const SizedBox(height: 8),
                Text(_controller.listError.value, textAlign: TextAlign.center),
                TextButton(
                  onPressed: _controller.loadSupplierPayments,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final records = _controller.filteredPayments;
        if (records.isEmpty) {
          final searched = _controller.searchQuery.value.isNotEmpty;
          return _stateCard(
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Icon(
                    searched ? Icons.search_off : Icons.payments_outlined,
                    size: 36,
                    color: _muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    searched
                        ? 'No supplier payments match your search.'
                        : 'No saved supplier payments.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${records.length} payments',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _green,
              ),
            ),
            const SizedBox(height: 10),
            for (final payment in records) _paymentCard(payment),
          ],
        );
      });

  Widget _paymentCard(SupplierPayment payment) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
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
                    payment.paymentNumber.isEmpty
                        ? 'Supplier Payment'
                        : payment.paymentNumber,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                _badge(payment.paymentMode),
                const SizedBox(width: 6),
                _badge(payment.approved ? 'Approved' : 'Draft'),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              payment.supplierName.isEmpty
                  ? payment.supplierId
                  : payment.supplierName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 4),
            Text(
              payment.invoiceMode == 'Cumulative'
                  ? 'Cumulative'
                  : 'Invoice by Invoice',
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: _muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _displayDate(payment.date),
                    style: const TextStyle(fontSize: 12.5, color: _muted),
                  ),
                ),
                Text(
                  '₹${_formatAmount(payment.amount)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: _line),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _action(
                  Icons.visibility_outlined,
                  'View',
                  () => _openPayment(payment, Routes.viewSupplierPayment),
                ),
                _action(
                  Icons.edit_outlined,
                  'Edit',
                  () => _openPayment(payment, Routes.editSupplierPayment),
                ),
              ],
            ),
          ],
        ),
      );

  Future<void> _openPayment(SupplierPayment payment, String route) async {
    if (payment.id.isEmpty) return;
    await Get.toNamed<void>(route, arguments: payment.id);
    await _controller.loadSupplierPayments();
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: _green),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _green,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: _green,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _stateCard(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: child,
      );

  String _displayDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _formatAmount(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
