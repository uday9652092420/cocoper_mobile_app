import 'package:flutter/material.dart';

import 'supplier_payment_form.dart';

class EditSupplierPaymentView extends StatelessWidget {
  const EditSupplierPaymentView({
    super.key,
    required this.paymentId,
  });

  final String paymentId;

  @override
  Widget build(BuildContext context) => SupplierPaymentFormView(
        isEdit: true,
        paymentId: paymentId,
      );
}
