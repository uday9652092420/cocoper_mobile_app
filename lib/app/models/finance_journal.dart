class FinanceJournalLine {
  const FinanceJournalLine({
    required this.accountId,
    required this.debit,
    required this.credit,
    this.id = '',
    this.accountCode = '',
    this.accountName = '',
    this.branchId = '',
    this.narration = '',
  });

  final String id;
  final String accountId;
  final String accountCode;
  final String accountName;
  final String branchId;
  final String narration;
  final String debit;
  final String credit;

  factory FinanceJournalLine.fromJson(Map<String, dynamic> json) =>
      FinanceJournalLine(
        id: _text(json['id']),
        accountId: _text(json['accountId'] ?? json['account_id']),
        accountCode: _text(json['accountCode'] ?? json['account_code']),
        accountName: _text(json['accountName'] ?? json['account_name']),
        branchId: _text(json['branchId'] ?? json['branch_id']),
        narration: _text(json['narration'] ?? json['description']),
        debit: _amountText(json['debit']),
        credit: _amountText(json['credit']),
      );

  Map<String, dynamic> toRequestJson(String selectedBranchId) =>
      <String, dynamic>{
        'accountId': accountId,
        'branchId': selectedBranchId,
        'debit': debit,
        'credit': credit,
        'narration': narration.trim(),
      };

  double get debitValue => double.tryParse(debit) ?? 0;
  double get creditValue => double.tryParse(credit) ?? 0;
}

class FinanceJournal {
  const FinanceJournal({
    required this.id,
    required this.date,
    required this.status,
    required this.sourceType,
    this.voucherNumber = '',
    this.reference = '',
    this.description = '',
    this.branchId = '',
    this.branchName = '',
    this.amount = 0,
    this.debit = 0,
    this.credit = 0,
    this.lines = const [],
  });

  final String id;
  final String voucherNumber;
  final String date;
  final String reference;
  final String description;
  final String status;
  final String sourceType;
  final String branchId;
  final String branchName;
  final double amount;
  final double debit;
  final double credit;
  final List<FinanceJournalLine> lines;

  bool get hasBalancedLines {
    var debitUnits = BigInt.zero;
    var creditUnits = BigInt.zero;
    for (final line in lines) {
      final lineDebit = parseFinanceAmountUnits(line.debit);
      final lineCredit = parseFinanceAmountUnits(line.credit);
      if (lineDebit == null || lineCredit == null) return false;
      debitUnits += lineDebit;
      creditUnits += lineCredit;
    }
    return debitUnits > BigInt.zero && debitUnits == creditUnits;
  }

  factory FinanceJournal.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    if (rawLines != null && rawLines is! List) {
      throw const FormatException('Journal lines must be a list.');
    }
    return FinanceJournal(
      id: _text(json['id']),
      voucherNumber: _text(json['voucherNumber'] ?? json['voucher_number']),
      date: _dateText(json['date'] ?? json['entry_date']),
      reference: _text(json['reference']),
      description: _text(json['description']),
      status: _text(json['status']),
      sourceType: _text(json['sourceType'] ?? json['source_type']),
      branchId: _text(json['branchId'] ?? json['branch_id']),
      branchName: _text(json['branchName'] ?? json['branch_name']),
      amount: _number(json['amount']),
      debit: _number(json['debit']),
      credit: _number(json['credit']),
      lines: rawLines == null
          ? const []
          : (rawLines as List).map((row) {
              if (row is! Map) {
                throw const FormatException('Invalid journal line.');
              }
              return FinanceJournalLine.fromJson(
                Map<String, dynamic>.from(row),
              );
            }).toList(growable: false),
    );
  }
}

class FinanceAccount {
  const FinanceAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.accountType,
    required this.subType,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String accountType;
  final String subType;
  final bool isActive;

  String get label => '$code · $name';

  factory FinanceAccount.fromJson(Map<String, dynamic> json) {
    final account = FinanceAccount(
      id: _text(json['id']),
      code: _text(json['code']),
      name: _text(json['name']),
      accountType: _text(json['accountType'] ?? json['account_type']),
      subType: _text(json['subType'] ?? json['sub_type']),
      isActive: _bool(json['isActive'] ?? json['is_active']),
    );
    if (account.id.isEmpty || account.code.isEmpty || account.name.isEmpty) {
      throw const FormatException('The server returned an incomplete account.');
    }
    return account;
  }
}

class FinanceBranch {
  const FinanceBranch({
    required this.id,
    required this.name,
    this.code = '',
  });

  final String id;
  final String name;
  final String code;

  factory FinanceBranch.fromJson(Map<String, dynamic> json) {
    final branch = FinanceBranch(
      id: _text(json['id']),
      name: _text(json['branch_name'] ?? json['branchName'] ?? json['name']),
      code: _text(json['branch_code'] ?? json['branchCode']),
    );
    if (branch.id.isEmpty || branch.name.isEmpty) {
      throw const FormatException('The server returned an incomplete branch.');
    }
    return branch;
  }
}

class FinanceBankAccount {
  const FinanceBankAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
    this.ledgerAccountId,
    this.ledgerAccountCode = '',
    this.ledgerAccountName = '',
  });

  final String id;
  final String name;
  final String type;
  final bool isActive;
  final String? ledgerAccountId;
  final String ledgerAccountCode;
  final String ledgerAccountName;

  factory FinanceBankAccount.fromJson(Map<String, dynamic> json) {
    final ledgerAccountId = _text(
      json['ledgerAccountId'] ?? json['ledger_account_id'],
    );
    final account = FinanceBankAccount(
      id: _text(json['id']),
      name: _text(json['name']),
      type: _text(json['type'] ?? json['account_type']),
      isActive: _bool(json['isActive'] ?? json['is_active']),
      ledgerAccountId: ledgerAccountId.isEmpty ? null : ledgerAccountId,
      ledgerAccountCode: _text(
        json['ledgerAccountCode'] ?? json['ledger_account_code'],
      ),
      ledgerAccountName: _text(
        json['ledgerAccountName'] ?? json['ledger_account_name'],
      ),
    );
    if (account.id.isEmpty || account.name.isEmpty || account.type.isEmpty) {
      throw const FormatException(
        'The server returned an incomplete bank account.',
      );
    }
    return account;
  }
}

String _text(dynamic value) => value?.toString().trim() ?? '';

BigInt? parseFinanceAmountUnits(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return BigInt.zero;
  if (!RegExp(r'^\d{1,16}(?:\.\d{1,4})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final fraction = parts.length > 1 ? parts[1].padRight(4, '0') : '0000';
  return BigInt.parse(parts[0]) * BigInt.from(10000) + BigInt.parse(fraction);
}

String _amountText(dynamic value) {
  if (value is num && !value.isFinite) {
    throw const FormatException('Journal amount is not finite.');
  }
  final text = _text(value);
  if (text.isEmpty) return '0';
  if (double.tryParse(text) == null) {
    throw const FormatException('Invalid journal amount.');
  }
  return text;
}

double _number(dynamic value) {
  final text = _amountText(value);
  final number = double.parse(text);
  if (!number.isFinite) throw const FormatException('Invalid amount.');
  return number;
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().trim().toLowerCase() == 'true';
}

String _dateText(dynamic value) {
  final text = _text(value);
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return text;
  return '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
}
