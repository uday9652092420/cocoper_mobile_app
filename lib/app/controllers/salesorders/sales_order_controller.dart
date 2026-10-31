import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../helpers/console_print.dart';
import '../../helpers/flutter_toast.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/lookup_option.dart';
import '../../models/sales_order.dart';
import '../../models/sales_order_line.dart';
import '../../services/api_service.dart';
import '../../services/endpoints.dart';
import '../../services/mobile_app_permissions.dart';

/// Handles Sales Order list, lookups, calculations and create flows
/// against the existing COCOPER backend using the shared [ApiService].
class SalesOrderController extends GetxController {
  static const _conversionLocksPreferenceKey = 'sales_order_conversion_locks';
  static const _unscopedOrganizationKey = '__unscoped__';

  SalesOrderController({
    Future<Response<dynamic>?> Function(String endpoint)? getRequest,
    Future<Response<dynamic>?> Function(String endpoint, dynamic body)?
        postRequest,
    Future<Response<dynamic>?> Function(
            String endpoint, Map<String, dynamic> body)?
        putRequest,
    Future<Response<dynamic>?> Function(String endpoint)? deleteRequest,
  })  : _getRequest = getRequest,
        _postRequest = postRequest,
        _putRequest = putRequest,
        _deleteRequest = deleteRequest;

  final Future<Response<dynamic>?> Function(String endpoint)? _getRequest;
  final Future<Response<dynamic>?> Function(String endpoint, dynamic body)?
      _postRequest;
  final Future<Response<dynamic>?> Function(
    String endpoint,
    Map<String, dynamic> body,
  )? _putRequest;
  final Future<Response<dynamic>?> Function(String endpoint)? _deleteRequest;
  final Set<String> _deletingSalesOrderIds = <String>{};

  // ============================================================
  // LIST STATE
  // ============================================================

  final salesOrders = <SalesOrder>[].obs;
  final isLoadingList = false.obs;
  final hasListError = false.obs;
  final blockedConversionPoIds = <String>{}.obs;
  final conversionReferences = <String, String>{}.obs;
  final conversionSalesOrderIds = <String, String>{}.obs;
  final _persistedConversionPoIds = <String>{};
  final _refreshableConversionPoIds = <String>{};
  final _acceptedUnconfirmedConversionPoIds = <String>{};
  String? _loadedLockOrganizationId;

  // ============================================================
  // LOOKUP STATE
  // ============================================================

  final customers = <LookupOption>[].obs;
  final items = <LookupOption>[].obs;
  final isLoadingLookups = false.obs;

  // ============================================================
  // SAVING STATE
  // ============================================================

  final isSaving = false.obs;
  final isApproving = false.obs;
  String? lastCreatedSalesOrderReference;
  String? lastCreatedSalesOrderId;
  String? lastExistingSalesOrderReference;
  String? lastExistingSalesOrderId;

  // ============================================================
  // LIST
  // ============================================================

  Future<bool> loadSalesOrders({bool showErrors = true}) async {
    isLoadingList.value = true;
    hasListError.value = false;

    consolePrint('SALES ORDER LIST REQUEST');

    try {
      await _restoreConversionLocks();
      final response = await _get(
        EndPoints.salesOrders,
        showServerErrors: showErrors,
      );
      consolePrint('SALES ORDER LIST STATUS: ${response?.statusCode}');

      if (response?.statusCode != 200) {
        hasListError.value = true;
        return false;
      }

      final data = _extractList(response?.data);
      if (data == null) {
        hasListError.value = true;
        return false;
      }

      salesOrders.value = data
          .whereType<Map<String, dynamic>>()
          .map(SalesOrder.fromJson)
          .toList();
      consolePrint(
        'SALES ORDER LIST ITEMS: '
        '${salesOrders.map((order) => '${order.soNumber}:${order.id}:${order.status}').join(', ')}',
      );
      final linkedPurchaseOrderIds = salesOrders
          .map((order) => order.sourcePoId.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      final unconfirmedLocks =
          _refreshableConversionPoIds.difference(linkedPurchaseOrderIds);
      if (unconfirmedLocks.isNotEmpty) {
        _refreshableConversionPoIds.removeAll(unconfirmedLocks);
        _persistedConversionPoIds.removeAll(unconfirmedLocks);
        try {
          await _saveConversionLocks();
        } on StateError {
          _refreshableConversionPoIds.addAll(unconfirmedLocks);
          _persistedConversionPoIds.addAll(unconfirmedLocks);
          rethrow;
        }
      }
      final confirmedLocks = _acceptedUnconfirmedConversionPoIds
          .intersection(linkedPurchaseOrderIds);
      if (confirmedLocks.isNotEmpty) {
        _acceptedUnconfirmedConversionPoIds.removeAll(confirmedLocks);
        _persistedConversionPoIds.removeAll(confirmedLocks);
        try {
          await _saveConversionLocks();
        } on StateError {
          _acceptedUnconfirmedConversionPoIds.addAll(confirmedLocks);
          _persistedConversionPoIds.addAll(confirmedLocks);
          rethrow;
        }
      }
      blockedConversionPoIds
        ..removeWhere(
          (id) =>
              !linkedPurchaseOrderIds.contains(id) &&
              !_persistedConversionPoIds.contains(id),
        )
        ..addAll(linkedPurchaseOrderIds);
      return true;
    } on DioException {
      hasListError.value = true;
      return false;
    } on StateError catch (error) {
      hasListError.value = true;
      if (showErrors) errorToast(error.message.toString());
      return false;
    } finally {
      isLoadingList.value = false;
    }
  }

  /// Sales Orders are available through the verified list read only. Refresh
  /// that list before resolving the selected ID so detail views never reuse a
  /// stale order or accidentally select by its former list position. A server-
  /// returned create/conflict DTO remains usable if the list refresh is delayed.
  Future<SalesOrder?> fetchSalesOrderById(String id) async {
    SalesOrder? cachedOrder;
    for (final order in salesOrders) {
      if (order.id == id) {
        cachedOrder = order;
        break;
      }
    }
    consolePrint(
      'SALES ORDER EDIT LOOKUP: requestedId=$id, '
      'cachedId=${cachedOrder?.id ?? 'missing'}',
    );
    await loadSalesOrders();
    consolePrint(
      'SALES ORDER EDIT LOOKUP RESULT: requestedId=$id, '
      'listCount=${salesOrders.length}, listError=${hasListError.value}',
    );
    if (hasListError.value) return cachedOrder;

    for (final order in salesOrders) {
      if (order.id == id) {
        consolePrint(
          'SALES ORDER EDIT LOAD: id=${order.id}, '
          'organizationId=${order.organizationId.isEmpty ? 'missing' : order.organizationId}, '
          'branchId=${order.branchId.isEmpty ? 'missing' : order.branchId}, '
          'status=${order.status}',
        );
        return order;
      }
    }
    if (cachedOrder != null) {
      consolePrint(
        'SALES ORDER EDIT LOAD: id=${cachedOrder.id}, '
        'organizationId=${cachedOrder.organizationId.isEmpty ? 'missing' : cachedOrder.organizationId}, '
        'branchId=${cachedOrder.branchId.isEmpty ? 'missing' : cachedOrder.branchId}, '
        'status=${cachedOrder.status}; list refresh failed or order not returned',
      );
    }
    return cachedOrder;
  }

  static String normalizedStatus(String status) => status.trim().toLowerCase();

  static bool canEditSalesOrder(SalesOrder order) =>
      normalizedStatus(order.status) == 'draft';

  static bool hasPermission(String action) {
    final permissions = MobileAppPermissions.current;
    final granted = permissions != null &&
        (permissions.hasPermission('sales-order.$action') ||
            permissions.hasPermission('transactions.sales'));
    if (action == 'approve') {
      consolePrint(
        'SALES ORDER APPROVAL PERMISSION: '
        'granted=$granted; '
        'configuredSalesOrderKeys=${permissions?.modulePermissions.where(
              (permission) => permission.startsWith('sales-order.'),
            ).toList() ?? const <String>[]}; '
        'transactions.sales=${permissions?.hasPermission('transactions.sales') ?? false}',
      );
    }
    return granted;
  }

  static bool hasSalesOrderActionPermission(String action) {
    final permissions = MobileAppPermissions.current;
    if (permissions == null) return false;
    if (permissions.hasPermission('sales-order.$action') ||
        permissions.hasPermission('transactions.sales')) {
      return true;
    }

    final hasSalesOrderActionPermissions = permissions.modulePermissions.any(
      (permission) => permission.startsWith('sales-order.'),
    );
    return permissions.canAccessMainApp && !hasSalesOrderActionPermissions;
  }

  bool isPurchaseOrderConversionBlocked(String purchaseOrderId) {
    final id = purchaseOrderId.trim();
    if (id.isEmpty) return false;
    return blockedConversionPoIds.contains(id) ||
        salesOrders.any((order) => order.sourcePoId == id);
  }

  SalesOrder? salesOrderByPurchaseOrderReference({
    required String purchaseOrderId,
    required String poNumber,
  }) {
    final id = purchaseOrderId.trim();
    for (final order in salesOrders) {
      if (id.isNotEmpty && order.sourcePoId.trim() == id) return order;
    }

    final number = poNumber.trim().toLowerCase();
    if (number.isEmpty) return null;
    for (final order in salesOrders) {
      if (order.sourcePoId.trim().isEmpty &&
          order.poNumber.trim().toLowerCase() == number) {
        return order;
      }
    }
    return null;
  }

  SalesOrder? salesOrderForPurchaseOrder(String purchaseOrderId) {
    final id = purchaseOrderId.trim();
    return id.isEmpty ? null : _salesOrderForPurchaseOrder(id);
  }

  bool isAcceptedConversionUnconfirmed(String purchaseOrderId) =>
      _acceptedUnconfirmedConversionPoIds.contains(purchaseOrderId.trim());

  /// Validates the fields and derived line data sent to the Sales Order API.
  static String? validateSalesOrder({
    required String soNumber,
    required String date,
    required String customerId,
    required String mode,
    required List<SalesOrderLine> lines,
  }) {
    if (soNumber.trim().isEmpty) return 'Please enter the SO number.';
    final parsedDate = DateTime.tryParse(date);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        parsedDate == null ||
        parsedDate.toIso8601String().substring(0, 10) != date) {
      return 'Please enter a valid date.';
    }
    if (customerId.trim().isEmpty) return 'Please select a customer.';
    if (!const {modeTonage, modeLessing}.contains(mode)) {
      return 'Select a supported Sales Order mode.';
    }
    if (lines.isEmpty) return 'Please add at least one line item.';

    for (final line in lines) {
      if (line.itemId.trim().isEmpty) {
        return 'Please select an item for every line.';
      }
      if (!line.quantity.isFinite || line.quantity <= 0) {
        return 'Each line quantity must be greater than zero.';
      }
      if (!line.discount.isFinite || line.discount < 0) {
        return 'Discounts cannot be negative.';
      }
      if (!line.salePrice.isFinite || line.salePrice <= 0) {
        return 'Each line Sale Price must be greater than zero.';
      }
      if (!line.pieces.isFinite || line.pieces < 0) {
        return 'Pieces cannot be negative.';
      }
      final actualQuantity = calculateActualQuantity(
        mode: mode,
        quantity: line.quantity,
        discount: line.discount,
        piecesPercentage: line.piecesPercentage,
      );
      if (!actualQuantity.isFinite || actualQuantity <= 0) {
        return 'Each line must have a positive actual quantity.';
      }
      final saleAmount = calculateSaleAmount(line.salePrice, actualQuantity);
      if (!saleAmount.isFinite || saleAmount <= 0) {
        return 'Each line must have a valid positive sale amount.';
      }
    }
    return null;
  }

  // ============================================================
  // LOOKUPS
  // ============================================================

  Future<void> loadLookups() async {
    isLoadingLookups.value = true;
    await Future.wait([_loadCustomers(), _loadItems()]);
    isLoadingLookups.value = false;
  }

  Future<void> _loadCustomers() async {
    final response = await ApiService.get(EndPoints.customers);
    final data = response?.data;

    if (response?.statusCode == 200) {
      final list = _extractList(data);
      if (list != null) {
        customers.value = list
            .map((e) => LookupOption.fromDynamic(e))
            .where((o) => o.id.isNotEmpty)
            .toList();
      }
    }
  }

  Future<void> _loadItems() async {
    final response = await ApiService.get(EndPoints.items);
    final data = response?.data;

    if (response?.statusCode == 200) {
      final list = _extractList(data);
      if (list != null) {
        items.value = list
            .map((e) => LookupOption.fromDynamic(e))
            .where((o) => o.id.isNotEmpty)
            .toList();
      }
    }
  }

  /// Accepts either a raw array or the {success, data: []} envelope used by
  /// several COCOPER master endpoints.
  List<dynamic>? _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in const ['data', 'items', 'results', 'records']) {
        final value = data[key];
        if (value is List) return value;
        if (value is Map) {
          final nested = _extractList(value);
          if (nested != null) return nested;
        }
      }
    }
    return null;
  }

  // ============================================================
  // SO NUMBER GENERATION
  // ============================================================

  /// Reproduces the web client-side numbering: <OrganizationInitial>SO-<NN>.
  Future<String> generateSoNumber() async {
    final organizationName = await SharedPrefsHelper.getString(
      SharedPrefsHelper.organizationName,
    );

    final initial = organizationName.trim().isNotEmpty
        ? organizationName.trim()[0].toUpperCase()
        : 'S';

    final prefix = '${initial}SO-';

    var maxNumber = 0;
    for (final so in salesOrders) {
      final number = so.soNumber.toUpperCase();
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
  // CALCULATIONS (verified Sales Order contract — 6-decimal)
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

  /// Sales Order actual quantity is retained to 6 decimal places (unlike the
  /// Purchase Order which rounds to an integer).
  static double calculateActualQuantity({
    required String mode,
    required double quantity,
    required double discount,
    required double piecesPercentage,
  }) {
    switch (mode) {
      case modeLessing:
        return roundValue(quantity - discount, 6);

      case modeTonagePercentage:
        final effectiveDiscount = discount != 0
            ? discount
            : quantity * clampNum(piecesPercentage, 0, 100) / 100;
        return roundValue(quantity - effectiveDiscount, 6);

      case modeTonage:
      default:
        final denominator = 1000 + discount;
        final safeDenominator = denominator == 0 ? 1.0 : denominator;
        return roundValue(quantity * 1000 / safeDenominator, 6);
    }
  }

  static double calculateSaleAmount(double salePrice, double actualQuantity) {
    return roundValue(salePrice * actualQuantity, 2);
  }

  static double calculateBaseCost(double saleAmount, double pieces) {
    if (pieces <= 0) return 0;
    return roundValue(saleAmount / pieces, 2);
  }

  static double calculateTotalAmount(List<SalesOrderLine> lines) {
    return lines.fold(
      0.0,
      (sum, line) => sum + line.effectiveSaleAmount,
    );
  }

  /// Frontend-only profit: total sale amount minus total purchase amount.
  static double calculateProfit(
    double totalSaleAmount,
    double totalPurchaseAmount,
  ) {
    return totalSaleAmount - totalPurchaseAmount;
  }

  // ============================================================
  // CREATE / UPDATE
  // ============================================================

  Future<bool> createSalesOrder({
    required String soNumber,
    required String date, // YYYY-MM-DD
    required String customerId,
    required String remarks,
    required String mode,
    String branchId = '',
    required String sourcePoId,
    required String poNumber,
    required List<SalesOrderLine> lines,
  }) {
    return _submitSalesOrder(
      soNumber: soNumber,
      date: date,
      customerId: customerId,
      remarks: remarks,
      mode: mode,
      branchId: branchId,
      sourcePoId: sourcePoId,
      poNumber: poNumber,
      lines: lines,
      status: 'Draft',
    );
  }

  Future<bool> updateSalesOrder({
    required String id,
    required String status,
    String organizationId = '',
    String branchId = '',
    required String soNumber,
    required String date,
    required String customerId,
    required String remarks,
    required String mode,
    required List<SalesOrderLine> lines,
  }) async {
    if (isSaving.value) return false;
    if (!hasSalesOrderActionPermission('edit')) {
      errorToast('You do not have permission to edit Sales Orders.');
      return false;
    }

    isSaving.value = true;
    var updateSubmitted = false;
    try {
      final validationError = validateSalesOrder(
        soNumber: soNumber,
        date: date,
        customerId: customerId,
        mode: mode,
        lines: lines,
      );
      if (validationError != null) {
        errorToast(validationError);
        return false;
      }

      if (normalizedStatus(status) != 'draft') {
        errorToast('Only a Draft Sales Order can be edited.');
        return false;
      }

      final latestResponse = await _get(
        '${EndPoints.salesOrders}/$id',
        showServerErrors: false,
        diagnosticLabel: 'sales-order.update.preflight',
      );
      final latestOrder = latestResponse?.statusCode == 200
          ? SalesOrder.fromApiResponse(latestResponse?.data)
          : null;
      if (latestOrder == null || latestOrder.id != id) {
        final message = _extractMessage(latestResponse?.data);
        errorToast(
          message.isNotEmpty
              ? message
              : 'Unable to verify the latest Sales Order. No changes were saved.',
        );
        return false;
      }
      if (!canEditSalesOrder(latestOrder)) {
        errorToast('This Sales Order is no longer an editable Draft.');
        return false;
      }

      final selectedOrganizationId = await SharedPrefsHelper.getString(
        SharedPrefsHelper.organizationId,
      );
      final effectiveOrganizationId = latestOrder.organizationId.isNotEmpty
          ? latestOrder.organizationId
          : organizationId.trim().isNotEmpty
              ? organizationId.trim()
              : selectedOrganizationId.trim();
      if (effectiveOrganizationId.isEmpty) {
        errorToast(
          'The Sales Order organization identifier is invalid. '
          'Refresh the selected organization.',
        );
        return false;
      }

      final payload = SalesOrder(
        soNumber: soNumber,
        organizationId: effectiveOrganizationId,
        date: date,
        customerId: customerId,
        remarks: remarks,
        status: latestOrder.status,
        mode: mode,
        sourcePoId: latestOrder.sourcePoId,
        poNumber: latestOrder.poNumber,
        lines: lines,
      ).toUpdateRequestJson();
      consolePrint(
        'SALES ORDER UPDATE REQUEST: '
        'id=$id, organizationId=${payload['organizationId'] ?? 'missing'}, '
        'status=${latestOrder.status}, fields=${payload.keys.toList()}',
      );
      updateSubmitted = true;
      final response = await _put(
        '${EndPoints.salesOrders}/$id',
        payload,
        showServerErrors: false,
        diagnosticLabel: 'sales-order.update',
      );
      consolePrint(
        'SALES ORDER UPDATE RESPONSE: '
        'id=$id, status=${response?.statusCode ?? 'no response'}, '
        'message=${_extractMessage(response?.data)}',
      );
      final savedOrder = SalesOrder.fromApiResponse(response?.data);
      final responseConfirmsUpdate = _hasExplicitSuccess(response?.data) ||
          savedOrder == null ||
          savedOrder.id.isEmpty ||
          _confirmsSalesOrderUpdate(
            savedOrder,
            id: id,
            soNumber: soNumber,
            date: date,
            customerId: customerId,
            remarks: remarks,
            mode: mode,
            sourcePoId: latestOrder.sourcePoId,
            poNumber: latestOrder.poNumber,
            lines: lines,
          );
      if (response?.statusCode != 200 ||
          !_isNotExplicitlyRejected(response?.data) ||
          !responseConfirmsUpdate) {
        final message = _extractMessage(response?.data);
        _logSalesOrderFailure('PUT', response, message);
        errorToast(
          message.isNotEmpty
              ? message
              : response == null ||
                      response.statusCode == null ||
                      response.statusCode! >= 500
                  ? 'The save outcome could not be confirmed. Refresh the '
                      'Sales Order before trying again; do not resubmit yet.'
                  : 'The Sales Order was not saved (HTTP '
                      '${response.statusCode}).',
        );
        return false;
      }

      if (savedOrder != null &&
          _confirmsSalesOrderUpdate(
            savedOrder,
            id: id,
            soNumber: soNumber,
            date: date,
            customerId: customerId,
            remarks: remarks,
            mode: mode,
            sourcePoId: latestOrder.sourcePoId,
            poNumber: latestOrder.poNumber,
            lines: lines,
          )) {
        _upsertSalesOrder(savedOrder);
      }

      var refreshed = false;
      try {
        refreshed = await loadSalesOrders(showErrors: false);
      } on StateError catch (error) {
        consolePrint('SALES ORDER POST-SAVE REFRESH ERROR: ${error.message}');
      } on DioException catch (error) {
        consolePrint('SALES ORDER POST-SAVE REFRESH ERROR: $error');
      } catch (error) {
        consolePrint('SALES ORDER POST-SAVE REFRESH ERROR: $error');
      }
      if (!refreshed) {
        successToast(
          'Sales Order saved successfully. The list could not be refreshed.',
        );
      } else {
        successToast('Sales Order saved successfully.');
      }
      return true;
    } on DioException catch (error) {
      final response = error.response;
      final message = _extractMessage(response?.data);
      _logSalesOrderFailure('PUT', response, message);
      errorToast(message.isNotEmpty
          ? message
          : updateSubmitted
              ? 'The save outcome could not be confirmed. Refresh the Sales '
                  'Order before trying again; do not resubmit yet.'
              : 'Unable to verify the Sales Order: '
                  '${error.message ?? 'network error'}');
      return false;
    } catch (error) {
      consolePrint('SALES ORDER UPDATE ERROR: $error');
      errorToast(
        updateSubmitted
            ? 'The save outcome could not be confirmed. Refresh the Sales '
                'Order before trying again; do not resubmit yet.'
            : 'Unable to save the Sales Order: $error',
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteSalesOrder(String id) async {
    if (!hasSalesOrderActionPermission('delete')) {
      errorToast('You do not have permission to delete Sales Orders.');
      return false;
    }
    if (!_deletingSalesOrderIds.add(id)) return false;

    try {
      final latestResponse = await _get(
        '${EndPoints.salesOrders}/$id',
        showServerErrors: false,
        diagnosticLabel: 'sales-order.delete.preflight',
      );
      final latestOrder = latestResponse?.statusCode == 200
          ? SalesOrder.fromApiResponse(latestResponse?.data)
          : null;
      if (latestOrder == null || latestOrder.id != id) {
        final message = _extractMessage(latestResponse?.data);
        errorToast(
          message.isNotEmpty
              ? message
              : 'Unable to verify the latest Sales Order. It was not deleted.',
        );
        return false;
      }
      if (!canEditSalesOrder(latestOrder)) {
        errorToast('Only a Draft Sales Order can be deleted.');
        return false;
      }

      final response = await _delete('${EndPoints.salesOrders}/$id');
      if ((response?.statusCode != 200 && response?.statusCode != 204) ||
          !_isNotExplicitlyRejected(response?.data)) {
        final message = _extractMessage(response?.data);
        _logSalesOrderFailure('DELETE', response, message);
        errorToast(
          message.isNotEmpty
              ? message
              : 'Unable to delete Sales Order'
                  '${response?.statusCode == null ? '.' : ' (HTTP ${response?.statusCode}).'}',
        );
        return false;
      }

      salesOrders.removeWhere((order) => order.id == id);
      var refreshed = false;
      try {
        refreshed = await loadSalesOrders(showErrors: false);
      } on StateError catch (error) {
        consolePrint('SALES ORDER POST-DELETE REFRESH ERROR: ${error.message}');
      } on DioException catch (error) {
        consolePrint('SALES ORDER POST-DELETE REFRESH ERROR: $error');
      }
      successToast(
        refreshed
            ? 'Sales Order deleted successfully.'
            : 'Sales Order deleted successfully. The list could not be refreshed.',
      );
      return true;
    } on DioException catch (error) {
      final response = error.response;
      final message = _extractMessage(response?.data);
      _logSalesOrderFailure('DELETE', response, message);
      errorToast(
        message.isNotEmpty
            ? message
            : 'Unable to delete Sales Order. Please try again.',
      );
      return false;
    } finally {
      _deletingSalesOrderIds.remove(id);
    }
  }

  Future<bool> approveSalesOrder({
    required String id,
    required String status,
    String organizationId = '',
    String branchId = '',
    required String soNumber,
    required String date,
    required String customerId,
    required String remarks,
    required String mode,
    required List<SalesOrderLine> lines,
  }) async {
    if (isSaving.value) return false;
    if (!hasPermission('approve')) {
      errorToast('You do not have permission to approve Sales Orders.');
      return false;
    }
    isSaving.value = true;
    isApproving.value = true;
    var approvalSubmitted = false;
    try {
      final validationError = validateSalesOrder(
        soNumber: soNumber,
        date: date,
        customerId: customerId,
        mode: mode,
        lines: lines,
      );
      if (validationError != null) {
        errorToast(validationError);
        return false;
      }
      if (normalizedStatus(status) != 'draft') {
        errorToast('Only a Draft Sales Order can be approved.');
        return false;
      }

      final latestResponse = await _get(
        '${EndPoints.salesOrders}/$id',
        showServerErrors: false,
        diagnosticLabel: 'sales-order.approve.preflight',
      );
      final latestOrder = latestResponse?.statusCode == 200
          ? SalesOrder.fromApiResponse(latestResponse?.data)
          : null;
      if (latestOrder == null || latestOrder.id != id) {
        final message = _extractMessage(latestResponse?.data);
        errorToast(
          message.isNotEmpty
              ? message
              : 'Unable to verify the latest Sales Order. It was not approved.',
        );
        return false;
      }
      if (!canEditSalesOrder(latestOrder)) {
        errorToast('This Sales Order is no longer a Draft.');
        return false;
      }

      final selectedOrganizationId = await SharedPrefsHelper.getString(
        SharedPrefsHelper.organizationId,
      );
      final effectiveOrganizationId = latestOrder.organizationId.isNotEmpty
          ? latestOrder.organizationId
          : organizationId.trim().isNotEmpty
              ? organizationId.trim()
              : selectedOrganizationId.trim();
      if (effectiveOrganizationId.isEmpty) {
        errorToast(
          'The Sales Order organization identifier is invalid. '
          'Refresh the selected organization.',
        );
        return false;
      }

      final payload = SalesOrder(
        soNumber: soNumber,
        organizationId: effectiveOrganizationId,
        date: date,
        customerId: customerId,
        remarks: remarks,
        status: 'Approved',
        mode: mode,
        sourcePoId: latestOrder.sourcePoId,
        poNumber: latestOrder.poNumber,
        lines: lines,
      ).toUpdateRequestJson()
        ..['status'] = 'Approved';
      approvalSubmitted = true;
      final response = await _put(
        '${EndPoints.salesOrders}/$id',
        payload,
        showServerErrors: false,
        diagnosticLabel: 'sales-order.approve',
      );
      if (response?.statusCode != 200 ||
          !_isNotExplicitlyRejected(response?.data)) {
        final message = _extractMessage(response?.data);
        _logSalesOrderFailure('PUT', response, message);
        errorToast(
          message.isNotEmpty
              ? message
              : 'The Sales Order approval could not be confirmed.',
        );
        return false;
      }

      var approvedOrder = SalesOrder.fromApiResponse(response?.data);
      if (approvedOrder?.id != id ||
          normalizedStatus(approvedOrder?.status ?? '') != 'approved') {
        final verifyResponse = await _get(
          '${EndPoints.salesOrders}/$id',
          showServerErrors: false,
          diagnosticLabel: 'sales-order.approve.verify',
        );
        approvedOrder = verifyResponse?.statusCode == 200
            ? SalesOrder.fromApiResponse(verifyResponse?.data)
            : null;
      }
      if (approvedOrder == null ||
          approvedOrder.id != id ||
          normalizedStatus(approvedOrder.status) != 'approved') {
        final message = _extractMessage(response?.data);
        errorToast(
          message.isNotEmpty
              ? message
              : 'The server did not confirm the Sales Order as Approved. '
                  'Refresh its status before trying again.',
        );
        return false;
      }

      _upsertSalesOrder(approvedOrder);
      var refreshed = false;
      try {
        refreshed = await loadSalesOrders(showErrors: false);
      } on StateError catch (error) {
        consolePrint(
            'SALES ORDER POST-APPROVAL REFRESH ERROR: ${error.message}');
      } on DioException catch (error) {
        consolePrint('SALES ORDER POST-APPROVAL REFRESH ERROR: $error');
      }
      _upsertSalesOrder(approvedOrder);
      successToast(
        refreshed
            ? 'Sales Order approved successfully.'
            : 'Sales Order approved successfully. The list could not be refreshed.',
      );
      return true;
    } on DioException catch (error) {
      final response = error.response;
      final message = _extractMessage(response?.data);
      _logSalesOrderFailure('PUT', response, message);
      errorToast(
        message.isNotEmpty
            ? message
            : approvalSubmitted
                ? 'The approval outcome could not be confirmed. Refresh the '
                    'Sales Order before trying again.'
                : 'Unable to verify the Sales Order: '
                    '${error.message ?? 'network error'}',
      );
      return false;
    } catch (error) {
      consolePrint('SALES ORDER APPROVAL ERROR: $error');
      errorToast(
        approvalSubmitted
            ? 'The approval outcome could not be confirmed. Refresh the '
                'Sales Order before trying again.'
            : 'Unable to approve the Sales Order: $error',
      );
      return false;
    } finally {
      isApproving.value = false;
      isSaving.value = false;
    }
  }

  bool _confirmsSalesOrderUpdate(
    SalesOrder savedOrder, {
    required String id,
    required String soNumber,
    required String date,
    required String customerId,
    required String remarks,
    required String mode,
    required String sourcePoId,
    required String poNumber,
    required List<SalesOrderLine> lines,
  }) {
    if (savedOrder.id != id ||
        !canEditSalesOrder(savedOrder) ||
        savedOrder.soNumber != soNumber ||
        !_sameDate(savedOrder.date, date) ||
        savedOrder.customerId != customerId ||
        savedOrder.remarks != remarks ||
        savedOrder.mode != mode ||
        savedOrder.sourcePoId != sourcePoId ||
        savedOrder.poNumber != poNumber ||
        savedOrder.lines.length != lines.length ||
        savedOrder.savedTotalAmount == null ||
        !_sameCurrency(
          savedOrder.savedTotalAmount!,
          calculateTotalAmount(lines),
        )) {
      return false;
    }

    for (var index = 0; index < lines.length; index++) {
      final requested = lines[index];
      final saved = savedOrder.lines[index];
      if (saved.itemId != requested.itemId ||
          !_sameNumber(saved.quantity, requested.quantity) ||
          !_sameNumber(saved.discount, requested.discount) ||
          !_sameNumber(saved.piecesPercentage, requested.piecesPercentage) ||
          !_sameNumber(saved.pieces, requested.pieces) ||
          !_sameNumber(saved.actualQuantity, requested.actualQuantity) ||
          !_sameNumber(saved.salePrice, requested.salePrice) ||
          !_sameCurrency(
            saved.effectiveSaleAmount,
            requested.effectiveSaleAmount,
          )) {
        return false;
      }
    }
    return true;
  }

  bool _sameNumber(double first, double second) =>
      first.isFinite && second.isFinite && (first - second).abs() < 0.000001;

  bool _sameCurrency(double first, double second) =>
      first.isFinite && second.isFinite && (first - second).abs() <= 0.01;

  bool _sameDate(String first, String second) {
    DateTime? parsed(String value) => DateTime.tryParse(value.trim());
    final firstDate = parsed(first);
    final secondDate = parsed(second);
    if (firstDate == null || secondDate == null) {
      return first.trim() == second.trim();
    }
    return firstDate.toIso8601String().substring(0, 10) ==
        secondDate.toIso8601String().substring(0, 10);
  }

  Future<bool> _submitSalesOrder({
    required String status,
    required String soNumber,
    required String date,
    required String customerId,
    required String remarks,
    required String mode,
    String branchId = '',
    String sourcePoId = '',
    String poNumber = '',
    required List<SalesOrderLine> lines,
  }) async {
    if (isSaving.value) return false;
    var createSubmitted = false;

    final conversionPoId = sourcePoId.trim();
    if (conversionPoId.isNotEmpty) {
      await _restoreConversionLocks();
    }
    if (isSaving.value) return false;
    if (conversionPoId.isNotEmpty &&
        isPurchaseOrderConversionBlocked(conversionPoId)) {
      final reference = conversionReferences[conversionPoId] ??
          _salesOrderForPurchaseOrder(conversionPoId)?.soNumber ??
          '';
      errorToast(
        reference.isNotEmpty
            ? 'This Purchase Order already has Sales Order $reference.'
            : 'This Purchase Order conversion is already submitted or needs '
                'verification. Refresh before trying again.',
      );
      return false;
    }

    isSaving.value = true;

    try {
      lastCreatedSalesOrderReference = null;
      lastCreatedSalesOrderId = null;
      lastExistingSalesOrderReference = null;
      lastExistingSalesOrderId = null;
      if (conversionPoId.isNotEmpty) {
        _persistedConversionPoIds.add(conversionPoId);
        _refreshableConversionPoIds.add(conversionPoId);
        blockedConversionPoIds.add(conversionPoId);
        await _saveConversionLocks();
      }

      final body = SalesOrder(
        soNumber: soNumber,
        date: date,
        customerId: customerId,
        branchId: branchId,
        remarks: remarks,
        status: status,
        mode: mode,
        sourcePoId: sourcePoId,
        poNumber: poNumber,
        lines: lines,
      ).toCreateRequestJson();

      consolePrint('SALES ORDER CREATE REQUEST');
      consolePrint('SALES ORDER NUMBER: $soNumber');
      if (conversionPoId.isNotEmpty) {
        consolePrint(
          'SALES ORDER CONVERSION REQUEST: purchaseOrderId=$conversionPoId',
        );
      }

      createSubmitted = true;
      final response = await _post(
        EndPoints.salesOrders,
        body,
        showServerErrors: false,
        diagnosticLabel: 'sales-order.create',
      );

      consolePrint('SALES ORDER SAVE STATUS: ${response?.statusCode}');
      if (conversionPoId.isNotEmpty) {
        final responseOrder = SalesOrder.fromCreateResponse(response?.data);
        final successIndicator = response?.data is Map
            ? response?.data['success']?.toString() ?? 'not provided'
            : 'not provided';
        final backendMessage = _extractMessage(response?.data);
        consolePrint(
          'SALES ORDER CONVERSION RESPONSE: purchaseOrderId=$conversionPoId, '
          'httpStatus=${response?.statusCode ?? 'no response'}, '
          'success=$successIndicator, '
          'message=${backendMessage.isEmpty ? 'none' : _safeLogMessage(backendMessage)}, '
          'salesOrderId=${responseOrder?.id.isNotEmpty == true ? responseOrder!.id : 'none'}',
        );
      }

      if (conversionPoId.isNotEmpty && response?.statusCode == 409) {
        final responseOrder = _extractExistingSalesOrder(response?.data);
        SalesOrder? existing;
        if (responseOrder != null &&
            responseOrder.sourcePoId == conversionPoId) {
          existing = responseOrder;
          await _rememberExistingConversion(conversionPoId, existing);
        }
        await loadSalesOrders();
        existing ??= _salesOrderForPurchaseOrder(conversionPoId);
        if (existing != null) {
          await _rememberExistingConversion(conversionPoId, existing);
        }
        final reference = existing?.soNumber ?? '';
        if (reference.isNotEmpty) {
          conversionReferences[conversionPoId] = reference;
        }
        if (response?.data is Map &&
            response?.data['code'] == 'PURCHASE_ORDER_ALREADY_CONVERTED' &&
            existing?.id.isNotEmpty == true) {
          lastExistingSalesOrderId = existing!.id;
          lastExistingSalesOrderReference = existing.soNumber;
        }
        final serverMessage = _extractMessage(response?.data);
        errorToast(
          reference.isEmpty
              ? serverMessage.isNotEmpty
                  ? 'Conversion rejected: $serverMessage'
                  : hasListError.value
                      ? 'The server reported a conversion conflict, but the '
                          'Sales Orders list could not be refreshed. Try '
                          'refreshing before converting again.'
                      : 'The server reported a conversion conflict, but no '
                          'linked Sales Order was found. Ask an administrator '
                          'to verify this Purchase Order before retrying.'
              : 'This Purchase Order is already converted to Sales Order '
                  '$reference.',
        );
        return false;
      }

      if (isSuccessfulCreateResponse(
        response,
        isPurchaseOrderConversion: conversionPoId.isNotEmpty,
      )) {
        consolePrint('SALES ORDER SAVE SUCCESS');
        if (conversionPoId.isNotEmpty) {
          _refreshableConversionPoIds.remove(conversionPoId);
          _acceptedUnconfirmedConversionPoIds.add(conversionPoId);
          await _saveConversionLocks();
          final responseOrder = SalesOrder.fromCreateResponse(response?.data);
          if (responseOrder != null &&
              responseOrder.sourcePoId.isNotEmpty &&
              responseOrder.sourcePoId != conversionPoId) {
            errorToast(
              'The server accepted a Sales Order with a different Purchase '
              'Order link. Do not retry; contact your administrator.',
            );
            return false;
          }

          var refreshed = false;
          try {
            refreshed = await loadSalesOrders(showErrors: false);
          } on StateError catch (error) {
            consolePrint(
                'SALES ORDER POST-SAVE REFRESH ERROR: ${error.message}');
          } on DioException catch (error) {
            consolePrint('SALES ORDER POST-SAVE REFRESH ERROR: $error');
          } catch (error) {
            consolePrint('SALES ORDER POST-SAVE REFRESH ERROR: $error');
          }
          final listedOrder =
              refreshed ? _salesOrderForPurchaseOrder(conversionPoId) : null;
          final created = listedOrder ??
              (responseOrder != null &&
                      responseOrder.id.isNotEmpty &&
                      responseOrder.soNumber.isNotEmpty &&
                      responseOrder.sourcePoId == conversionPoId
                  ? responseOrder
                  : null);
          if (created == null ||
              created.id.isEmpty ||
              created.soNumber.isEmpty) {
            errorToast(
              'The server accepted the conversion, but its Purchase Order '
              'link could not be confirmed. Do not retry; refresh or contact '
              'your administrator.',
            );
            return false;
          }
          _upsertSalesOrder(created);
          lastCreatedSalesOrderId = created.id;
          lastCreatedSalesOrderReference = created.soNumber;
          conversionReferences[conversionPoId] = created.soNumber;
          conversionSalesOrderIds[conversionPoId] = created.id;
          consolePrint(
            'SALES ORDER CONVERSION VERIFICATION: '
            'purchaseOrderId=$conversionPoId, result=confirmed, '
            'source=response-or-list, salesOrderId=${created.id}',
          );
          if (listedOrder != null) {
            await _removeConversionLock(conversionPoId);
          } else {
            blockedConversionPoIds.add(conversionPoId);
            await _saveConversionLocks();
          }
        } else {
          final responseOrder = SalesOrder.fromCreateResponse(response?.data);
          var refreshed = false;
          try {
            refreshed = await loadSalesOrders(showErrors: false);
          } on StateError catch (error) {
            consolePrint(
                'SALES ORDER POST-SAVE REFRESH ERROR: ${error.message}');
          } on DioException catch (error) {
            consolePrint('SALES ORDER POST-SAVE REFRESH ERROR: $error');
          } catch (error) {
            consolePrint('SALES ORDER POST-SAVE REFRESH ERROR: $error');
          }
          if (responseOrder != null && responseOrder.id.isNotEmpty) {
            lastCreatedSalesOrderId = responseOrder.id;
            lastCreatedSalesOrderReference = responseOrder.soNumber;
          }
          if (refreshed) {
            SalesOrder? savedOrder;
            for (final order in salesOrders) {
              if (order.soNumber == soNumber ||
                  (lastCreatedSalesOrderId?.isNotEmpty == true &&
                      order.id == lastCreatedSalesOrderId)) {
                savedOrder = order;
                break;
              }
            }
            if (savedOrder != null) {
              lastCreatedSalesOrderId = savedOrder.id;
              lastCreatedSalesOrderReference = savedOrder.soNumber;
            }
          }
          successToast(
            refreshed
                ? 'Sales order saved successfully.'
                : 'Sales order saved successfully. The list could not be '
                    'refreshed.',
          );
        }
        return true;
      }

      final statusCode = response?.statusCode;
      final explicitlyRejected =
          response?.data is Map && response?.data['success'] == false;
      final serverMessage = _extractMessage(response?.data);
      _logSalesOrderFailure('POST', response, serverMessage);
      final isAmbiguousResponse = response == null ||
          (!explicitlyRejected &&
              (statusCode == 200 ||
                  statusCode == 408 ||
                  statusCode == 504 ||
                  (statusCode != null && statusCode >= 500)));
      if (isAmbiguousResponse) {
        if (conversionPoId.isNotEmpty) {
          var refreshed = false;
          try {
            refreshed = await loadSalesOrders(showErrors: false);
          } on StateError catch (error) {
            consolePrint(
              'SALES ORDER CONVERSION VERIFICATION ERROR: ${error.message}',
            );
          } on DioException catch (error) {
            consolePrint(
              'SALES ORDER CONVERSION VERIFICATION ERROR: $error',
            );
          }

          final linkedOrder =
              refreshed ? _salesOrderForPurchaseOrder(conversionPoId) : null;
          final verified = linkedOrder != null &&
              linkedOrder.id.isNotEmpty &&
              linkedOrder.sourcePoId == conversionPoId;
          consolePrint(
            'SALES ORDER CONVERSION VERIFICATION: '
            'purchaseOrderId=$conversionPoId, '
            'result=${verified ? 'linked' : refreshed ? 'not found' : 'unavailable'}, '
            'salesOrderId=${verified ? linkedOrder.id : 'none'}',
          );
          if (verified) {
            _upsertSalesOrder(linkedOrder);
            lastCreatedSalesOrderId = linkedOrder.id;
            lastCreatedSalesOrderReference = linkedOrder.soNumber;
            conversionReferences[conversionPoId] = linkedOrder.soNumber;
            conversionSalesOrderIds[conversionPoId] = linkedOrder.id;
            await _removeConversionLock(conversionPoId);
            return true;
          }

          final responseClaimsSuccess =
              response?.data is Map && response?.data['success'] == true;
          if (refreshed && !responseClaimsSuccess) {
            await _removeConversionLock(conversionPoId);
            errorToast(
              serverMessage.isNotEmpty
                  ? serverMessage
                  : 'No Sales Order linked to this Purchase Order was found. '
                      'You may retry the conversion.',
            );
            return false;
          }
        }

        final uncertaintyMessage = conversionPoId.isNotEmpty
            ? 'The conversion outcome could not be confirmed. Do not retry '
                'yet; verify the Purchase Order and Sales Order with your '
                'administrator.'
            : 'The save outcome could not be confirmed. Refresh the Sales '
                'Orders list before trying again; do not resubmit yet.';
        errorToast(
          serverMessage.isEmpty
              ? uncertaintyMessage
              : '$serverMessage. $uncertaintyMessage',
        );
        return false;
      }

      if (conversionPoId.isNotEmpty) {
        await _removeConversionLock(conversionPoId);
      }

      final message = serverMessage.isNotEmpty
          ? serverMessage
          : conversionErrorMessage(statusCode) ?? '';
      errorToast(
        message.isNotEmpty
            ? message
            : conversionErrorMessage(statusCode) ??
                'Unable to save sales order.',
      );
      return false;
    } on StateError catch (error) {
      errorToast(error.message.toString());
      return false;
    } on DioException catch (error) {
      final response = error.response;
      final serverMessage = _extractMessage(response?.data);
      _logSalesOrderFailure('POST', response, serverMessage);
      if (conversionPoId.isNotEmpty) {
        var refreshed = false;
        try {
          refreshed = await loadSalesOrders(showErrors: false);
        } on StateError catch (refreshError) {
          consolePrint(
            'SALES ORDER CONVERSION VERIFICATION ERROR: '
            '${refreshError.message}',
          );
        }
        final linkedOrder =
            refreshed ? _salesOrderForPurchaseOrder(conversionPoId) : null;
        if (linkedOrder != null &&
            linkedOrder.id.isNotEmpty &&
            linkedOrder.sourcePoId == conversionPoId) {
          _upsertSalesOrder(linkedOrder);
          lastCreatedSalesOrderId = linkedOrder.id;
          lastCreatedSalesOrderReference = linkedOrder.soNumber;
          conversionReferences[conversionPoId] = linkedOrder.soNumber;
          conversionSalesOrderIds[conversionPoId] = linkedOrder.id;
          await _removeConversionLock(conversionPoId);
          consolePrint(
            'SALES ORDER CONVERSION VERIFICATION: '
            'purchaseOrderId=$conversionPoId, result=linked, '
            'salesOrderId=${linkedOrder.id}',
          );
          return true;
        }
        if (refreshed && response?.statusCode != 409) {
          await _removeConversionLock(conversionPoId);
          errorToast(
            serverMessage.isNotEmpty
                ? serverMessage
                : 'No Sales Order linked to this Purchase Order was found. '
                    'You may retry the conversion.',
          );
        } else {
          blockedConversionPoIds.add(conversionPoId);
          errorToast(
            'The conversion outcome could not be confirmed. Do not retry yet; '
            'verify the Purchase Order and Sales Order with your administrator.',
          );
        }
      } else if (createSubmitted) {
        final statusCode = response?.statusCode;
        final ambiguous = response == null ||
            statusCode == 408 ||
            statusCode == 504 ||
            (statusCode != null && statusCode >= 500);
        errorToast(serverMessage.isNotEmpty
            ? serverMessage
            : ambiguous
                ? 'The save outcome could not be confirmed. Refresh the Sales '
                    'Orders list before trying again; do not resubmit yet.'
                : 'Unable to save the Sales Order (HTTP $statusCode).');
      } else {
        errorToast(serverMessage.isNotEmpty
            ? serverMessage
            : 'Unable to prepare the Sales Order request.');
      }
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _restoreConversionLocks() async {
    final organizationId = await SharedPrefsHelper.getString(
      SharedPrefsHelper.organizationId,
    );
    if (_loadedLockOrganizationId == organizationId) return;

    _loadedLockOrganizationId = organizationId;
    blockedConversionPoIds.clear();
    conversionReferences.clear();
    conversionSalesOrderIds.clear();
    _persistedConversionPoIds.clear();
    _refreshableConversionPoIds.clear();
    _acceptedUnconfirmedConversionPoIds.clear();

    final lockMap = Map<String, dynamic>.from(
      await SharedPrefsHelper.getMap(_conversionLocksPreferenceKey),
    );
    final lockState = lockMap[_organizationLockKey(organizationId)];
    if (lockState is List) {
      final legacyIds =
          lockState.whereType<String>().map((id) => id.trim()).where(
                (id) => id.isNotEmpty,
              );
      _persistedConversionPoIds.addAll(legacyIds);
      _refreshableConversionPoIds.addAll(legacyIds);
    } else if (lockState is Map) {
      final refreshableIds = _readConversionLockIds(lockState['refreshable']);
      final acceptedUnconfirmedIds =
          _readConversionLockIds(lockState['acceptedUnconfirmed']);
      _refreshableConversionPoIds.addAll(refreshableIds);
      _acceptedUnconfirmedConversionPoIds.addAll(acceptedUnconfirmedIds);
      _persistedConversionPoIds
        ..addAll(refreshableIds)
        ..addAll(acceptedUnconfirmedIds);
    }
    blockedConversionPoIds.addAll(_persistedConversionPoIds);
  }

  Future<void> _removeConversionLock(String purchaseOrderId) async {
    _persistedConversionPoIds.remove(purchaseOrderId);
    _refreshableConversionPoIds.remove(purchaseOrderId);
    _acceptedUnconfirmedConversionPoIds.remove(purchaseOrderId);
    blockedConversionPoIds.remove(purchaseOrderId);
    await _saveConversionLocks();
  }

  Future<void> _saveConversionLocks() async {
    final organizationId = _loadedLockOrganizationId ?? '';
    final key = _organizationLockKey(organizationId);
    final lockMap = Map<String, dynamic>.from(
      await SharedPrefsHelper.getMap(_conversionLocksPreferenceKey),
    );

    if (_persistedConversionPoIds.isEmpty) {
      lockMap.remove(key);
    } else {
      lockMap[key] = <String, dynamic>{
        'refreshable': _refreshableConversionPoIds.toList(growable: false),
        'acceptedUnconfirmed':
            _acceptedUnconfirmedConversionPoIds.toList(growable: false),
      };
    }

    final saved = lockMap.isEmpty
        ? await SharedPrefsHelper.remove(_conversionLocksPreferenceKey)
        : await SharedPrefsHelper.setMap(
            _conversionLocksPreferenceKey,
            lockMap,
          );
    if (!saved) {
      throw StateError('Unable to save Purchase Order conversion status.');
    }
  }

  String _organizationLockKey(String organizationId) =>
      organizationId.isEmpty ? _unscopedOrganizationKey : organizationId;

  List<String> _readConversionLockIds(dynamic value) => value is List
      ? value
          .whereType<String>()
          .map((id) => id.trim())
          .where(
            (id) => id.isNotEmpty,
          )
          .toList()
      : const [];

  // ============================================================
  // HELPERS
  // ============================================================

  static bool isSuccessfulCreateResponse(
    Response<dynamic>? response, {
    bool isPurchaseOrderConversion = false,
  }) {
    if (response == null ||
        !(isPurchaseOrderConversion
            ? response.statusCode == 200 || response.statusCode == 201
            : response.statusCode == 200 || response.statusCode == 201) ||
        !_isNotExplicitlyRejected(response.data)) {
      return false;
    }

    return true;
  }

  static bool _hasExplicitSuccess(dynamic data) =>
      data is Map && data['success'] == true;

  static bool _isNotExplicitlyRejected(dynamic data) =>
      data is! Map ||
      (data['success'] != false &&
          data['status']?.toString().toLowerCase() != 'error');

  static String? conversionErrorMessage(int? statusCode) {
    switch (statusCode) {
      case 401:
        return 'Your session has expired. Sign in again before converting.';
      case 403:
        return 'You are not authorized to convert this Purchase Order.';
      case 404:
        return 'The Purchase Order was not found. Refresh the Purchase Order '
            'list and try again.';
      case 409:
        return 'This Purchase Order has already been converted or cannot be '
            'converted in its current state.';
      default:
        return null;
    }
  }

  SalesOrder? _salesOrderForPurchaseOrder(String purchaseOrderId) {
    for (final order in salesOrders) {
      if (order.sourcePoId == purchaseOrderId) return order;
    }
    return null;
  }

  Future<Response<dynamic>?> _get(
    String endpoint, {
    bool showServerErrors = true,
    String? diagnosticLabel,
  }) {
    final request = _getRequest;
    return request == null
        ? ApiService.get(
            endpoint,
            showServerErrors: showServerErrors,
            diagnosticLabel: diagnosticLabel,
          )
        : request(endpoint);
  }

  Future<Response<dynamic>?> _post(
    String endpoint,
    dynamic body, {
    bool showServerErrors = true,
    String? diagnosticLabel,
  }) {
    final request = _postRequest;
    return request == null
        ? ApiService.post(
            endpoint,
            body,
            showServerErrors: showServerErrors,
            diagnosticLabel: diagnosticLabel,
          )
        : request(endpoint, body);
  }

  Future<Response<dynamic>?> _put(
    String endpoint,
    Map<String, dynamic> body, {
    bool showServerErrors = true,
    String? diagnosticLabel,
  }) {
    final request = _putRequest;
    return request == null
        ? ApiService.put(
            endpoint,
            body,
            showServerErrors: showServerErrors,
            diagnosticLabel: diagnosticLabel,
          )
        : request(endpoint, body);
  }

  Future<Response<dynamic>?> _delete(String endpoint) {
    final request = _deleteRequest;
    return request == null ? ApiService.delete(endpoint) : request(endpoint);
  }

  void _logSalesOrderFailure(
    String method,
    Response<dynamic>? response,
    String message,
  ) {
    final code = response?.data is Map
        ? response?.data['code'] ?? response?.data['errorCode']
        : null;
    consolePrint(
      'SALES ORDER $method FAILED: HTTP ${response?.statusCode ?? 'no response'}'
      '${code == null ? '' : ', code: $code'}'
      '${message.isEmpty ? '' : ', message: $message'}',
    );
  }

  String _safeLogMessage(String message) {
    final normalized = message.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return normalized.length > 300
        ? '${normalized.substring(0, 300)}…'
        : normalized;
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

  SalesOrder? _extractExistingSalesOrder(dynamic data) {
    if (data is! Map) return null;
    final details = data['details'];
    if (details is! Map) return null;
    final order = details['salesOrder'];
    if (order is! Map) return null;
    final mapped = SalesOrder.fromJson(Map<String, dynamic>.from(order));
    return mapped.id.isEmpty ? null : mapped;
  }

  Future<void> _rememberExistingConversion(
    String purchaseOrderId,
    SalesOrder order,
  ) async {
    _upsertSalesOrder(order);
    if (order.soNumber.isNotEmpty) {
      conversionReferences[purchaseOrderId] = order.soNumber;
    }
    if (order.id.isNotEmpty) {
      conversionSalesOrderIds[purchaseOrderId] = order.id;
    }
    _persistedConversionPoIds.add(purchaseOrderId);
    _acceptedUnconfirmedConversionPoIds.add(purchaseOrderId);
    blockedConversionPoIds.add(purchaseOrderId);
    await _saveConversionLocks();
  }

  void _upsertSalesOrder(SalesOrder order) {
    salesOrders.removeWhere(
      (saved) =>
          saved.id == order.id ||
          (order.sourcePoId.isNotEmpty && saved.sourcePoId == order.sourcePoId),
    );
    salesOrders.insert(0, order);
  }
}
