import 'package:flutter/material.dart';

import 'customer_receipt_form.dart';

class EditCustomerReceiptView extends StatelessWidget {
  const EditCustomerReceiptView({
    super.key,
    required this.receiptId,
  });

  final String receiptId;

  @override
  Widget build(BuildContext context) =>
      CustomerReceiptFormView(isEdit: true, receiptId: receiptId);
}