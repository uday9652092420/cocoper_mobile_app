import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/statements_report.dart';
import '../repositories/statements_report_repository.dart';

class StatementsReportController extends GetxController {
  StatementsReportController({
    required this.type,
    required StatementsReportRepository repository,
  }) : _repository = repository;

  final StatementsReportType type;
  final StatementsReportRepository _repository;

  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final filterErrorMessage = ''.obs;
  final searchController = TextEditingController();
  final sourceRecords = <StatementsReportRecord>[].obs;
  final parties = <({String id, String name})>[].obs;
  final branches = <({String id, String name})>[].obs;
  final selectedPartyId = ''.obs;
  final selectedBranchId = ''.obs;
  final selectedType = ''.obs;
  final selectedStatus = ''.obs;
  final startDate = Rxn<DateTime>();
  final endDate = Rxn<DateTime>();
  final searchText = ''.obs;
  final sortField = StatementsReportSortField.date.obs;
  final sortAscending = false.obs;

  final draftPartyId = ''.obs;
  final draftBranchId = ''.obs;
  final draftType = ''.obs;
  final draftStatus = ''.obs;
  final draftStartDate = Rxn<DateTime>();
  final draftEndDate = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  bool get isStatement =>
      type == StatementsReportType.supplierStatement ||
      type == StatementsReportType.customerStatement;

  bool get isPurchaseRegister => type == StatementsReportType.purchaseRegister;

  bool get isSalesRegister => type == StatementsReportType.salesRegister;

  bool get isDispatch => type == StatementsReportType.pendingDispatch;

  bool get supportsPartyFilter =>
      isPurchaseRegister || isSalesRegister || isDispatch || isStatement;

  List<String> get availableStatuses => sourceRecords
      .map((record) => record.status.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<String> get availableTransactionTypes => sourceRecords
      .map((record) => isSalesRegister
          ? record.partyType.trim()
          : record.transactionType.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<StatementsReportSortOption> get sortOptions => switch (type) {
        StatementsReportType.purchaseRegister => const [
            StatementsReportSortOption(
              field: StatementsReportSortField.date,
              label: 'Invoice Date',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.reference,
              label: 'Invoice Number',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.partyName,
              label: 'Supplier Name',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.branch,
              label: 'Branch',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.amount,
              label: 'Amount',
            ),
          ],
        StatementsReportType.salesRegister => const [
            StatementsReportSortOption(
              field: StatementsReportSortField.date,
              label: 'Invoice Date',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.reference,
              label: 'Invoice Number',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.partyName,
              label: 'Customer Name',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.transactionType,
              label: 'Transaction Type',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.branch,
              label: 'Branch',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.amount,
              label: 'Amount',
            ),
          ],
        StatementsReportType.supplierStatement ||
        StatementsReportType.customerStatement =>
          const [
            StatementsReportSortOption(
              field: StatementsReportSortField.date,
              label: 'Transaction Date',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.reference,
              label: 'Voucher Number',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.transactionType,
              label: 'Transaction Type',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.debit,
              label: 'Debit',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.credit,
              label: 'Credit',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.balance,
              label: 'Running Balance',
            ),
          ],
        StatementsReportType.pendingDispatch => const [
            StatementsReportSortOption(
              field: StatementsReportSortField.date,
              label: 'Dispatch Date',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.reference,
              label: 'Dispatch Number',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.partyName,
              label: 'Customer',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.lorryNumber,
              label: 'Lorry Number',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.driverName,
              label: 'Driver Name',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.status,
              label: 'Status',
            ),
            StatementsReportSortOption(
              field: StatementsReportSortField.quantity,
              label: 'Quantity',
            ),
          ],
      };

  int get activeFilterCount {
    var count = 0;
    if (selectedPartyId.value.isNotEmpty) count++;
    if (selectedBranchId.value.isNotEmpty) count++;
    if (selectedType.value.isNotEmpty) count++;
    if (selectedStatus.value.isNotEmpty) count++;
    if (startDate.value != null) count++;
    if (endDate.value != null) count++;
    return count;
  }

  StatementsReportSortOption get selectedSortOption => sortOptions.firstWhere(
        (option) => option.field == sortField.value,
        orElse: () => sortOptions.first,
      );

  String get filterSummary {
    final values = <String>[];
    if (isStatement) {
      final party = parties
          .where((option) => option.id == selectedPartyId.value)
          .firstOrNull;
      values.add(party?.name ?? _partyAllLabel);
    } else if (supportsPartyFilter) {
      final party = parties
          .where((option) => option.id == selectedPartyId.value)
          .firstOrNull;
      values.add(party?.name ?? _partyAllLabel);
    }
    if (isSalesRegister || isStatement) {
      values.add(selectedType.value.isEmpty ? 'All Types' : selectedType.value);
    }
    if (isDispatch) {
      values.add(
        selectedStatus.value.isEmpty ? 'All Statuses' : selectedStatus.value,
      );
    }
    if (isPurchaseRegister || isSalesRegister) {
      final branch = branches
          .where((option) => option.id == selectedBranchId.value)
          .firstOrNull;
      values.add(branch?.name ?? 'All Branches');
    }
    if (startDate.value != null) {
      values.add('From ${_dateLabel(startDate.value!)}');
    }
    if (endDate.value != null) {
      values.add('To ${_dateLabel(endDate.value!)}');
    }
    return values.join(' · ');
  }

  List<({String key, String label})> get appliedFilterChips {
    final chips = <({String key, String label})>[];
    if (selectedPartyId.value.isNotEmpty) {
      final party = parties
          .where((option) => option.id == selectedPartyId.value)
          .firstOrNull;
      chips.add((key: 'party', label: party?.name ?? 'Party'));
    }
    if (selectedBranchId.value.isNotEmpty) {
      final branch = branches
          .where((option) => option.id == selectedBranchId.value)
          .firstOrNull;
      chips.add((key: 'branch', label: branch?.name ?? 'Branch'));
    }
    if (selectedType.value.isNotEmpty) {
      chips.add((key: 'type', label: selectedType.value));
    }
    if (selectedStatus.value.isNotEmpty) {
      chips.add((key: 'status', label: selectedStatus.value));
    }
    if (startDate.value != null) {
      chips.add((key: 'from', label: 'From ${_dateLabel(startDate.value!)}'));
    }
    if (endDate.value != null) {
      chips.add((key: 'to', label: 'To ${_dateLabel(endDate.value!)}'));
    }
    return chips;
  }

  String get sortSummary => '${selectedSortOption.label} · '
      '${sortAscending.value ? 'Ascending' : 'Descending'}';

  String get _partyAllLabel {
    if (isPurchaseRegister) return 'All Suppliers';
    if (isSalesRegister || isDispatch) return 'All Customers';
    return 'Select a party';
  }

  Future<void> load() async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final data = await _repository.load(type);
      sourceRecords.assignAll(data.records);
      parties.assignAll(data.parties);
      branches.assignAll(data.branches);
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  List<StatementsReportRecord> get visibleRecords {
    if (isStatement && selectedPartyId.value.isEmpty) {
      return const [];
    }

    final reportRecords = sourceRecords.where((record) {
      if (isStatement && record.partyId != selectedPartyId.value) {
        return false;
      }
      if (selectedPartyId.value.isNotEmpty &&
          supportsPartyFilter &&
          record.partyId != selectedPartyId.value) {
        return false;
      }
      if (selectedBranchId.value.isNotEmpty &&
          !record.branchIds.contains(selectedBranchId.value) &&
          record.branchId != selectedBranchId.value) {
        return false;
      }
      final typeValue =
          isSalesRegister ? record.partyType : record.transactionType;
      if (selectedType.value.isNotEmpty && typeValue != selectedType.value) {
        return false;
      }
      if (selectedStatus.value.isNotEmpty &&
          record.status.toLowerCase() != selectedStatus.value.toLowerCase()) {
        return false;
      }
      return true;
    }).toList()
      ..sort(_compareRecords);

    var balance = 0.0;
    final withBalances = <StatementsReportRecord>[];
    for (final record in reportRecords) {
      balance += record.debit - record.credit;
      if (!_withinAppliedDates(record.date)) continue;
      withBalances.add(record.withBalance(balance));
    }

    final query = searchText.value.trim().toLowerCase();
    final matchedRecords = withBalances.where((record) {
      if (query.isEmpty) return true;
      return <String>[
        record.reference,
        record.partyName,
        record.branchName,
        record.description,
        record.status,
        record.lorryNumber,
        record.driverName,
        record.driverMobile,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
    matchedRecords.sort(_compareBySelectedSort);
    return matchedRecords;
  }

  List<StatementsReportRecord> get _statementPeriodRecords {
    if (selectedPartyId.value.isEmpty) return const [];
    return sourceRecords.where((record) {
      if (record.partyId != selectedPartyId.value) return false;
      if (!_matchesSelectedType(record)) return false;
      return _withinAppliedDates(record.date);
    }).toList();
  }

  bool _matchesSelectedType(StatementsReportRecord record) =>
      selectedType.value.isEmpty ||
      record.transactionType == selectedType.value;

  bool _withinAppliedDates(DateTime? date) {
    if (startDate.value != null &&
        (date == null || _day(date).isBefore(_day(startDate.value!)))) {
      return false;
    }
    if (endDate.value != null &&
        (date == null || _day(date).isAfter(_day(endDate.value!)))) {
      return false;
    }
    return true;
  }

  double get openingBalance {
    if (!isStatement ||
        startDate.value == null ||
        selectedPartyId.value.isEmpty) {
      return 0;
    }
    final cutoff = _day(startDate.value!);
    return sourceRecords
        .where(
          (record) =>
              record.partyId == selectedPartyId.value &&
              _matchesSelectedType(record) &&
              record.date != null &&
              _day(record.date!).isBefore(cutoff),
        )
        .fold<double>(0, (sum, record) => sum + record.debit - record.credit);
  }

  double get totalDebit =>
      (isStatement ? _statementPeriodRecords : visibleRecords)
          .fold(0, (sum, record) => sum + record.debit);

  double get totalCredit =>
      (isStatement ? _statementPeriodRecords : visibleRecords)
          .fold(0, (sum, record) => sum + record.credit);

  double get totalAmount =>
      visibleRecords.fold(0, (sum, record) => sum + record.amount);

  double get closingBalance => openingBalance + totalDebit - totalCredit;

  void setSearch(String value) => searchText.value = value;

  void selectParty(String? id) => draftPartyId.value = id ?? '';
  void selectBranch(String? id) => draftBranchId.value = id ?? '';
  void selectType(String? value) => draftType.value = value ?? '';
  void selectStatus(String? value) => draftStatus.value = value ?? '';

  void setStartDate(DateTime? value) => draftStartDate.value = value;
  void setEndDate(DateTime? value) => draftEndDate.value = value;

  void setSort(StatementsReportSortField field, {required bool ascending}) {
    sortField.value = field;
    sortAscending.value = ascending;
  }

  void resetSorting() {
    sortField.value = StatementsReportSortField.date;
    sortAscending.value = false;
  }

  void setDateRange(DateTimeRangeValues value) {
    draftStartDate.value = value.start;
    draftEndDate.value = value.end;
    applyFilters();
  }

  bool applyFilters() {
    if (draftStartDate.value != null &&
        draftEndDate.value != null &&
        _day(draftEndDate.value!).isBefore(_day(draftStartDate.value!))) {
      filterErrorMessage.value = 'To Date must be on or after From Date.';
      return false;
    }
    filterErrorMessage.value = '';
    selectedPartyId.value = draftPartyId.value;
    selectedBranchId.value = draftBranchId.value;
    selectedType.value = draftType.value;
    selectedStatus.value = draftStatus.value;
    startDate.value = draftStartDate.value;
    endDate.value = draftEndDate.value;
    return true;
  }

  void clearFilters() {
    draftPartyId.value = '';
    draftBranchId.value = '';
    draftType.value = '';
    draftStatus.value = '';
    draftStartDate.value = null;
    draftEndDate.value = null;
    selectedPartyId.value = '';
    selectedBranchId.value = '';
    selectedType.value = '';
    selectedStatus.value = '';
    startDate.value = null;
    endDate.value = null;
    searchText.value = '';
    searchController.clear();
    filterErrorMessage.value = '';
  }

  void removeFilter(String key) {
    switch (key) {
      case 'party':
        draftPartyId.value = '';
        selectedPartyId.value = '';
        break;
      case 'branch':
        draftBranchId.value = '';
        selectedBranchId.value = '';
        break;
      case 'type':
        draftType.value = '';
        selectedType.value = '';
        break;
      case 'status':
        draftStatus.value = '';
        selectedStatus.value = '';
        break;
      case 'from':
        draftStartDate.value = null;
        startDate.value = null;
        break;
      case 'to':
        draftEndDate.value = null;
        endDate.value = null;
        break;
    }
    filterErrorMessage.value = '';
  }

  int _compareBySelectedSort(
    StatementsReportRecord left,
    StatementsReportRecord right,
  ) {
    final order = switch (sortField.value) {
      StatementsReportSortField.date =>
        (left.date ?? DateTime(1900)).compareTo(right.date ?? DateTime(1900)),
      StatementsReportSortField.reference =>
        left.reference.toLowerCase().compareTo(right.reference.toLowerCase()),
      StatementsReportSortField.partyName =>
        left.partyName.toLowerCase().compareTo(right.partyName.toLowerCase()),
      StatementsReportSortField.transactionType => (isSalesRegister
              ? left.partyType
              : left.transactionType)
          .toLowerCase()
          .compareTo((isSalesRegister ? right.partyType : right.transactionType)
              .toLowerCase()),
      StatementsReportSortField.branch =>
        left.branchName.toLowerCase().compareTo(right.branchName.toLowerCase()),
      StatementsReportSortField.amount => left.amount.compareTo(right.amount),
      StatementsReportSortField.debit => left.debit.compareTo(right.debit),
      StatementsReportSortField.credit => left.credit.compareTo(right.credit),
      StatementsReportSortField.balance =>
        left.balance.compareTo(right.balance),
      StatementsReportSortField.status =>
        left.status.toLowerCase().compareTo(right.status.toLowerCase()),
      StatementsReportSortField.lorryNumber => left.lorryNumber
          .toLowerCase()
          .compareTo(right.lorryNumber.toLowerCase()),
      StatementsReportSortField.driverName =>
        left.driverName.toLowerCase().compareTo(right.driverName.toLowerCase()),
      StatementsReportSortField.quantity =>
        left.totalQuantity.compareTo(right.totalQuantity),
    };
    return sortAscending.value ? order : -order;
  }

  static String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  static int _compareRecords(
    StatementsReportRecord left,
    StatementsReportRecord right,
  ) {
    final dateOrder =
        (left.date ?? DateTime(1900)).compareTo(right.date ?? DateTime(1900));
    return dateOrder != 0
        ? dateOrder
        : left.reference.compareTo(right.reference);
  }

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class DateTimeRangeValues {
  const DateTimeRangeValues({this.start, this.end});

  final DateTime? start;
  final DateTime? end;
}
