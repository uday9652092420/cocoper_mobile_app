import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/profit_loss_controller.dart';
import '../../models/profit_loss_statement.dart';
import '../../theme/app_theme.dart';

const _ink = AppColors.textDefaultLight;
const _muted = AppColors.textLightGrayLight;
const _line = AppColors.borderLightGrayLight;
const _green = AppColors.primaryLight;
const _expense = Color(0xFFB42335);
const _income = Color(0xFF16804A);

class ProfitLossStatementView extends StatelessWidget {
  const ProfitLossStatementView({this.controller, super.key});

  final ProfitLossController? controller;

  ProfitLossController get _reportController =>
      controller ?? Get.find<ProfitLossController>();

  @override
  Widget build(BuildContext context) {
    final reportController = _reportController;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profit & Loss Statement',
              style: TextStyle(fontSize: 18),
            ),
            Obx(
              () => Text(
                reportController.scopeLabel,
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ),
          ],
        ),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Refresh',
              onPressed: reportController.isLoading.value
                  ? null
                  : reportController.load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Obx(() => _dateFilters(context, reportController)),
            Obx(
              () => reportController.isLoading.value
                  ? const LinearProgressIndicator(
                      minHeight: 2,
                      color: _green,
                      backgroundColor: Colors.transparent,
                    )
                  : const SizedBox(height: 2),
            ),
            Expanded(
              child: Obx(
                () => _reportBody(reportController),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateFilters(
    BuildContext context,
    ProfitLossController reportController,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _dateButton(
                  context: context,
                  label: 'From Date',
                  date: reportController.fromDate.value,
                  onSelected: reportController.setFromDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateButton(
                  context: context,
                  label: 'To Date',
                  date: reportController.toDate.value,
                  onSelected: reportController.setToDate,
                ),
              ),
            ],
          ),
          Obx(
            () => reportController.filterErrorMessage.value.isEmpty
                ? const SizedBox(height: 10)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      reportController.filterErrorMessage.value,
                      style: const TextStyle(
                        color: _expense,
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
          SizedBox(
            height: 42,
            child: FilledButton.icon(
              onPressed: reportController.isLoading.value
                  ? null
                  : reportController.applyDateRange,
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Apply / Refresh'),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reporting period: ${reportController.reportingPeriod}',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _dateButton({
    required BuildContext context,
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onSelected,
  }) {
    return OutlinedButton(
      onPressed: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (selected != null) onSelected(selected);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        foregroundColor: _ink,
        side: const BorderSide(color: _line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormatters.shortDate(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.calendar_month_outlined, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportBody(ProfitLossController reportController) {
    final statement = reportController.statement.value;
    if (reportController.isLoading.value && statement == null) {
      return const Center(
        child: CircularProgressIndicator(color: _green),
      );
    }
    if (reportController.errorMessage.value.isNotEmpty) {
      return _messageState(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load statement',
        message: reportController.errorMessage.value,
        action: FilledButton.icon(
          onPressed: reportController.isLoading.value
              ? null
              : reportController.load,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
        ),
      );
    }
    if (statement == null) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (!statement.hasData) {
      return _messageState(
        icon: Icons.receipt_long_outlined,
        title: 'No financial records',
        message:
            'No financial records are available for the selected period.',
        action: OutlinedButton.icon(
          onPressed: reportController.load,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
      );
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: reportController.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _sectionTitle('Stock & Movement'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 360 ? 1 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: columns == 1
                    ? 2.2
                    : constraints.maxWidth < 420
                        ? 1
                        : 1.45,
                children: [
                  _stockCard(
                    title: 'Opening Stock',
                    quantity: statement.openingUnits,
                    rate: statement.openingRate,
                    amount: statement.openingAmount,
                  ),
                  _valueCard(
                    title: 'Purchases (In Range)',
                    amount: statement.purchaseAmount,
                    tint: const Color(0xFFF2F6EA),
                    accent: _green,
                  ),
                  _valueCard(
                    title: 'Sales (In Range)',
                    amount: statement.salesAmount,
                    tint: const Color(0xFFEEF7F3),
                    accent: _income,
                  ),
                  _stockCard(
                    title: 'Closing Stock',
                    quantity: statement.closingUnits,
                    rate: statement.closingRate,
                    amount: statement.closingAmount,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _sectionTitle('Expenses & Other Income'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _valueCard(
                  title: 'Total Expenses (In Range)',
                  amount: statement.expenses,
                  tint: const Color(0xFFFFF0F1),
                  accent: _expense,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _valueCard(
                  title: 'Total Other Income (In Range)',
                  amount: statement.otherIncome,
                  tint: const Color(0xFFECF8F0),
                  accent: _income,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('Profit & Loss Calculation'),
          const SizedBox(height: 10),
          _statementCard(statement),
          const SizedBox(height: 12),
          const Text(
            'Calculated to match COPPER Web from sales invoices, purchase '
            'invoices, approved cash/bank entries, and the stock snapshot. '
            'The current report API includes all branches.',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          color: _ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      );

  Widget _stockCard({
    required String title,
    required double quantity,
    required double rate,
    required double amount,
  }) {
    return _card(
      title: title,
      tint: const Color(0xFFF5F7F3),
      accent: _green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatProfitLossQuantity(quantity)} units',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 3),
          Text(
            'Rate: ${formatProfitLossCurrency(rate)}',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 3),
          Text(
            'Amount: ${formatProfitLossCurrency(amount)}',
            style: const TextStyle(
              fontSize: 14,
              color: _ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueCard({
    required String title,
    required double amount,
    required Color tint,
    required Color accent,
  }) {
    return _card(
      title: title,
      tint: tint,
      accent: accent,
      child: Text(
        formatProfitLossCurrency(amount),
        style: const TextStyle(
          fontSize: 15,
          color: _ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required Color tint,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: _muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }

  Widget _statementCard(ProfitLossStatement statement) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          for (final line in statement.lines)
            _statementLine(line),
        ],
      ),
    );
  }

  Widget _statementLine(ProfitLossStatementLine line) {
    final negative = line.amount < 0;
    final color = negative
        ? _expense
        : line.emphasized
            ? _income
            : _ink;
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F1F2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight:
                    line.emphasized ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatProfitLossStatementAmount(line.amount),
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: line.emphasized ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String message,
    required Widget action,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: _green),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 18),
            action,
          ],
        ),
      ),
    );
  }
}
