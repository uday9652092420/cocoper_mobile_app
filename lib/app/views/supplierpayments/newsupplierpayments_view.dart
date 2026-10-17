import 'package:flutter/material.dart';

import 'supplier_payment_form.dart';

class NewSupplierPaymentView extends StatelessWidget {
  const NewSupplierPaymentView({super.key});

  @override
  Widget build(BuildContext context) =>
      const SupplierPaymentFormView(isEdit: false);
}
