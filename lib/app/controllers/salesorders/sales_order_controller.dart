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

/// Handles Sales Order list, lookups, calculations and create flows
/// against the existing COCOPER backend using the shared [ApiService].
class SalesOrderController extends GetxController {
  static const _conversionLocksPreferenceKey = 'sales_order_conversion_locks';
  static const _unscopedOrganizationKey = '__unscoped__';

  SalesOrderController({
    Future<Response<dynamic>?> Function(String endpoint)? getRequest,
    Future<Response<dynamic>?> Function(String endpoint, dynamic body)?
        postRequest,
  })  : _getRequest = getRequest,
        _postRequest = postRequest;

  final Future<Response<dynamic>?> Function(String endpoint)? _getRequest;
  final Future<Response<dynamic>?> Function(String endpoint, dynamic body)?
      _postRequest;

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
  String? lastCreatedSalesOrderReference;
  String? lastCreatedSalesOrderId;

  // ============================================================
  // LIST
  // ============================================================

  Future<bool> loadSalesOrders() async {
    await _restoreConversionLocks();
    isLoadingList.value = true;
    hasListError.value = false;

    consolePrint('SALES ORDER LIST REQUEST');

    try {
      final response = await _get(EndPoints.salesOrders);
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
      blockedConversionPoIds.addAll(
        salesOrders
            .map((order) => order.sourcePoId.trim())
            .where((id) => id.isNotEmpty),
      );
      return true;
    } on DioException {
      hasListError.value = true;
      return false;
    } finally {
      isLoadingList.value = false;
    }
  }

  /// Sales Orders are available through the verified list read only. Refresh
  /// that list before resolving the selected ID so detail views never reuse a
  /// stale order or accidentally select by its former list position.
  Future<SalesOrder?> fetchSalesOrderById(String id) async {
    await loadSalesOrders();
    if (hasListError.value) return null;

    for (final order in salesOrders) {
      if (order.id == id) return order;
    }
    return null;
  }

  static String normalizedStatus(String status) => status.trim().toLowerCase();

  static bool canEditSalesOrder(SalesOrder order) =>
      normalizedStatus(order.status) == 'draft';

  bool isPurchaseOrderConversionBlocked(String purchaseOrderId) {
    final id = purchaseOrderId.trim();
    if (id.isEmpty) return false;
    return blockedConversionPoIds.contains(id) ||
        salesOrders.any((order) => order.sourcePoId == id);
  }

  /// Validates the fields that are present in the verified Sales Order model.
  /// The server write is intentionally not enabled without an update contract.
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
      if (!line.saleCost.isFinite || line.saleCost <= 0) {
        return 'Each line sale cost must be greater than zero.';
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
      final saleAmount = calculateSaleAmount(line.saleCost, actualQuantity);
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

  static double calculateSaleAmount(double saleCost, double actualQuantity) {
    return roundValue(saleCost * actualQuantity, 2);
  }

  static double calculateBaseCost(double saleAmount, double pieces) {
    if (pieces <= 0) return 0;
    return roundValue(saleAmount / pieces, 2);
  }

  static double calculateTotalAmount(List<SalesOrderLine> lines) {
    return lines.fold(
      0.0,
      (sum, line) =>
          sum + (line.saleAmount != 0 ? line.saleAmount : line.amount),
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
    required String soNumber,
    required String date,
    required String customerId,
    required String remarks,
    required String mode,
    required List<SalesOrderLine> lines,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
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

      final latestOrder = await fetchSalesOrderById(id);
      if (latestOrder == null) {
        errorToast(
          hasListError.value
              ? 'Unable to verify the latest Sales Order status.'
              : 'This Sales Order is no longer available.',
        );
        return false;
      }
      if (!canEditSalesOrder(latestOrder)) {
        errorToast('This Sales Order is no longer an editable Draft.');
        return false;
      }

      errorToast(
        'Sales Order editing is unavailable because no update endpoint is '
        'verified.',
      );
      return false;
    } finally {
      isSaving.value = false;
    }
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
      if (conversionPoId.isNotEmpty) {
        _persistedConversionPoIds.add(conversionPoId);
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

      final response = await _post(EndPoints.salesOrders, body);

      consolePrint('SALES ORDER SAVE STATUS: ${response?.statusCode}');

      if (conversionPoId.isNotEmpty && response?.statusCode == 409) {
        await loadSalesOrders();
        final existing = _salesOrderForPurchaseOrder(conversionPoId);
        final reference = existing?.soNumber ?? '';
        if (reference.isNotEmpty) {
          conversionReferences[conversionPoId] = reference;
        }
        errorToast(
          reference.isEmpty
              ? 'This Purchase Order has a conversion conflict. Refresh its '
                  'status before trying again.'
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
          final refreshed = await loadSalesOrders();
          final created =
              refreshed ? _salesOrderForPurchaseOrder(conversionPoId) : null;
          final responseOrder = SalesOrder.fromCreateResponse(response?.data);
          final responseLinkMatches = responseOrder == null ||
              responseOrder.sourcePoId.isEmpty ||
              responseOrder.sourcePoId == conversionPoId;
          final responseIdMatches = responseOrder == null ||
              responseOrder.id.isEmpty ||
              responseOrder.id == created?.id;

          if (created == null ||
              created.id.isEmpty ||
              created.soNumber.isEmpty ||
              !responseLinkMatches ||
              !responseIdMatches) {
            errorToast(
              'The server accepted the conversion, but the refreshed Sales '
              'Orders list did not confirm the saved record and Purchase '
              'Order link. Do not retry; refresh or contact your administrator.',
            );
            return false;
          }

          lastCreatedSalesOrderId = created.id;
          lastCreatedSalesOrderReference = created.soNumber;
          conversionReferences[conversionPoId] = created.soNumber;
          conversionSalesOrderIds[conversionPoId] = created.id;
        } else {
          await loadSalesOrders();
        }
        if (conversionPoId.isEmpty) {
          successToast('Sales order saved successfully.');
        }
        return true;
      }

      final statusCode = response?.statusCode;
      final explicitlyRejected =
          response?.data is Map && response?.data['success'] == false;
      final isAmbiguousConversionResponse = response == null ||
          (!explicitlyRejected &&
              (statusCode == 200 ||
                  statusCode == 408 ||
                  statusCode == 504 ||
                  (statusCode != null && statusCode >= 500)));
      if (conversionPoId.isNotEmpty && isAmbiguousConversionResponse) {
        errorToast(
          'The conversion outcome could not be confirmed. Do not retry yet; '
          'verify the Purchase Order and Sales Order with your administrator.',
        );
        return false;
      }

      if (conversionPoId.isNotEmpty) {
        await _removeConversionLock(conversionPoId);
      }

      final message = conversionPoId.isNotEmpty
          ? conversionErrorMessage(statusCode) ??
              _extractMessage(response?.data)
          : _extractMessage(response?.data);
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
    } on DioException {
      if (conversionPoId.isNotEmpty) {
        blockedConversionPoIds.add(conversionPoId);
        errorToast(
          'The conversion outcome could not be confirmed. Do not retry yet; '
          'verify the Purchase Order and Sales Order with your administrator.',
        );
      } else {
        errorToast('Unable to save sales order.');
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

    final lockMap = Map<String, dynamic>.from(
      await SharedPrefsHelper.getMap(_conversionLocksPreferenceKey),
    );
    final ids = lockMap[_organizationLockKey(organizationId)];
    if (ids is List) {
      _persistedConversionPoIds.addAll(
        ids.whereType<String>().map((id) => id.trim()).where(
              (id) => id.isNotEmpty,
            ),
      );
      blockedConversionPoIds.addAll(_persistedConversionPoIds);
    }
  }

  Future<void> _removeConversionLock(String purchaseOrderId) async {
    _persistedConversionPoIds.remove(purchaseOrderId);
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
      lockMap[key] = _persistedConversionPoIds.toList(growable: false);
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

  // ============================================================
  // HELPERS
  // ============================================================

  static bool isSuccessfulCreateResponse(
    Response<dynamic>? response, {
    bool isPurchaseOrderConversion = false,
  }) =>
      response != null &&
      (isPurchaseOrderConversion
          ? response.statusCode == 201
          : response.statusCode == 200 || response.statusCode == 201) &&
      !(response.data is Map && response.data['success'] == false);

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
