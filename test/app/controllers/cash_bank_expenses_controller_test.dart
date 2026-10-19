import 'package:cocoper_mobile/app/controllers/cash&bankexpenses/cash_bank_expenses_controller.dart';
import 'package:cocoper_mobile/app/models/cash_bank_expense_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validExpense = CashBankExpense(
    id: 'CBE-123',
    branchId: 'branch-id',
    date: '2026-10-17',
    paymentMode: 'Cash',
    transactionType: 'Expenses',
    amount: 12.5,
  );

  test('accepts valid create and edit values without requiring attachments',
      () {
    expect(
      CashBankExpensesController.validate(validExpense, isEdit: false),
      isNull,
    );
    expect(
      CashBankExpensesController.validate(validExpense, isEdit: true),
      isNull,
    );
  });

  test('requires an existing database ID for edit mode', () {
    expect(
      CashBankExpensesController.validate(
        const CashBankExpense(
          branchId: 'branch-id',
          date: '2026-10-17',
          paymentMode: 'Cash',
          transactionType: 'Expenses',
          amount: 12.5,
        ),
        isEdit: true,
      ),
      'The expense ID is missing.',
    );
  });

  test('rejects invalid required fields, dates, modes, and amounts', () {
    expect(
      CashBankExpensesController.validate(
        const CashBankExpense(
          branchId: '',
          date: '2026-10-17',
          paymentMode: 'Cash',
          transactionType: 'Expenses',
          amount: 12.5,
        ),
        isEdit: false,
      ),
      'Select a branch.',
    );
    expect(
      CashBankExpensesController.validate(
        validExpense.copyWith(date: '2026-02-30'),
        isEdit: false,
      ),
      'Enter a valid expense date.',
    );
    expect(
      CashBankExpensesController.validate(
        validExpense.copyWith(paymentMode: 'Cheque'),
        isEdit: false,
      ),
      'Select a supported payment mode.',
    );
    expect(
      CashBankExpensesController.validate(
        validExpense.copyWith(amount: 0),
        isEdit: false,
      ),
      'Enter an amount greater than zero.',
    );
  });

  test('limits attachments and rejects unsupported attachment types', () {
    final sixAttachments = List.generate(
      6,
      (index) => CashBankExpenseAttachment(
        name: 'proof-$index.pdf',
        mimeType: 'application/pdf',
        data: 'data:application/pdf;base64,AQID',
      ),
    );
    expect(
      CashBankExpensesController.validate(
        validExpense.copyWith(attachments: sixAttachments),
        isEdit: false,
      ),
      'You can attach up to 5 files.',
    );
    expect(
      CashBankExpensesController.validate(
        validExpense.copyWith(
          attachments: const [
            CashBankExpenseAttachment(
              name: 'proof.exe',
              mimeType: 'application/octet-stream',
              data: 'data:application/octet-stream;base64,AQID',
            ),
          ],
        ),
        isEdit: false,
      ),
      'The attachment data is invalid.',
    );
  });
}

extension on CashBankExpense {
  CashBankExpense copyWith({
    String? date,
    String? paymentMode,
    double? amount,
    List<CashBankExpenseAttachment>? attachments,
  }) =>
      CashBankExpense(
        id: id,
        organizationId: organizationId,
        branchId: branchId,
        branch: branch,
        date: date ?? this.date,
        paymentMode: paymentMode ?? this.paymentMode,
        transactionType: transactionType,
        amount: amount ?? this.amount,
        description: description,
        attachments: attachments ?? this.attachments,
        hasAttachmentField: hasAttachmentField,
        hasValidAttachmentData: hasValidAttachmentData,
        approved: approved,
        createdAt: createdAt,
      );
}
