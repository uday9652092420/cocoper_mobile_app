import 'package:cocoper_mobile/app/models/cash_bank_expense_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the backend expense fields and embedded attachment metadata',
      () {
    final expense = CashBankExpense.fromJson({
      'id': 'CBE-123',
      'organizationId': 'organization-id',
      'branchId': 'branch-id',
      'branch': 'Main Branch',
      'date': '2026-10-17T00:00:00.000Z',
      'paymentMode': 'Bank',
      'transactionType': 'Expenses',
      'amount': '45.25',
      'description': 'Office supplies',
      'attachments': [
        {
          'name': 'proof.pdf',
          'mimeType': 'application/pdf',
          'data': 'data:application/pdf;base64,AQID',
        },
      ],
      'approved': false,
      'createdAt': '2026-10-17 12:00:00',
    });

    expect(expense.id, 'CBE-123');
    expect(expense.organizationId, 'organization-id');
    expect(expense.branchId, 'branch-id');
    expect(expense.branch, 'Main Branch');
    expect(expense.date, '2026-10-17');
    expect(expense.amount, 45.25);
    expect(expense.hasAttachmentField, isTrue);
    expect(expense.hasValidAttachmentData, isTrue);
    expect(expense.attachments.single.name, 'proof.pdf');

    expect(
      expense.toRequestJson()['attachments'],
      [
        {
          'name': 'proof.pdf',
          'mimeType': 'application/pdf',
          'data': 'data:application/pdf;base64,AQID',
        },
      ],
    );
  });

  test(
      'distinguishes valid empty attachment data from missing or malformed data',
      () {
    final empty = CashBankExpense.fromJson({
      'id': 'CBE-empty',
      'attachments': <dynamic>[],
    });
    final missing = CashBankExpense.fromJson({'id': 'CBE-missing'});
    final malformed = CashBankExpense.fromJson({
      'id': 'CBE-malformed',
      'attachments': <dynamic>[null],
    });

    expect(empty.hasAttachmentField, isTrue);
    expect(empty.hasValidAttachmentData, isTrue);
    expect(missing.hasAttachmentField, isFalse);
    expect(missing.hasValidAttachmentData, isFalse);
    expect(malformed.hasAttachmentField, isTrue);
    expect(malformed.hasValidAttachmentData, isFalse);
  });

  test('parses branches using the backend snake_case organization field', () {
    final branch = CashBankBranch.fromJson({
      'id': 'branch-id',
      'organization_id': 'organization-id',
      'branch_name': 'North',
      'status': 'ACTIVE',
    });

    expect(branch.id, 'branch-id');
    expect(branch.organizationId, 'organization-id');
    expect(branch.name, 'North');
    expect(branch.status, 'ACTIVE');
  });
}
