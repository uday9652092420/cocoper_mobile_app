import 'package:flutter/material.dart';

import 'customer_receipt_form.dart';

class NewCustomerReceiptView extends StatelessWidget {
  const NewCustomerReceiptView({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomerReceiptFormView(isEdit: false);
}