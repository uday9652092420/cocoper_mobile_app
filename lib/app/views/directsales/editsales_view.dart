import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/direct_sale.dart';
import 'new_direct_sale_view.dart';
import 'viewsavedsale_view.dart';

/// Opens the existing Direct Sales form in edit mode for a selected record.
///
/// This screen reuses the same New Direct Sale form so the editing workflow,
/// validation, and calculations stay consistent with the app's current
/// architecture. Pending records can be updated through the existing Direct
/// Sales update endpoint; approved records are routed to their read-only view.
class EditSalesView extends StatelessWidget {
  const EditSalesView({super.key});

  @override
  Widget build(BuildContext context) {
    final sale =
        Get.arguments is DirectSale ? Get.arguments as DirectSale : null;
    if (sale?.approved == true) {
      return const ViewSavedSaleView();
    }
    return NewDirectSaleView(sale: sale);
  }
}
