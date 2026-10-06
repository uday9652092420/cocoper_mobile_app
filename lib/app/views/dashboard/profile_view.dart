import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/dashboard/profile_controller.dart';
import '../../helpers/secure_store.dart';
import '../../helpers/shared_preferences.dart';
import '../../routes/app_routes.dart';

const _kInk = Color(0xFF14342B);
const _kMuted = Color(0xFF14342B);
const _kLine = Color(0xFFE4EBE4);
const _kGreen = Color(0xFF2D8135);
const _kMint = Color(0xFFE7F3E4);

class ProfileView extends GetView<ProfileController> {
  ProfileView({super.key});

  @override
  final ProfileController controller = Get.find();

  String get _displayName {
    if (controller.fullName.value.isNotEmpty) {
      return controller.fullName.value;
    }
    if (controller.username.value.isNotEmpty) {
      return controller.username.value;
    }
    if (controller.email.value.isNotEmpty) {
      return controller.email.value;
    }
    return 'COCOPER User';
  }

  String get _initial {
    final name = _displayName.trim();
    return name.isEmpty ? 'C' : name[0].toUpperCase();
  }

  String _value(String value) => value.isEmpty ? '-' : value;

  Future<void> _logout() async {
    await FlutterSecureStore().deleteAllData();
    await SharedPrefsHelper.clearAll();

    Get.offAllNamed(Routes.loginPage);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
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
                    'Profile',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildDetailsCard(),
                  const SizedBox(height: 16),
                  _buildBranchesCard(),
                  const SizedBox(height: 18),
                  _buildLogoutButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF17402F), Color(0xFF0F2A20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E4C39),
              border: Border.all(color: const Color(0xFF3F7A5E), width: 2),
            ),
            child: Text(
              controller.isLoading.value ? '' : _initial,
              style: const TextStyle(
                color: Color(0xFF8FD3AE),
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.isLoading.value ? 'Loading...' : _displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _value(controller.username.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9FC0AE),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E4C39),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _value(controller.role.value),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8FD3AE),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        children: [
          _detailRow(
            Icons.person_outline,
            'Username',
            _value(controller.username.value),
          ),
          _divider(),
          _detailRow(
            Icons.mail_outline,
            'Email',
            _value(controller.email.value),
          ),
          _divider(),
          _detailRow(
            Icons.badge_outlined,
            'Role',
            _value(controller.role.value),
          ),
          _divider(),
          _detailRow(
            Icons.business_outlined,
            'Organization',
            _value(
              controller.organizationName.value.isNotEmpty
                  ? controller.organizationName.value
                  : controller.organizationId.value,
            ),
          ),
          _divider(),
          _detailRow(
            Icons.fingerprint,
            'User ID',
            _value(controller.userId.value),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchesCard() {
    final list = controller.branches;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Branches',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No branches assigned',
                style: TextStyle(fontSize: 12, color: _kMuted),
              ),
            )
          else
            for (var i = 0; i < list.length; i++) ...[
              if (i != 0) _divider(),
              _branchRow(list[i]),
            ],
        ],
      ),
    );
  }

  Widget _branchRow(Map<String, dynamic> branch) {
    final id = branch['id']?.toString() ?? '';
    final code = branch['branch_code']?.toString() ?? '';
    final name = branch['branch_name']?.toString() ?? '';
    final isDefault = (branch['is_default'] == true) ||
        (controller.defaultBranchId.value.isNotEmpty &&
            controller.defaultBranchId.value == id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kMint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              size: 17,
              color: _kGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? '-' : name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  ),
                ),
                if (code.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    code,
                    style: const TextStyle(fontSize: 12, color: _kMuted),
                  ),
                ],
              ],
            ),
          ),
          if (isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kMint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Default',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF0F4F0));
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kMint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: _kGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: _kMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, size: 18),
        label: const Text(
          'Logout',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFFB3261E),
          side: const BorderSide(color: Color(0xFFE6C7C4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
