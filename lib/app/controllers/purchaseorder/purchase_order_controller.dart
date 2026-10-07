import 'dart:math' as math;

import 'package:get/get.dart';

import '../../helpers/console_print.dart';
import '../../helpers/flutter_toast.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/lookup_option.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_order_line.dart';
import '../../services/api_service.dart';
import '../../services/endpoints.dart';

/// Handles the Purchase Order list, lookups and create/save flow against the
/// existing COCOPER backend using the shared [ApiService].
class PurchaseOrderController extends GetxController {
  // ============================================================
  // LIST STATE
  // ============================================================

  final purchaseOrders = <PurchaseOrder>[].obs;
  final isLoadingList = false.obs;
  final hasListError = false.obs;
  final listError = ''.obs;

  // ============================================================
  // LOOKUP STATE
  // ============================================================

  final suppliers = <LookupOption>[].obs;
  final items = <LookupOption>[].obs;
  final branches = <LookupOption>[].obs;
  final isLoadingLookups = false.obs;

  // ============================================================
  // SAVING STATE
  // ============================================================

  final isSaving = false.obs;

  // ============================================================
  // LIST
  // ============================================================

  Future<void> loadPurchaseOrders() async {
    isLoadingList.value = true;
    hasListError.value = false;
    listError.value = '';

    consolePrint('PURCHASE ORDER LIST REQUEST');

    final response = await ApiService.get(EndPoints.purchaseOrders);

    consolePrint('PURCHASE ORDER LIST STATUS: ${response?.statusCode}');

    if (response == null) {
      isLoadingList.value = false;
      hasListError.value = true;
      listError.value = 'Unable to load purchase orders.';
      return;
    }

    final data = response.data;

    if (response.statusCode == 200 && data is List) {
      purchaseOrders.value = data
          .whereType<Map<String, dynamic>>()
          .map(PurchaseOrder.fromJson)
          .toList();
      isLoadingList.value = false;
      consolePrint('PURCHASE ORDER LIST SUCCESS: ${purchaseOrders.length}');
      return;
    }

    isLoadingList.value = false;
    hasListError.value = true;
    listError.value = _extractMessage(data).isNotEmpty
        ? _extractMessage(data)
        : 'Unable to load purchase orders.';
  }

  // ============================================================
  // LOOKUPS
  // ============================================================

  Future<void> loadLookups() async {
    isLoadingLookups.value = true;

    await Future.wait([
      _loadSuppliers(),
      _loadItems(),
      _loadBranches(),
    ]);

    isLoadingLookups.value = false;
  }

  Future<void> _loadSuppliers() async {
    // NOTE: /suppliers uses the {success, data: []} envelope.
    final response = await ApiService.get(EndPoints.suppliers);
    final data = response?.data;

    if (response?.statusCode == 200 && data is Map) {
      final list = data['data'];
      if (list is List) {
        suppliers.value = list
            .map((e) => LookupOption.fromDynamic(e))
            .where((o) => o.id.isNotEmpty)
            .toList();
      }
    }
  }

  Future<void> _loadItems() async {
    // NOTE: /items returns a raw array.
    final response = await ApiService.get(EndPoints.items);
    final data = response?.data;

    if (response?.statusCode == 200 && data is List) {
      items.value = data
          .map((e) => LookupOption.fromDynamic(e))
          .where((o) => o.id.isNotEmpty)
          .toList();
    }
  }

  Future<void> _loadBranches() async {
    // NOTE: /branches returns a raw array.
    final response = await ApiService.get(EndPoints.branches);
    final data = response?.data;

    if (response?.statusCode == 200 && data is List) {
      branches.value = data
          .map((e) => LookupOption.fromDynamic(e))
          .where((o) => o.id.isNotEmpty)
          .toList();
    }
  }

  // ============================================================
  // CREATE FORM PREPARATION
  // ============================================================

  /// Loads lookups (and the list, so numbering is correct) and returns a
  /// suggested PO number.
  Future<String> prepareCreate() async {
    await Future.wait([
      loadLookups(),
      if (purchaseOrders.isEmpty) loadPurchaseOrders(),
    ]);

    return generatePoNumber();
  }

  // ============================================================
  // PO NUMBER GENERATION
  // ============================================================

  /// Reproduces the web client-side numbering: <OrganizationInitial>PO-<NN>.
  ///
  /// The initial is the first letter of the organization name and NN is the
  /// next zero-padded counter derived from the existing list.
  Future<String> generatePoNumber() async {
    final organizationName = await SharedPrefsHelper.getString(
      SharedPrefsHelper.organizationName,
    );

    final initial = organizationName.trim().isNotEmpty
        ? organizationName.trim()[0].toUpperCase()
        : 'P';

    final prefix = '${initial}PO-';

    var maxNumber = 0;
    for (final po in purchaseOrders) {
      final number = po.poNumber.toUpperCase();
      if (number.startsWith(prefix)) {
        final parsed = int.tryParse(number.substring(prefix.length));
        if (parsed != null && parsed > maxNumber) {
          maxNumber = parsed;
        }
      }
    }

    return '$prefix${(maxNumber + 1).toString().padLeft(2, '0')}';
  }

  // ============================================================
  // CALCULATIONS (verified web PurchaseOrderPage.tsx contract)
  // ============================================================

  static const String modeTonage = 'tonage';
  static const String modeTonagePercentage = 'tonagePercentage';
  static const String modeLessing = 'lessing';

  static double clampNum(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Reproduces JavaScript's Math.round (halves round towards +Infinity).
  static double jsRound(double value) {
    if (!value.isFinite) return 0;
    return (value + 0.5).floorToDouble();
  }

  static double roundValue(double value, int decimals) {
    if (!value.isFinite) return 0;
    final factor = math.pow(10, decimals).toDouble();
    final result = jsRound(value * factor) / factor;
    return result.isFinite ? result : 0;
  }

  static double percentageDiscount(double quantity, double piecesPercentage) {
    return quantity * clampNum(piecesPercentage, 0, 100) / 100;
  }

  static double calculateActualQuantity({
    required String mode,
    required double quantity,
    required double discount,
    required double piecesPercentage,
  }) {
    switch (mode) {
      case modeLessing:
        return roundValue(quantity - discount, 0);

      case modeTonagePercentage:
        final percentage = percentageDiscount(quantity, piecesPercentage);
        // Discount (Kgs) takes precedence over Pieces % when non-zero.
        final effectiveDiscount = discount != 0 ? discount : percentage;
        return roundValue(quantity - effectiveDiscount, 0);

      case modeTonage:
      default:
        final denominator = 1000 + discount;
        final safeDenominator = denominator == 0 ? 1.0 : denominator;
        return roundValue(quantity * 1000 / safeDenominator, 0);
    }
  }

  static double calculatePurchaseAmount(
    double purchaseCost,
    double actualQuantity,
  ) {
    return purchaseCost * actualQuantity;
  }

  static double calculateBaseCost(double purchaseAmount, double pieces) {
    if (pieces <= 0) return 0;
    return roundValue(purchaseAmount / pieces, 2);
  }

  static double calculateTotalAmount(List<PurchaseOrderLine> lines) {
    return lines.fold(0.0, (sum, line) => sum + line.purchaseAmount);
  }

  // ============================================================
  // CREATE / UPDATE / APPROVE
  // ============================================================

  Future<bool> createPurchaseOrder({
    required String poNumber,
    required String supplierId,
    required String branchId,
    required String date, // YYYY-MM-DD
    required String mode,
    required String remarks,
    required List<PurchaseOrderLine> lines,
  }) {
    return _submitPurchaseOrder(
      poNumber: poNumber,
      supplierId: supplierId,
      branchId: branchId,
      date: date,
      mode: mode,
      remarks: remarks,
      lines: lines,
      status: 'Draft',
    );
  }

  Future<bool> updatePurchaseOrder({
    required String id,
    required String status,
    required String poNumber,
    required String supplierId,
    required String branchId,
    required String date, // YYYY-MM-DD
    required String mode,
    required String remarks,
    required List<PurchaseOrderLine> lines,
  }) {
    return _submitPurchaseOrder(
      id: id,
      poNumber: poNumber,
      supplierId: supplierId,
      branchId: branchId,
      date: date,
      mode: mode,
      remarks: remarks,
      lines: lines,
      status: status,
    );
  }

  Future<bool> _submitPurchaseOrder({
    String? id,
    required String status,
    required String poNumber,
    required String supplierId,
    required String branchId,
    required String date,
    required String mode,
    required String remarks,
    required List<PurchaseOrderLine> lines,
  }) async {
    if (isSaving.value) return false;

    isSaving.value = true;

    try {
      final organizationId = await SharedPrefsHelper.getString(
        SharedPrefsHelper.organizationId,
      );

      final body = <String, dynamic>{
        'poNumber': poNumber,
        'organizationId': organizationId,
        'supplierId': supplierId,
        if (branchId.isNotEmpty) 'branchId': branchId,
        'date': date,
        if (remarks.isNotEmpty) 'remarks': remarks,
        'status': status,
        'mode': mode,
        'lines': lines.map((line) => line.toJson()).toList(),
      };

      consolePrint(
        id == null
            ? 'PURCHASE ORDER CREATE REQUEST'
            : 'PURCHASE ORDER UPDATE REQUEST',
      );
      consolePrint('PURCHASE ORDER NUMBER: $poNumber');

      final response = id == null
          ? await ApiService.post(EndPoints.purchaseOrders, body)
          : await ApiService.put('${EndPoints.purchaseOrders}/$id', body);

      consolePrint('PURCHASE ORDER SAVE STATUS: ${response?.statusCode}');

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201)) {
        consolePrint('PURCHASE ORDER SAVE SUCCESS');
        successToast(
          id == null
              ? 'Purchase order saved successfully.'
              : 'Purchase order updated.',
        );
        await loadPurchaseOrders();
        return true;
      }

      final message = _extractMessage(response?.data);
      errorToast(
        message.isNotEmpty ? message : 'Unable to save purchase order.',
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // ============================================================
  // DETAILS / DELETE
  // ============================================================

  Future<PurchaseOrder?> fetchPurchaseOrderById(String id) async {
    final response = await ApiService.get('${EndPoints.purchaseOrders}/$id');
    final data = response?.data;

    if (response?.statusCode == 200 && data is Map) {
      return PurchaseOrder.fromJson(Map<String, dynamic>.from(data));
    }

    return null;
  }

  Future<bool> deletePurchaseOrder(String id) async {
    final response = await ApiService.delete(
      '${EndPoints.purchaseOrders}/$id',
    );

    if (response != null && response.statusCode == 200) {
      successToast('Purchase order deleted.');
      await loadPurchaseOrders();
      return true;
    }

    final message = _extractMessage(response?.data);
    errorToast(message.isNotEmpty ? message : 'Unable to delete purchase order.');
    return false;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _extractMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }
    }
    return '';
  }
}
