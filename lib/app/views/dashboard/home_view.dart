import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/dashboard/dashboard_controller.dart';
import '../../controllers/dashboard/profile_controller.dart';
import '../../helpers/secure_store.dart';
import '../../helpers/shared_preferences.dart';
import '../../localization/localization.dart';
import '../../routes/app_routes.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF14342B);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _kMint = Color(0xFFE7F3E4);

class HomeView extends GetView<DashboardController> {
  const HomeView({super.key});

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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildScopeRow(),
                const SizedBox(height: 16),
                _buildBanner(),
                const SizedBox(height: 20),
                _buildRoleSection(),
                const SizedBox(height: 18),
                _buildSearchBar(),
                const SizedBox(height: 18),
                _buildStats(),
                const SizedBox(height: 22),
                _buildFastTransactions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 54,
            height: 54,
            child: Image.asset(
              'assets/cocoper-icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF2E9E62), Color(0xFF14532D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Text(
                  'C',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COCOPER',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: _kInk,
                ),
              ),
              Text(
                'All coconut operations',
                style: TextStyle(fontSize: 13, color: _kMuted),
              ),
            ],
          ),
        ),
        _buildLanguageButton(),
        const SizedBox(width: 8),
        _buildLogoutButton(),
      ],
    );
  }

  Widget _buildLanguageButton() {
    return PopupMenuButton<Map<String, String>>(
      tooltip: 'language'.tr,
      onSelected: (option) => _changeLanguage(
        option['code'] ?? 'en',
        option['country'] ?? 'US',
      ),
      itemBuilder: (context) => [
        for (final option in Localization.languageOptions)
          PopupMenuItem<Map<String, String>>(
            value: option,
            child: Row(
              children: [
                Icon(
                  Get.locale?.languageCode == option['code']
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 16,
                  color: Get.locale?.languageCode == option['code']
                      ? _kGreen
                      : _kMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  option['name'] ?? '',
                  style: const TextStyle(fontSize: 15, color: _kInk),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kLine),
        ),
        child: const Icon(Icons.translate, size: 19, color: _kGreen),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: _logout,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kLine),
        ),
        child: const Icon(
          Icons.logout,
          size: 19,
          color: Color(0xFFB3261E),
        ),
      ),
    );
  }

  Future<void> _changeLanguage(String code, String country) async {
    await SharedPrefsHelper.setString(SharedPrefsHelper.languageCode, code);
    await SharedPrefsHelper.setString(SharedPrefsHelper.countryCode, country);

    Get.updateLocale(Locale(code, country));
  }

  Future<void> _logout() async {
    final languageCode = await SharedPrefsHelper.getString(
      SharedPrefsHelper.languageCode,
      defaultValue: 'en',
    );
    final countryCode = await SharedPrefsHelper.getString(
      SharedPrefsHelper.countryCode,
      defaultValue: 'US',
    );

    await FlutterSecureStore().deleteAllData();
    await SharedPrefsHelper.clearAll();

    await SharedPrefsHelper.setString(
      SharedPrefsHelper.languageCode,
      languageCode,
    );
    await SharedPrefsHelper.setString(
      SharedPrefsHelper.countryCode,
      countryCode,
    );

    Get.offAllNamed(Routes.loginPage);
  }

  Widget _buildScopeRow() {
    final profile = Get.find<ProfileController>();

    return Obx(() {
      final branches = profile.branches;
      final selectedId = profile.selectedBranchId.value;

      String branchName = 'select_branch'.tr;
      for (final b in branches) {
        final id = b['id']?.toString() ?? '';
        if (id.isNotEmpty && id == selectedId) {
          branchName = b['branch_name']?.toString() ?? branchName;
        }
      }

      return Row(
        children: [
          Expanded(
            child: _branchScopeCard(
              branches: branches,
              selectedId: selectedId,
              selectedName: branchName,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _scopeCard(
              icon: Icons.workspace_premium_outlined,
              iconColor: const Color(0xFFE9A23B),
              label: 'role_workspace'.tr,
              value: profile.role.value.isEmpty ? '-' : profile.role.value,
              showCaret: false,
            ),
          ),
        ],
      );
    });
  }

  Widget _branchScopeCard({
    required List<Map<String, dynamic>> branches,
    required String selectedId,
    required String selectedName,
  }) {
    final profile = Get.find<ProfileController>();

    return PopupMenuButton<String>(
      tooltip: 'active_branch'.tr,
      onSelected: profile.selectBranch,
      itemBuilder: (context) {
        if (branches.isEmpty) {
          return [
            PopupMenuItem<String>(
              value: '',
              enabled: false,
              child: Text(
                'no_branches'.tr,
                style: const TextStyle(fontSize: 13, color: _kMuted),
              ),
            ),
          ];
        }

        return [
          for (final b in branches)
            PopupMenuItem<String>(
              value: b['id']?.toString() ?? '',
              child: Row(
                children: [
                  Icon(
                    (b['id']?.toString() ?? '') == selectedId
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 16,
                    color: (b['id']?.toString() ?? '') == selectedId
                        ? _kGreen
                        : _kMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b['branch_name']?.toString() ?? '-',
                      style: const TextStyle(fontSize: 13, color: _kInk),
                    ),
                  ),
                  if (b['branch_code']?.toString().isNotEmpty ?? false)
                    Text(
                      b['branch_code'].toString(),
                      style: const TextStyle(fontSize: 11, color: _kMuted),
                    ),
                ],
              ),
            ),
        ];
      },
      child: _scopeCard(
        icon: Icons.storefront_outlined,
        iconColor: _kInk,
        label: 'active_branch'.tr,
        value: selectedName,
        showCaret: true,
      ),
    );
  }

  Widget _scopeCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool showCaret,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, color: _kMuted),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ],
            ),
          ),
          if (showCaret)
            const Icon(Icons.keyboard_arrow_down, size: 18, color: _kMuted),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF17402F), Color(0xFF0F2A20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3314342B),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COCOPER INDIA PVT. LTD.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Color(0xFF9FC0AE),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Every coconut operation.\nOne simple app.',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Buy, sell, dispatch, collect and track - all with clear '
                  'guided steps.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Color(0xFFB8D2C4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ClipOval(
            child: SizedBox(
              width: 66,
              height: 66,
              child: Image.asset(
                'assets/cocoper-icon.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  alignment: Alignment.center,
                  color: const Color(0xFF1E4C39),
                  child: const Text(
                    'C',
                    style: TextStyle(
                      color: Color(0xFF8FD3AE),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSection() {
    final roles = <(String, IconData, bool)>[
      ('Finance Manager', Icons.eco_outlined, true),
      ('Warehouse Manager', Icons.grid_view, false),
      ('Procurement Manager', Icons.arrow_downward, false),
      ('Sales Manager', Icons.arrow_upward, false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose login role',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _kInk,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < roles.length; i++) ...[
              if (i != 0) const SizedBox(width: 8),
              Expanded(
                child: _roleChip(roles[i].$1, roles[i].$2, roles[i].$3),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Owns vouchers, payments, ledgers and the month-end close.',
          style: TextStyle(fontSize: 12, color: _kMuted),
        ),
      ],
    );
  }

  Widget _roleChip(String label, IconData icon, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: selected ? _kMint : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF9ED0A0) : _kLine,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: selected ? _kGreen : _kMuted),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: selected ? _kGreen : const Color(0xFF5A6A5F),
            ),
          ),
        ],
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

  Widget _buildStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Purchased',
                '2.5 t',
                Icons.trending_up,
                _kGreen,
                _kMint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Sold',
                '\u20B981K',
                Icons.trending_up,
                const Color(0xFFE9A23B),
                const Color(0xFFFDF2E2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Received',
                '\u20B952K',
                Icons.currency_rupee,
                const Color(0xFF0E8F86),
                const Color(0xFFE2F2F1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Workers',
                '18',
                Icons.people_alt_outlined,
                const Color(0xFF7C5CD6),
                const Color(0xFFEDE8FB),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color tint,
  ) {
    return Container(
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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 12, color: _kMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastTransactions() {
    final items = <(String, String, IconData)>[
      (
        'Purchase entry',
        'Record coconut purchases from farmers',
        Icons.shopping_cart_outlined
      ),
      (
        'Sales order',
        'Create and dispatch customer orders',
        Icons.local_shipping_outlined
      ),
      (
        'Payment receipt',
        'Collect and post customer payments',
        Icons.receipt_long_outlined
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'THE MOST-USED WORK, SIMPLIFIED INTO SHORT STEPS.',
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
              'Fast transactions',
              style: TextStyle(
                fontSize: 16,
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
        const SizedBox(height: 10),
        for (final item in items) ...[
          _transactionTile(item.$1, item.$2, item.$3),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _transactionTile(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _kMint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _kGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: _kMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: _kInk),
        ],
      ),
    );
  }
}
