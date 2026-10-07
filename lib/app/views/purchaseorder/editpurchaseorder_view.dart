import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/purchase_order.dart';
import 'newpurchaseorder_view.dart';

/// Opens the shared Purchase Order form in edit mode.
///
/// The [PurchaseOrder] to edit is passed as a route argument.
class EditPurchaseOrderView extends StatelessWidget {
  const EditPurchaseOrderView({super.key});

  @override
  Widget build(BuildContext context) {
    final order = Get.arguments as PurchaseOrder?;
    return NewPurchaseOrderView(order: order);
  }
}
