// ignore_for_file: file_names

import 'package:flutter/material.dart';

import 'cash_bank_expense_form.dart';

class NewCashBankExpenseView extends StatelessWidget {
  const NewCashBankExpenseView({super.key});

  @override
  Widget build(BuildContext context) =>
      const CashBankExpenseFormView(isEdit: false);
}
