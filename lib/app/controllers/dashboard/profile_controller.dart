import 'package:get/get.dart';

import '../../helpers/console_print.dart';
import '../../helpers/flutter_toast.dart';
import '../../helpers/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/endpoints.dart';

/// Loads and exposes the logged-in user's profile using the existing
/// GET /mobile/bootstrap endpoint (user + organization + branches).
class ProfileController extends GetxController {
  // ============================================================
  // STATE
  // ============================================================

  final isLoading = true.obs;
  final hasError = false.obs;

  // User
  final userId = ''.obs;
  final username = ''.obs;
  final fullName = ''.obs;
  final email = ''.obs;
  final role = ''.obs;

  // Organization
  final organizationId = ''.obs;
  final organizationName = ''.obs;

  // Branches
  final branches = <Map<String, dynamic>>[].obs;
  final defaultBranchId = ''.obs;
  final selectedBranchId = ''.obs;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void onInit() {
    super.onInit();
    loadBootstrap();
  }

  // ============================================================
  // LOAD BOOTSTRAP
  // ============================================================

  Future<void> loadBootstrap() async {
    isLoading.value = true;
    hasError.value = false;

    // Seed the UI with what the login flow already stored, so the screen is
    // never blank while the network call is in flight (and on failure).
    await _seedFromPreferences();

    consolePrint('PROFILE BOOTSTRAP REQUEST');

    final response = await ApiService.get(EndPoints.mobileBootstrap);

    if (response == null) {
      // ApiService already showed the no-internet dialog; just mark the error
      // state so the UI falls back to the stored login data.
      consolePrint('PROFILE BOOTSTRAP FAILED (no response)');
      isLoading.value = false;
      hasError.value = true;
      return;
    }

    consolePrint('PROFILE BOOTSTRAP STATUS: ${response.statusCode}');

    final data = response.data;

    if (response.statusCode == 200 && data is Map && data['success'] == true) {
      await _parseBootstrap(Map<String, dynamic>.from(data));
      return;
    }

    _onError();
  }

  // ============================================================
  // PARSING
  // ============================================================

  Future<void> _parseBootstrap(Map<String, dynamic> data) async {
    final user = data['user'];
    if (user is Map) {
      final u = Map<String, dynamic>.from(user);
      userId.value = _string(u['id']);
      username.value = _string(u['username']);
      fullName.value = _string(u['full_name']);
      email.value = _string(u['email']);
      role.value = _string(u['role']);
    }

    final organization = data['organization'];
    if (organization is Map) {
      final o = Map<String, dynamic>.from(organization);
      organizationId.value = _string(o['id']);
      organizationName.value = _string(o['organization_name']);
    }

    final rawBranches = data['branches'];
    if (rawBranches is List) {
      branches.value = rawBranches
          .whereType<Map>()
          .map((b) => Map<String, dynamic>.from(b))
          .toList();
    } else {
      branches.value = [];
    }

    defaultBranchId.value = _string(data['default_branch_id']);

    // Restore the user's active branch (persisted selection if still assigned,
    // otherwise the API's default branch).
    await _restoreBranchSelection();

    isLoading.value = false;
    hasError.value = false;

    consolePrint('PROFILE BOOTSTRAP SUCCESS');
    consolePrint('PROFILE USER: ${username.value}');
    consolePrint('PROFILE ORGANIZATION: ${organizationName.value}');
    consolePrint('PROFILE BRANCH COUNT: ${branches.length}');

    await _persistToPreferences();
  }

  // ============================================================
  // BRANCH SELECTION
  // ============================================================

  Future<void> _restoreBranchSelection() async {
    final persisted = await SharedPrefsHelper.getString(
      SharedPrefsHelper.selectedBranchId,
    );
    final branchIds = branches
        .map((b) => b['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    if (persisted.isNotEmpty && branchIds.contains(persisted)) {
      selectedBranchId.value = persisted;
    } else {
      selectedBranchId.value = defaultBranchId.value;
    }
  }

  void selectBranch(String id) {
    selectedBranchId.value = id;
    SharedPrefsHelper.setString(SharedPrefsHelper.selectedBranchId, id);
  }

  // ============================================================
  // ERROR HANDLING
  // ============================================================

  void _onError() {
    isLoading.value = false;
    hasError.value = true;

    consolePrint('PROFILE BOOTSTRAP ERROR');

    errorToast('Unable to load profile. Please try again.');
  }

  // ============================================================
  // LOCAL STORAGE SYNC
  // ============================================================

  Future<void> _seedFromPreferences() async {
    userId.value = await SharedPrefsHelper.getString(SharedPrefsHelper.userId);
    username.value = await SharedPrefsHelper.getString(
      SharedPrefsHelper.username,
    );
    fullName.value = await SharedPrefsHelper.getString(
      SharedPrefsHelper.fullName,
    );
    email.value = await SharedPrefsHelper.getString(SharedPrefsHelper.emailId);
    role.value = await SharedPrefsHelper.getString(
      SharedPrefsHelper.userRole,
    );
    organizationId.value = await SharedPrefsHelper.getString(
      SharedPrefsHelper.organizationId,
    );
    organizationName.value = await SharedPrefsHelper.getString(
      SharedPrefsHelper.organizationName,
    );
  }

  Future<void> _persistToPreferences() async {
    if (userId.value.isNotEmpty) {
      await SharedPrefsHelper.setString(SharedPrefsHelper.userId, userId.value);
    }
    if (username.value.isNotEmpty) {
      await SharedPrefsHelper.setString(
        SharedPrefsHelper.username,
        username.value,
      );
    }
    if (fullName.value.isNotEmpty) {
      await SharedPrefsHelper.setString(
        SharedPrefsHelper.fullName,
        fullName.value,
      );
    }
    if (email.value.isNotEmpty) {
      await SharedPrefsHelper.setString(
        SharedPrefsHelper.emailId,
        email.value,
      );
    }
    if (role.value.isNotEmpty) {
      await SharedPrefsHelper.setString(
        SharedPrefsHelper.userRole,
        role.value,
      );
    }
    if (organizationId.value.isNotEmpty) {
      await SharedPrefsHelper.setString(
        SharedPrefsHelper.organizationId,
        organizationId.value,
      );
    }
    if (organizationName.value.isNotEmpty) {
      await SharedPrefsHelper.setString(
        SharedPrefsHelper.organizationName,
        organizationName.value,
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _string(dynamic value) {
    if (value == null) return '';
    final s = value.toString().trim();
    return s == 'null' ? '' : s;
  }
}
