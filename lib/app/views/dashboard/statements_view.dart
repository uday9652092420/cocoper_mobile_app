import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

const _kInk = AppColors.textDefaultLight;
const _kMuted = AppColors.textLightGrayLight;
const _kLine = AppColors.borderLightGrayLight;

class StatementsView extends StatefulWidget {
  const StatementsView({super.key});

  @override
  State<StatementsView> createState() => _StatementsViewState();
}

class _StatementsViewState extends State<StatementsView> {
  final _searchController = TextEditingController();
  String _query = '';

  static const List<_Statement> _statements = [
    _Statement(
      title: 'Purchase Register',
      description: 'Review purchase invoices by date and branch',
      icon: Icons.south_rounded,
      tint: Color(0xFFEAF5D9),
      route: Routes.purchaseRegisterReport,
    ),
    _Statement(
      title: 'Sales Register',
      description: 'Review sales invoices by date and branch',
      icon: Icons.north_rounded,
      tint: Color(0xFFE0F2E9),
      route: Routes.salesRegisterReport,
    ),
    _Statement(
      title: 'Supplier Statement',
      description: 'Supplier invoices, payments and balances',
      icon: Icons.storefront_outlined,
      tint: Color(0xFFF8E9BC),
      route: Routes.supplierStatementReport,
    ),
    _Statement(
      title: 'Customer Statement',
      description: 'Customer sales, receipts and balances',
      icon: Icons.people_outline_rounded,
      tint: Color(0xFFDDF1EE),
      route: Routes.customerStatementReport,
    ),
    _Statement(
      title: 'Pending & Dispatch',
      description: 'Loading, pending quantities and dispatch status',
      icon: Icons.local_shipping_outlined,
      tint: Color(0xFFF5E3E7),
      route: Routes.pendingDispatchReport,
    ),
    _Statement(
      title: 'Profit & Loss Statement',
      description: 'Review income, expenses and net profit',
      icon: Icons.account_balance_wallet_outlined,
      tint: Color(0xFFEAE4F5),
      route: Routes.profitLossStatementReport,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final statements = _statements
        .where(
          (statement) =>
              statement.title.toLowerCase().contains(query) ||
              statement.description.toLowerCase().contains(query),
        )
        .toList();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.pageBackground,
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Statements',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              const SizedBox(height: 14),
              _buildSearchBar(),
              const SizedBox(height: 22),
              const Text(
                'REPORTS',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: _kMuted,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Registers & statements',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              const SizedBox(height: 12),
              if (statements.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No reports match your search.',
                      style: TextStyle(color: _kMuted),
                    ),
                  ),
                )
              else
                for (int i = 0; i < statements.length; i++) ...[
                  _buildStatementTile(statements[i]),
                  if (i != statements.length - 1) const SizedBox(height: 9),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 19, color: _kMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search reports',
                hintStyle: TextStyle(fontSize: 13.5, color: _kMuted),
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              icon: const Icon(Icons.close, size: 18, color: _kMuted),
            ),
        ],
      ),
    );
  }

  Widget _buildStatementTile(_Statement statement) {
    return Material(
      color: statement.tint,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => Get.toNamed<void>(statement.route),
        child: Container(
          constraints: const BoxConstraints(minHeight: 94),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _kInk.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF06473E),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(statement.icon, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statement.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      statement.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: _kMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.north_east_rounded, size: 19, color: _kInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _Statement {
  final String title;
  final String description;
  final IconData icon;
  final Color tint;
  final String route;

  const _Statement({
    required this.title,
    required this.description,
    required this.icon,
    required this.tint,
    required this.route,
  });
}
