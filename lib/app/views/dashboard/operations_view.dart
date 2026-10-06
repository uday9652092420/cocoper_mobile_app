import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/dashboard/dashboard_controller.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF14342B);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);

class OperationsView extends GetView<DashboardController> {
  const OperationsView({super.key});

  static const List<_TransactionModule> _modules = [
    _TransactionModule(
      title: 'Purchase Order',
      subtitle: 'Create and track purchase orders',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF2D8135),
      tint: Color(0xFFE7F3E4),
    ),
    _TransactionModule(
      title: 'Purchase Invoice',
      subtitle: 'Record purchase invoices',
      icon: Icons.description_outlined,
      color: Color(0xFF0C8CE9),
      tint: Color(0xFFE3F1FC),
    ),
    _TransactionModule(
      title: 'Sales Order',
      subtitle: 'Create and dispatch sales orders',
      icon: Icons.local_shipping_outlined,
      color: Color(0xFFE9A23B),
      tint: Color(0xFFFDF2E2),
    ),
    _TransactionModule(
      title: 'Direct Sales',
      subtitle: 'Record direct cash/counter sales',
      icon: Icons.point_of_sale_outlined,
      color: Color(0xFF0E8F86),
      tint: Color(0xFFE2F2F1),
    ),
    _TransactionModule(
      title: 'Loading & Dispatch',
      subtitle: 'Manage loading and dispatches',
      icon: Icons.move_to_inbox_outlined,
      color: Color(0xFF7C5CD6),
      tint: Color(0xFFEDE8FB),
    ),
    _TransactionModule(
      title: 'Customer Receipts',
      subtitle: 'Collect customer payments',
      icon: Icons.payments_outlined,
      color: Color(0xFFB3261E),
      tint: Color(0xFFFBE9E7),
    ),
    _TransactionModule(
      title: 'Supplier Payments',
      subtitle: 'Pay supplier dues',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFF00696D),
      tint: Color(0xFFE0F2F2),
    ),
    _TransactionModule(
      title: 'Labour Attendance',
      subtitle: 'Mark daily labour attendance',
      icon: Icons.badge_outlined,
      color: Color(0xFF9A6B00),
      tint: Color(0xFFFBF3DD),
    ),
    _TransactionModule(
      title: 'Cash & Bank',
      subtitle: 'Record cash/bank expenses',
      icon: Icons.savings_outlined,
      color: Color(0xFFD95C21),
      tint: Color(0xFFFBEBDD),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE9F3E6), Color(0xFFFDFEFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
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
                  'Operations',
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
                  'FAST TRANSACTIONS',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: _kMuted,
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Text(
                      'Transactions',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _modules.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.32,
                  ),
                  itemBuilder: (context, index) => _buildTile(
                    _modules[index],
                  ),
                ),
              ],
            ),
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
      child: const Row(
        children: [
          Icon(Icons.search, size: 19, color: _kMuted),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search work, customer or voucher',
                hintStyle: TextStyle(fontSize: 13.5, color: _kInk),
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Icon(Icons.mic_none_outlined, size: 19, color: _kMuted),
        ],
      ),
    );
  }

  Widget _buildTile(_TransactionModule module) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Get.snackbar(
          module.title,
          'This module is coming soon.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kLine),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: module.tint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(module.icon, size: 19, color: module.color),
            ),
            const Spacer(),
            Text(
              module.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              module.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _kMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionModule {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color tint;

  const _TransactionModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tint,
  });
}
