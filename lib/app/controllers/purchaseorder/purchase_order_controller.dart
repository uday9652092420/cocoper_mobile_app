import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

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
  PurchaseOrderController({
    Future<Response<dynamic>?> Function(String endpoint)? getRequest,
    Future<Response<dynamic>?> Function(String endpoint, dynamic body)?
        postRequest,
    Future<Response<dynamic>?> Function(
            String endpoint, Map<String, dynamic> body)?
        putRequest,
  })  : _getRequest = getRequest,
        _postRequest = postRequest,
        _putRequest = putRequest;

  final Future<Response<dynamic>?> Function(String endpoint)? _getRequest;
  final Future<Response<dynamic>?> Function(String endpoint, dynamic body)?
      _postRequest;
  final Future<Response<dynamic>?> Function(
    String endpoint,
    Map<String, dynamic> body,
  )? _putRequest;

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

    final response = await _get(EndPoints.purchaseOrders);

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
    final response = await _get(EndPoints.suppliers);
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
    final response = await _get(EndPoints.items);
    final data = response?.data;

    if (response?.statusCode == 200 && data is List) {
      items.value = data
          .map((e) => LookupOption.fromDynamic(e))
          .where((o) => o.id.isNotEmpty)
          .toList();
    }
  }

  Future<void> _loadBranches() async {
    // Bootstrap returns the branches assigned to the authenticated user.
    final response = await _get(EndPoints.mobileBootstrap);
    final data = response?.data;

    if (response?.statusCode == 200 &&
        data is Map &&
        data['success'] == true &&
        data['branches'] is List) {
      branches.value = (data['branches'] as List)
          .map(LookupOption.fromDynamic)
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
    return roundValue(purchaseCost * actualQuantity, 0);
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
    String? organizationId,
    required String poNumber,
    required String supplierId,
    required String branchId,
    required String date, // YYYY-MM-DD
    required String mode,
    required String remarks,
    required List<PurchaseOrderLine> lines,
  }) async {
    final savedOrganizationId = organizationId?.trim().isNotEmpty == true
        ? organizationId!.trim()
        : await SharedPrefsHelper.getString(
            SharedPrefsHelper.organizationId,
          );
    final body = PurchaseOrder(
      poNumber: poNumber,
      organizationId: savedOrganizationId,
      supplierId: supplierId,
      branchId: branchId,
      date: date,
      remarks: remarks,
      mode: mode,
      lines: lines,
    ).toUpdateRequestJson(organizationId: savedOrganizationId);

    return _submitUpdate(
      id: id,
      body: body,
      successMessage: 'Purchase order updated.',
      failureMessage: 'Unable to save purchase order.',
    );
  }

  Future<bool> approvePurchaseOrder(String id) {
    return _submitUpdate(
      id: id,
      body: const <String, dynamic>{'status': 'Approved'},
      successMessage: 'Purchase Order approved successfully.',
      failureMessage: 'Unable to approve purchase order.',
    );
  }

  Future<bool> _submitPurchaseOrder({
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

      final body = PurchaseOrder(
        poNumber: poNumber,
        organizationId: organizationId,
        supplierId: supplierId,
        branchId: branchId,
        date: date,
        remarks: remarks,
        status: status,
        mode: mode,
        lines: lines,
      ).toRequestJson(organizationId: organizationId);

      consolePrint('PURCHASE ORDER CREATE REQUEST');
      consolePrint('PURCHASE ORDER NUMBER: $poNumber');

      final response = await _post(EndPoints.purchaseOrders, body);

      consolePrint('PURCHASE ORDER SAVE STATUS: ${response?.statusCode}');

      if (isSuccessfulSaveResponse(response)) {
        consolePrint('PURCHASE ORDER SAVE SUCCESS');
        successToast('Purchase order saved successfully.');
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

  Future<bool> _submitUpdate({
    required String id,
    required Map<String, dynamic> body,
    required String successMessage,
    required String failureMessage,
  }) async {
    if (isSaving.value) return false;

    isSaving.value = true;
    try {
      final response = await _put('${EndPoints.purchaseOrders}/$id', body);
      if (!isSuccessfulSaveResponse(response)) {
        final message = _extractMessage(response?.data);
        errorToast(message.isNotEmpty ? message : failureMessage);
        return false;
      }

      final responseOrderData = _extractObject(response?.data);
      final responseOrder = responseOrderData == null
          ? null
          : PurchaseOrder.fromJson(responseOrderData);
      if (responseOrder?.id == id) {
        _replacePurchaseOrder(responseOrder!);
      }

      successToast(successMessage);
      await loadPurchaseOrders();
      if (responseOrder?.id == id) {
        _replacePurchaseOrder(responseOrder!);
      }
      return true;
    } finally {
      isSaving.value = false;
    }
  }

  // ============================================================
  // DETAILS / DELETE
  // ============================================================

  Future<PurchaseOrder?> fetchPurchaseOrderById(String id) async {
    final response = await _get('${EndPoints.purchaseOrders}/$id');
    final data = response?.data;

    if (response?.statusCode == 200) {
      final orderData = _extractObject(data);
      if (orderData != null) {
        final order = PurchaseOrder.fromJson(orderData);
        if (order.id == id) {
          final index = purchaseOrders.indexWhere((item) => item.id == id);
          if (index == -1) {
            purchaseOrders.add(order);
          } else {
            purchaseOrders[index] = order;
          }
          return order;
        }
      }
    }

    final message = _extractMessage(data);
    errorToast(
      message.isNotEmpty
          ? message
          : 'Unable to refresh purchase order. Please try again.',
    );
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
    errorToast(
        message.isNotEmpty ? message : 'Unable to delete purchase order.');
    return false;
  }

  void _replacePurchaseOrder(PurchaseOrder order) {
    final index = purchaseOrders.indexWhere((item) => item.id == order.id);
    if (index == -1) {
      purchaseOrders.add(order);
    } else {
      purchaseOrders[index] = order;
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static bool isSuccessfulSaveResponse(Response<dynamic>? response) =>
      response != null &&
      (response.statusCode == 200 || response.statusCode == 201) &&
      !(response.data is Map && response.data['success'] == false);

  Future<Response<dynamic>?> _get(String endpoint) {
    final request = _getRequest;
    return request == null ? ApiService.get(endpoint) : request(endpoint);
  }

  Future<Response<dynamic>?> _post(String endpoint, dynamic body) {
    final request = _postRequest;
    return request == null
        ? ApiService.post(endpoint, body)
        : request(endpoint, body);
  }

  Future<Response<dynamic>?> _put(
    String endpoint,
    Map<String, dynamic> body,
  ) {
    final request = _putRequest;
    return request == null
        ? ApiService.put(endpoint, body)
        : request(endpoint, body);
  }

  String _extractMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }
    }
    return '';
  }

  Map<String, dynamic>? _extractObject(dynamic data) {
    if (data is! Map) return null;

    final value = data['data'];
    if (value is Map) return Map<String, dynamic>.from(value);

    return Map<String, dynamic>.from(data);
  }
}
