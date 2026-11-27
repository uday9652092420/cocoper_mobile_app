import 'package:cocoper_mobile/app/models/finance_journal.dart';
import 'package:cocoper_mobile/app/services/endpoints.dart';
import 'package:cocoper_mobile/app/services/finance_journal_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Response<dynamic> _response(String path, dynamic data, {int status = 200}) =>
    Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
      data: data,
    );

void main() {
  test('lists journals using the source type and selected branch', () async {
    final calls = <({String endpoint, Map<String, dynamic>? query})>[];
    final service = FinanceJournalService(
      get: (endpoint, {queryParameters}) async {
        calls.add((endpoint: endpoint, query: queryParameters));
        return _response(endpoint, {
          'success': true,
          'data': [
            {
              'id': 'journal-1',
              'voucherNumber': 'PC-000001',
              'date': '2026-11-26',
              'status': 'Draft',
              'sourceType': 'petty-cash',
              'debit': '250.0000',
              'credit': '250.0000',
            },
          ],
        });
      },
    );

    final entries = await service.fetchJournals(
      sourceType: 'petty-cash',
      branchId: 'branch-1',
    );

    expect(calls.single.endpoint, EndPoints.financeJournals);
    expect(calls.single.query, {
      'sourceType': 'petty-cash',
      'branchId': 'branch-1',
    });
    expect(entries.single.voucherNumber, 'PC-000001');
    expect(entries.single.debit, 250);
  });

  test('decodes journal detail lines and account options', () async {
    final service = FinanceJournalService(
      get: (endpoint, {queryParameters}) async {
        if (endpoint == EndPoints.financeAccounts) {
          return _response(endpoint, {
            'success': true,
            'data': [
              {
                'id': 'account-1',
                'code': 'EX7000',
                'name': 'Office Expense',
                'accountType': 'Expenses',
                'subType': 'Account',
                'isActive': true,
              },
            ],
          });
        }
        return _response(endpoint, {
          'success': true,
          'data': {
            'id': 'journal-1',
            'voucherNumber': 'JV-000001',
            'date': '2026-11-26',
            'status': 'Draft',
            'sourceType': 'journal-entry',
            'lines': [
              {
                'accountId': 'account-1',
                'accountCode': 'EX7000',
                'accountName': 'Office Expense',
                'debit': '100.0000',
                'credit': '0.0000',
                'narration': 'Office supplies',
              },
              {
                'accountId': 'account-2',
                'accountCode': 'AS1000',
                'accountName': 'Cash',
                'debit': '0.0000',
                'credit': '100.0000',
              },
            ],
          },
        });
      },
    );

    final journal = await service.fetchJournal('journal-1');
    final accounts = await service.fetchAccounts();

    expect(journal.lines, hasLength(2));
    expect(journal.lines.first.accountName, 'Office Expense');
    expect(journal.lines.first.debitValue, 100);
    expect(journal.debit, 0);
    expect(journal.hasBalancedLines, isTrue);
    expect(
      const FinanceJournal(
        id: 'journal-2',
        date: '2026-11-26',
        status: 'Draft',
        sourceType: 'journal-entry',
        lines: [
          FinanceJournalLine(
            accountId: 'account-1',
            debit: '100.0001',
            credit: '0',
          ),
          FinanceJournalLine(
            accountId: 'account-2',
            debit: '0',
            credit: '100.0000',
          ),
        ],
      ).hasBalancedLines,
      isFalse,
    );
    expect(accounts.single.label, 'EX7000 · Office Expense');
  });

  test('loads cash account mappings from the finance bank accounts endpoint',
      () async {
    final calls = <String>[];
    final service = FinanceJournalService(
      get: (endpoint, {queryParameters}) async {
        calls.add(endpoint);
        return _response(endpoint, {
          'success': true,
          'data': [
            {
              'id': 'cash-record-1',
              'name': 'Main cash',
              'type': 'Cash',
              'ledgerAccountId': 'account-1',
              'ledgerAccountCode': 'AS1000',
              'ledgerAccountName': 'Cash on hand',
              'isActive': true,
            },
          ],
        });
      },
    );

    final accounts = await service.fetchBankAccounts();

    expect(calls.single, EndPoints.financeBankAccounts);
    expect(accounts.single.type, 'Cash');
    expect(accounts.single.ledgerAccountId, 'account-1');
    expect(accounts.single.isActive, isTrue);
  });

  test('surfaces backend errors and preserves the error code', () async {
    final service = FinanceJournalService(
      get: (endpoint, {queryParameters}) async => _response(
        endpoint,
        {
          'success': false,
          'message': 'Finance permission required.',
          'code': 'MOBILE_PERMISSION_REQUIRED',
        },
        status: 403,
      ),
    );

    await expectLater(
      service.fetchJournals(sourceType: 'journal-entry'),
      throwsA(
        isA<FinanceJournalApiException>()
            .having((error) => error.code, 'code', 'MOBILE_PERMISSION_REQUIRED')
            .having(
              (error) => error.message,
              'message',
              'Finance permission required.',
            ),
      ),
    );
  });

  test('identifies expired sessions explicitly', () async {
    final service = FinanceJournalService(
      get: (endpoint, {queryParameters}) async => _response(
        endpoint,
        {'success': false, 'message': 'Authentication is required.'},
        status: 401,
      ),
    );

    await expectLater(
      service.fetchJournals(sourceType: 'journal-entry'),
      throwsA(
        isA<FinanceJournalApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having(
              (error) => error.message,
              'message',
              'Your session has expired. Please sign in again.',
            ),
      ),
    );
  });

  test('rejects incomplete account records instead of showing invalid options',
      () async {
    final service = FinanceJournalService(
      get: (endpoint, {queryParameters}) async => _response(endpoint, {
        'success': true,
        'data': [
          {'id': 'account-1', 'code': 'EX7000'},
        ],
      }),
    );

    await expectLater(
      service.fetchAccounts(),
      throwsA(isA<FormatException>()),
    );
  });

  test('journal line model accepts snake-case API fields', () {
    final line = FinanceJournalLine.fromJson({
      'account_id': 'account-1',
      'account_code': 'AS1000',
      'account_name': 'Cash',
      'branch_id': 'branch-1',
      'debit': '250.0000',
      'credit': '0.0000',
    });

    expect(line.accountId, 'account-1');
    expect(line.accountName, 'Cash');
    expect(line.branchId, 'branch-1');
  });
}
