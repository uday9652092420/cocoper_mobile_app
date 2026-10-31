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
    final arguments = Get.arguments;
    final order = arguments is PurchaseOrder
        ? arguments
        : arguments is Map && arguments['order'] is PurchaseOrder
            ? arguments['order'] as PurchaseOrder
            : null;
    final readOnly = arguments is Map && arguments['readOnly'] == true;
    return NewPurchaseOrderView(order: order, readOnly: readOnly);
  }
}
