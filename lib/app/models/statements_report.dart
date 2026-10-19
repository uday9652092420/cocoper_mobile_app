enum StatementsReportType {
  purchaseRegister,
  salesRegister,
  supplierStatement,
  customerStatement,
  pendingDispatch,
}

enum StatementsReportSortField {
  date,
  reference,
  partyName,
  transactionType,
  branch,
  amount,
  debit,
  credit,
  balance,
  status,
  lorryNumber,
  driverName,
  quantity,
}

class StatementsReportSortOption {
  const StatementsReportSortOption({
    required this.field,
    required this.label,
  });

  final StatementsReportSortField field;
  final String label;
}

class StatementsReportRecord {
  const StatementsReportRecord({
    required this.id,
    required this.date,
    required this.reference,
    required this.partyId,
    required this.partyName,
    required this.branchId,
    required this.branchName,
    required this.description,
    required this.amount,
    required this.debit,
    required this.credit,
    required this.status,
    this.balance = 0,
    this.totalQuantity = 0,
    this.loadedQuantity = 0,
    this.pendingQuantity = 0,
    this.branchIds = const [],
    this.partyType = '',
    this.transactionType = '',
    this.driverMobile = '',
    this.lorryNumber = '',
    this.driverName = '',
  });

  final String id;
  final DateTime? date;
  final String reference;
  final String partyId;
  final String partyName;
  final String branchId;
  final String branchName;
  final String description;
  final double amount;
  final double debit;
  final double credit;
  final String status;
  final double balance;
  final double totalQuantity;
  final double loadedQuantity;
  final double pendingQuantity;
  final List<String> branchIds;
  final String partyType;
  final String transactionType;
  final String driverMobile;
  final String lorryNumber;
  final String driverName;

  StatementsReportRecord withBalance(double value) => StatementsReportRecord(
        id: id,
        date: date,
        reference: reference,
        partyId: partyId,
        partyName: partyName,
        branchId: branchId,
        branchName: branchName,
        description: description,
        amount: amount,
        debit: debit,
        credit: credit,
        status: status,
        balance: value,
        totalQuantity: totalQuantity,
        loadedQuantity: loadedQuantity,
        pendingQuantity: pendingQuantity,
        branchIds: branchIds,
        partyType: partyType,
        transactionType: transactionType,
        driverMobile: driverMobile,
        lorryNumber: lorryNumber,
        driverName: driverName,
      );
}
