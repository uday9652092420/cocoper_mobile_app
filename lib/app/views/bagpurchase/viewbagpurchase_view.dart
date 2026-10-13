import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/bagpurchase/bag_purchase_controller.dart';
import '../../models/bag_purchase.dart';
import '../../routes/app_routes.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF5C6B66);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);

class ViewBagPurchaseView extends StatefulWidget {
  const ViewBagPurchaseView({super.key});

  @override
  State<ViewBagPurchaseView> createState() => _ViewBagPurchaseViewState();
}

class _ViewBagPurchaseViewState extends State<ViewBagPurchaseView> {
  final BagPurchaseController _controller = Get.find<BagPurchaseController>();
  String _id = '';
  String? _branchId;

  @override
  void initState() {
    super.initState();
    final argument = Get.arguments;
    if (argument is BagPurchase && argument.id.isNotEmpty) {
      _id = argument.id;
      _branchId = argument.branchId;
      _controller.loadPurchase(_id, branchId: _branchId);
    } else {
      _controller.detailError.value = 'Bag purchase record is unavailable.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
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
                child: Obx(() {
                  if (_controller.isLoadingDetail.value) {
                    return const Center(
                      child: CircularProgressIndicator(color: _kGreen),
                    );
                  }
                  if (_controller.detailError.value.isNotEmpty) {
                    return _buildError();
                  }
                  final purchase = _controller.detail.value;
                  if (purchase == null) {
                    return _buildError(
                      message: 'Bag purchase record was not found.',
                    );
                  }
                  return _buildContent(purchase);
                }),
              ),
            ],
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
          IconButton(
            tooltip: 'Back',
            onPressed: () => Get.back<void>(),
            icon: const Icon(Icons.arrow_back_ios_new, color: _kInk),
          ),
          const Expanded(
            child: Text(
              'Bag Purchase Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
          ),
          Obx(() {
            final purchase = _controller.detail.value;
            if (purchase == null) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Edit',
              onPressed: () async {
                await Get.toNamed<void>(
                  Routes.editBagPurchase,
                  arguments: purchase,
                );
                if (_id.isNotEmpty) {
                  await _controller.loadPurchase(_id, branchId: _branchId);
                }
              },
              icon: const Icon(Icons.edit_outlined, color: _kGreen),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContent(BagPurchase purchase) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _card(
                children: [
                  _row('Purchase No', purchase.purchaseNumber),
                  _row('Purchase Date', _formatDate(purchase.purchaseDate)),
                  _row('Supplier', purchase.supplierName),
                  if (purchase.branchName.isNotEmpty)
                    _row('Branch', purchase.branchName),
                  if (purchase.remarks.isNotEmpty)
                    _row('Remarks', purchase.remarks),
                  _row('Total Amount', _currency(purchase.totalAmount)),
                ],
              ),
              const SizedBox(height: 12),
              _card(
                children: [
                  const Text(
                    'Purchase Lines',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (purchase.lines.isEmpty)
                    const Text(
                      'No line details were returned.',
                      style: TextStyle(color: _kMuted),
                    ),
                  for (var index = 0; index < purchase.lines.length; index++)
                    _line(purchase.lines[index], index + 1),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(BagPurchaseLine line, int index) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.gunnyBagName.isEmpty ? 'Bag $index' : line.gunnyBagName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text('Qty: ${_number(line.quantity)}'),
              Text('Rate: ${_currency(line.rate)}'),
              Text('Amount: ${_currency(line.amount)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError({String? message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 10),
            Text(
              message ?? _controller.detailError.value,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _id.isEmpty
                  ? null
                  : () => _controller.loadPurchase(
                        _id,
                        branchId: _branchId,
                      ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: _kMuted)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value) ??
        DateFormat('d/M/yyyy').tryParse(value) ??
        DateFormat('dd/MM/yyyy').tryParse(value);
    return date == null ? value : DateFormat('d/M/yyyy').format(date);
  }

  String _currency(double value) =>
      '₹${NumberFormat('#,##0.##').format(value)}';

  String _number(double value) => NumberFormat('#,##0.##').format(value);
}
