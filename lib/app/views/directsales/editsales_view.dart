import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/direct_sale.dart';
import 'new_direct_sale_view.dart';

/// Opens the existing Direct Sales form in edit mode for a selected record.
///
/// This screen reuses the same New Direct Sale form so the editing workflow,
/// validation, and calculations stay consistent with the app's current
/// architecture. The backend contract currently has no persistent Direct Sales
/// update endpoint, so the form is populated from the selected record and the
/// save action is intentionally blocked until a verified update contract exists.
class EditSalesView extends StatelessWidget {
  const EditSalesView({super.key});

  @override
  Widget build(BuildContext context) {
    final sale =
        Get.arguments is DirectSale ? Get.arguments as DirectSale : null;
    return NewDirectSaleView(sale: sale);
  }
}
