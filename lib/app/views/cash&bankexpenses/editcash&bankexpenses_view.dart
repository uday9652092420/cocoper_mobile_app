// ignore_for_file: file_names

import 'package:flutter/material.dart';

import 'cash_bank_expense_form.dart';

class EditCashBankExpenseView extends StatelessWidget {
  const EditCashBankExpenseView({
    super.key,
    required this.expenseId,
  });

  final String expenseId;

  @override
  Widget build(BuildContext context) => CashBankExpenseFormView(
        isEdit: true,
        expenseId: expenseId,
      );
}
