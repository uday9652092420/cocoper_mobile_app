import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/dashboard/dashboard_controller.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF718078);
const _kLine = Color(0xFFDCE7DB);

class StatementsView extends GetView<DashboardController> {
  const StatementsView({super.key});

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
                  'STATEMENT OVERVIEW',
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
                      'Balances',
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
                        color: Color(0xFF2D8135),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < _statements.length; i++) ...[
                  _buildStatementTile(_statements[i]),
                  if (i != _statements.length - 1) const SizedBox(height: 9),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<_Statement> _statements = [
    _Statement(
      title: 'Purchase Register',
      balance: '\u20B97.45L',
      icon: Icons.south_rounded,
      tint: Color(0xFFEAF5D9),
    ),
    _Statement(
      title: 'Sales Register',
      balance: '\u20B98.92L',
      icon: Icons.north_rounded,
      tint: Color(0xFFE0F2E9),
    ),
    _Statement(
      title: 'Supplier Statement',
      balance: '\u20B96.68L',
      icon: Icons.pie_chart_rounded,
      tint: Color(0xFFF8E9BC),
    ),
    _Statement(
      title: 'Customer Statement',
      balance: '\u20B92.84L',
      icon: Icons.pie_chart_outline_rounded,
      tint: Color(0xFFDDF1EE),
    ),
    _Statement(
      title: 'Labour Attendance',
      balance: '25',
      icon: Icons.badge_rounded,
      tint: Color(0xFFF5E3E7),
    ),
  ];

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
                hintText: 'Search register, supplier or customer',
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

  Widget _buildStatementTile(_Statement statement) {
    return Material(
      color: statement.tint,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => Get.snackbar(
          statement.title,
          'This statement will be available soon.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        ),
        child: Container(
          height: 106,
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    const Text(
                      'Current balance',
                      style: TextStyle(fontSize: 8, color: _kMuted),
                    ),
                    const SizedBox(height: 4),
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
                    const SizedBox(height: 4),
                    Text(
                      statement.balance,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xCCFFFFFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.north_east_rounded,
                  size: 17,
                  color: _kInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Statement {
  final String title;
  final String balance;
  final IconData icon;
  final Color tint;

  const _Statement({
    required this.title,
    required this.balance,
    required this.icon,
    required this.tint,
  });
}
