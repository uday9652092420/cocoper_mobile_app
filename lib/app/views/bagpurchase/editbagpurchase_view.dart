import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/bagpurchase/bag_purchase_controller.dart';
import '../../models/bag_purchase.dart';
import '../../theme/app_theme.dart';
import 'newbagpurchase_view.dart';

class EditBagPurchaseView extends StatefulWidget {
  const EditBagPurchaseView({super.key});

  @override
  State<EditBagPurchaseView> createState() => _EditBagPurchaseViewState();
}

class _EditBagPurchaseViewState extends State<EditBagPurchaseView> {
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
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Obx(() {
          if (_controller.isLoadingDetail.value) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryLight,
              ),
            );
          }
          if (_controller.detailError.value.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _controller.detailError.value,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _id.isEmpty
                          ? null
                          : () => _controller.loadPurchase(
                                _id,
                                branchId: _branchId,
                              ),
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () => Get.back<void>(),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            );
          }
          final purchase = _controller.detail.value;
          if (purchase == null) {
            return const Center(child: Text('Bag purchase record not found.'));
          }
          return NewBagPurchaseView(purchase: purchase);
        }),
      ),
    );
  }
}
