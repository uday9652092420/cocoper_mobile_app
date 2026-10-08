import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/purchase_invoice.dart';
import 'newpurchaseinvoice_view.dart';

/// Opens the shared Purchase Invoice form in edit mode.
///
/// The [PurchaseInvoice] to edit is passed as a route argument.
class EditPurchaseInvoiceView extends StatelessWidget {
  const EditPurchaseInvoiceView({super.key});

  @override
  Widget build(BuildContext context) {
    final invoice = Get.arguments as PurchaseInvoice?;
    return NewPurchaseInvoiceView(invoice: invoice);
  }
}
