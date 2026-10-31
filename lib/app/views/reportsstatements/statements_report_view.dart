import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/statements_report_controller.dart';
import '../../models/statements_report.dart';
import '../../repositories/statements_report_repository.dart';
import '../../custome_widgets/app_status_badge.dart';
import '../../custome_widgets/custome_dropdown_form.dart';
import '../../theme/app_theme.dart';

const _ink = AppColors.textDefaultLight;
const _green = AppColors.primaryLight;
const _muted = AppColors.textLightGrayLight;
const _line = AppColors.borderLightGrayLight;

class StatementsReportBinding extends Bindings {
  StatementsReportBinding(this.type);

  final StatementsReportType type;

  @override
  void dependencies() {
    Get.put(
      StatementsReportController(
        type: type,
        repository: StatementsReportRepository(),
      ),
      tag: type.name,
    );
  }
}

class StatementsReportView extends StatelessWidget {
  const StatementsReportView({required this.type, super.key});

  final StatementsReportType type;

  StatementsReportController get _controller =>
      Get.find<StatementsReportController>(tag: type.name);

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title(type), style: const TextStyle(fontSize: 18)),
            Text(
              _subtitle(type),
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _filters(context, controller),
            Obx(
              () => controller.isLoading.value &&
                      controller.sourceRecords.isNotEmpty
                  ? const LinearProgressIndicator(
                      minHeight: 2,
                      color: _green,
                      backgroundColor: Colors.transparent,
                    )
                  : const SizedBox(height: 2),
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value &&
                    controller.sourceRecords.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: _green),
                  );
                }
                if (controller.errorMessage.value.isNotEmpty &&
                    controller.sourceRecords.isEmpty) {
                  return _errorState(controller);
                }
                if (controller.isStatement &&
                    controller.selectedPartyId.value.isEmpty) {
                  return _selectPartyState(type);
                }
                final records = controller.visibleRecords;
                if (type == StatementsReportType.supplierStatement) {
                  return RefreshIndicator(
                    color: _green,
                    onRefresh: controller.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        if (controller.errorMessage.value.isNotEmpty)
                          _inlineError(controller),
                        _supplierStatementSummary(controller),
                        const SizedBox(height: 8),
                        _statementTable(
                          controller,
                          records,
                          debitLabel: 'Purchase',
                          creditLabel: 'Payment',
                          emptyMessage:
                              'No transactions match the selected supplier and dates.',
                        ),
                      ],
                    ),
                  );
                }
                if (type == StatementsReportType.customerStatement) {
                  return RefreshIndicator(
                    color: _green,
                    onRefresh: controller.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        if (controller.errorMessage.value.isNotEmpty)
                          _inlineError(controller),
                        _customerStatementSummary(controller),
                        const SizedBox(height: 8),
                        _statementTable(
                          controller,
                          records,
                          debitLabel: 'Sales',
                          creditLabel: 'Receipt',
                          emptyMessage:
                              'No transactions match the selected customer and dates.',
                        ),
                      ],
                    ),
                  );
                }
                if (records.isEmpty) {
                  return _emptyState(
                    controller,
                    controller.errorMessage.value.isNotEmpty,
                  );
                }
                return RefreshIndicator(
                  color: _green,
                  onRefresh: controller.load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      if (controller.errorMessage.value.isNotEmpty)
                        _inlineError(controller),
                      if (controller.isStatement) _statementSummary(controller),
                      if (!controller.isStatement && !controller.isDispatch)
                        _registerSummary(controller),
                      const SizedBox(height: 8),
                      for (final record in records)
                        _recordCard(controller, record),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters(
    BuildContext context,
    StatementsReportController controller,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.searchController,
                  onChanged: controller.setSearch,
                  decoration: InputDecoration(
                    hintText: _searchHint(type),
                    prefixIcon: const Icon(Icons.search, color: _muted),
                    filled: true,
                    fillColor: const Color(0xFFF5F8F4),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Obx(
                () => IconButton(
                  tooltip: 'Filter reports',
                  onPressed: () => _showFilterSheet(context, controller),
                  icon: Badge(
                    isLabelVisible: controller.activeFilterCount > 0,
                    label: Text('${controller.activeFilterCount}'),
                    child: const Icon(Icons.tune_rounded, color: _green),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sort reports',
                onPressed: () => _showSortSheet(context, controller),
                icon: const Icon(Icons.sort_rounded, color: _green),
              ),
            ],
          ),
          Obx(() {
            final chips = controller.appliedFilterChips;
            if (chips.isEmpty) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 0,
                children: [
                  for (final chip in chips)
                    InputChip(
                      label: Text(
                        chip.label,
                        style: const TextStyle(fontSize: 11),
                      ),
                      onDeleted: () => controller.removeFilter(chip.key),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            );
          }),
          Obx(
            () => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sort: ${controller.sortSummary}',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context,
    StatementsReportController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Filter reports',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: _filterSheetFields(context, controller),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            controller.clearFilters();
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (controller.applyFilters()) {
                              Navigator.pop(sheetContext);
                            }
                          },
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterSheetFields(
    BuildContext context,
    StatementsReportController controller,
  ) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.supportsPartyFilter) ...[
            _fieldLabel(_partyFilterLabel(type)),
            _selectFilter(
              hint: _partyFilterLabel(type),
              value: controller.draftPartyId.value,
              options: [
                ('', _partyAllLabel(type)),
                ...controller.parties.map((option) => (option.id, option.name)),
              ],
              onChanged: controller.selectParty,
            ),
            const SizedBox(height: 14),
          ],
          if (controller.isSalesRegister || controller.isStatement) ...[
            _fieldLabel(
              controller.isSalesRegister ? 'Customer Type' : 'Transaction Type',
            ),
            _selectFilter(
              hint: controller.isSalesRegister
                  ? 'Customer Type'
                  : 'Transaction Type',
              value: controller.draftType.value,
              options: [
                ('', 'All Types'),
                ...controller.availableTransactionTypes
                    .map((value) => (value, value)),
              ],
              onChanged: controller.selectType,
            ),
            const SizedBox(height: 14),
          ],
          if (controller.isPurchaseRegister || controller.isSalesRegister) ...[
            _fieldLabel('Branch'),
            _selectFilter(
              hint: 'Branch',
              value: controller.draftBranchId.value,
              options: [
                ('', 'All Branches'),
                ...controller.branches
                    .map((option) => (option.id, option.name)),
              ],
              onChanged: controller.selectBranch,
            ),
            const SizedBox(height: 14),
          ],
          if (controller.isDispatch) ...[
            _fieldLabel('Status'),
            _selectFilter(
              hint: 'Status',
              value: controller.draftStatus.value,
              options: [
                ('', 'All Statuses'),
                ...controller.availableStatuses.map((value) => (value, value)),
              ],
              onChanged: controller.selectStatus,
            ),
            const SizedBox(height: 14),
          ],
          _fieldLabel('Date range'),
          Row(
            children: [
              Expanded(
                child: _dateFilterButton(
                  label: 'From Date',
                  date: controller.draftStartDate.value,
                  onTap: () => _chooseDate(
                    context,
                    controller,
                    isStartDate: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dateFilterButton(
                  label: 'To Date',
                  date: controller.draftEndDate.value,
                  onTap: () => _chooseDate(
                    context,
                    controller,
                    isStartDate: false,
                  ),
                ),
              ),
            ],
          ),
          if (controller.filterErrorMessage.value.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              controller.filterErrorMessage.value,
              style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: _ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Future<void> _showSortSheet(
    BuildContext context,
    StatementsReportController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sort records',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.resetSorting,
                      child: const Text('Reset Sorting'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Ascending'),
                      icon: Icon(Icons.arrow_upward),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Descending'),
                      icon: Icon(Icons.arrow_downward),
                    ),
                  ],
                  selected: {controller.sortAscending.value},
                  onSelectionChanged: (values) => controller.setSort(
                    controller.sortField.value,
                    ascending: values.first,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      RadioGroup<StatementsReportSortField>(
                        groupValue: controller.sortField.value,
                        onChanged: (field) {
                          if (field != null) {
                            controller.setSort(
                              field,
                              ascending: controller.sortAscending.value,
                            );
                          }
                        },
                        child: Column(
                          children: [
                            for (final option in controller.sortOptions)
                              Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(option.label),
                                  leading: Radio<StatementsReportSortField>(
                                    value: option.field,
                                  ),
                                  onTap: () => controller.setSort(
                                    option.field,
                                    ascending: controller.sortAscending.value,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectFilter({
    required String hint,
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String?> onChanged,
  }) {
    return CustomeDropdownForm(
      label: '',
      hintText: hint,
      items: options.map((option) => {option.$1: option.$2}).toList(),
      selectedKey: value,
      onChanged: onChanged,
    );
  }

  Widget _dateFilterButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        side: const BorderSide(color: _line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.calendar_today_outlined, size: 16, color: _green),
      label: Text(
        date == null ? label : DateFormat('dd/MM/yyyy').format(date),
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Future<void> _chooseDate(
      BuildContext context, StatementsReportController controller,
      {required bool isStartDate}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      initialDate: (isStartDate
              ? controller.draftStartDate.value
              : controller.draftEndDate.value) ??
          (isStartDate ? controller.draftEndDate.value : null) ??
          now,
    );
    if (selected == null) return;
    if (isStartDate) {
      controller.setStartDate(selected);
    } else {
      controller.setEndDate(selected);
    }
  }

  static String _partyFilterLabel(StatementsReportType type) => switch (type) {
        StatementsReportType.purchaseRegister ||
        StatementsReportType.supplierStatement =>
          'Supplier',
        _ => 'Customer',
      };

  static String _partyAllLabel(StatementsReportType type) => switch (type) {
        StatementsReportType.purchaseRegister => 'All Suppliers',
        StatementsReportType.salesRegister ||
        StatementsReportType.pendingDispatch =>
          'All Customers',
        StatementsReportType.supplierStatement => 'Select supplier',
        StatementsReportType.customerStatement => 'Select customer',
      };

  Widget _statementSummary(StatementsReportController controller) {
    return Obx(
      () => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3E9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Column(
          children: [
            _summaryLine('Opening balance', controller.openingBalance),
            const Divider(height: 16),
            _summaryLine('Debit', controller.totalDebit),
            const SizedBox(height: 6),
            _summaryLine('Credit', controller.totalCredit),
            const Divider(height: 16),
            _summaryLine('Closing balance', controller.closingBalance,
                bold: true),
          ],
        ),
      ),
    );
  }

  Widget _supplierStatementSummary(
    StatementsReportController controller,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statementMetric(
                  'Opening Balance',
                  controller.openingBalance,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _statementMetric(
                  'Total Purchase',
                  controller.totalDebit,
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: _statementMetric(
                  'Total Payment',
                  controller.totalCredit,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _statementMetric(
                  'Closing Balance',
                  controller.closingBalance,
                  bold: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statementMetric(String label, double amount, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: _muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _currency.format(amount),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _statementTable(
    StatementsReportController controller,
    List<StatementsReportRecord> records, {
    required String debitLabel,
    required String creditLabel,
    required String emptyMessage,
  }) {
    const columnWidths = <int, TableColumnWidth>{
      0: FixedColumnWidth(105),
      1: FixedColumnWidth(90),
      2: FixedColumnWidth(135),
      3: FixedColumnWidth(135),
      4: FixedColumnWidth(165),
    };
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 630,
          child: Table(
            columnWidths: columnWidths,
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: const TableBorder(
              horizontalInside: BorderSide(color: _line, width: 0.7),
              bottom: BorderSide(color: _line, width: 0.7),
            ),
            children: [
              _statementTableRow(
                ['Date', 'Voucher', debitLabel, creditLabel, 'Running Balance'],
                header: true,
              ),
              if (records.isEmpty)
                _statementTableRow([
                  '',
                  emptyMessage,
                  '',
                  '',
                  '',
                ])
              else
                for (final record in records)
                  _statementTableRow([
                    record.date == null
                        ? '—'
                        : DateFormat('dd MMM yyyy').format(record.date!),
                    record.reference,
                    record.debit == 0 ? '—' : _currency.format(record.debit),
                    record.credit == 0 ? '—' : _currency.format(record.credit),
                    _currency.format(record.balance),
                  ]),
              _statementTableRow(
                [
                  '',
                  'TOTAL',
                  _currency.format(controller.totalDebit),
                  _currency.format(controller.totalCredit),
                  _currency.format(controller.closingBalance),
                ],
                total: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _statementTableRow(
    List<String> values, {
    bool header = false,
    bool total = false,
  }) =>
      TableRow(
        decoration: BoxDecoration(
          color: header
              ? const Color(0xFFF2F6F2)
              : total
                  ? const Color(0xFFEAF3E9)
                  : Colors.white,
        ),
        children: [
          for (var index = 0; index < values.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Text(
                values[index],
                textAlign: index >= 2 ? TextAlign.right : TextAlign.left,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: header ? 11 : 11.5,
                  fontWeight:
                      header || total ? FontWeight.w800 : FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),
        ],
      );

  Widget _customerStatementSummary(StatementsReportController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statementMetric(
                  'Opening Balance',
                  controller.openingBalance,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _statementMetric(
                  'Total Sales',
                  controller.totalDebit,
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: _statementMetric(
                  'Total Receipts',
                  controller.totalCredit,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _statementMetric(
                  'Closing Balance',
                  controller.closingBalance,
                  bold: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, double amount, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: _ink,
            ),
          ),
        ),
        Text(
          _currency.format(amount),
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _registerSummary(StatementsReportController controller) {
    return Obx(
      () => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3E9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Total for filtered records',
                style: TextStyle(fontSize: 12, color: _ink),
              ),
            ),
            Text(
              _currency.format(controller.totalAmount),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordCard(
    StatementsReportController controller,
    StatementsReportRecord record,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: _line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    record.reference.isEmpty ? 'Transaction' : record.reference,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (record.status.isNotEmpty) _statusBadge(record.status),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 12,
              runSpacing: 5,
              children: [
                _metadata(
                  Icons.calendar_today_outlined,
                  record.date == null
                      ? 'Date unavailable'
                      : DateFormat('dd MMM yyyy').format(record.date!),
                ),
                if (record.partyName.isNotEmpty)
                  _metadata(Icons.person_outline, record.partyName),
                if (record.branchName.isNotEmpty)
                  _metadata(Icons.store_outlined, record.branchName),
                if (controller.isDispatch && record.lorryNumber.isNotEmpty)
                  _metadata(
                    Icons.local_shipping_outlined,
                    record.lorryNumber,
                  ),
                if (controller.isDispatch && record.driverName.isNotEmpty)
                  _metadata(Icons.person_outline, record.driverName),
                if (controller.isDispatch && record.driverMobile.isNotEmpty)
                  _metadata(Icons.phone_outlined, record.driverMobile),
              ],
            ),
            if (record.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                record.description,
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: _line),
            const SizedBox(height: 8),
            if (controller.isStatement)
              _statementRecordAmounts(record)
            else if (!controller.isDispatch)
              _amountLine('Amount', record.amount)
            else
              Row(
                children: [
                  Expanded(
                    child: _amountLine(
                      'Quantity',
                      record.totalQuantity,
                      suffix: ' units',
                    ),
                  ),
                  Expanded(
                    child: _amountLine(
                      'Loaded',
                      record.loadedQuantity,
                      suffix: ' units',
                    ),
                  ),
                  Expanded(
                    child: _amountLine(
                      'Pending',
                      record.pendingQuantity,
                      suffix: ' units',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _statementRecordAmounts(
    StatementsReportRecord record,
  ) {
    return Row(
      children: [
        Expanded(child: _amountLine('Debit', record.debit)),
        Expanded(child: _amountLine('Credit', record.credit)),
        Expanded(child: _amountLine('Balance', record.balance)),
      ],
    );
  }

  Widget _amountLine(
    String title,
    double amount, {
    String suffix = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: _muted)),
        const SizedBox(height: 3),
        Text(
          suffix.isEmpty
              ? _currency.format(amount)
              : '${_quantity.format(amount)}$suffix',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _inlineError(StatementsReportController controller) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3D8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 18, color: _muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                controller.errorMessage.value,
                style: const TextStyle(fontSize: 12, color: _ink),
              ),
            ),
            TextButton(
              onPressed: controller.load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );

  Widget _metadata(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _muted),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, color: _muted)),
        ],
      );

  Widget _statusBadge(String status) {
    return AppStatusBadge(status: status);
  }

  Widget _errorState(StatementsReportController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: _muted),
            const SizedBox(height: 10),
            Text(
              controller.errorMessage.value,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: controller.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(StatementsReportController controller, bool hasError) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError
                  ? Icons.warning_amber_rounded
                  : Icons.receipt_long_outlined,
              size: 44,
              color: _muted,
            ),
            const SizedBox(height: 10),
            Text(
              hasError
                  ? controller.errorMessage.value
                  : 'No records match the selected filters.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
            if (hasError) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: controller.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _selectPartyState(StatementsReportType reportType) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_search_outlined, size: 42, color: _muted),
              const SizedBox(height: 10),
              Text(
                reportType == StatementsReportType.supplierStatement
                    ? 'Select a supplier to view its statement.'
                    : 'Select a customer to view its statement.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
        ),
      );

  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final _quantity = NumberFormat('#,##0.##', 'en_IN');

  static String _title(StatementsReportType type) => switch (type) {
        StatementsReportType.purchaseRegister => 'Purchase Register',
        StatementsReportType.salesRegister => 'Sales Register',
        StatementsReportType.supplierStatement => 'Supplier Statement',
        StatementsReportType.customerStatement => 'Customer Statement',
        StatementsReportType.pendingDispatch => 'Pending & Dispatch',
      };

  static String _subtitle(StatementsReportType type) => switch (type) {
        StatementsReportType.purchaseRegister =>
          'Purchase invoices by date and branch',
        StatementsReportType.salesRegister =>
          'Sales invoices by date and branch',
        StatementsReportType.supplierStatement =>
          'Supplier invoices, payments and balance',
        StatementsReportType.customerStatement =>
          'Customer sales, receipts and balance',
        StatementsReportType.pendingDispatch =>
          'Loading and dispatch transactions',
      };

  static String _searchHint(StatementsReportType type) => switch (type) {
        StatementsReportType.purchaseRegister => 'Search invoice or supplier',
        StatementsReportType.salesRegister => 'Search invoice or customer',
        StatementsReportType.supplierStatement =>
          'Search voucher or description',
        StatementsReportType.customerStatement =>
          'Search voucher or description',
        StatementsReportType.pendingDispatch =>
          'Search dispatch, customer or lorry',
      };
}
