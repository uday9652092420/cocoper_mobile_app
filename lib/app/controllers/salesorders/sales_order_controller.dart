import 'dart:math' as math;

import 'package:get/get.dart';

import '../../helpers/console_print.dart';
import '../../helpers/flutter_toast.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/lookup_option.dart';
import '../../models/sales_order.dart';
import '../../models/sales_order_line.dart';
import '../../services/api_service.dart';
import '../../services/endpoints.dart';

/// Handles Sales Order list, lookups, calculations and save/update flows
/// against the existing COCOPER backend using the shared [ApiService].
class SalesOrderController extends GetxController {
  // ============================================================
  // LIST STATE
  // ============================================================

  final salesOrders = <SalesOrder>[].obs;
  final isLoadingList = false.obs;
  final hasListError = false.obs;

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

  // ============================================================
  // LIST
  // ============================================================

  Future<void> loadSalesOrders() async {
    isLoadingList.value = true;
    hasListError.value = false;

    consolePrint('SALES ORDER LIST REQUEST');

    final response = await ApiService.get(EndPoints.salesOrders);

    consolePrint('SALES ORDER LIST STATUS: ${response?.statusCode}');

    if (response?.statusCode == 200) {
      final data = _extractList(response?.data);
      if (data != null) {
        salesOrders.value = data
            .whereType<Map<String, dynamic>>()
            .map(SalesOrder.fromJson)
            .toList();
      } else {
        hasListError.value = true;
      }
    } else {
      hasListError.value = true;
    }

    isLoadingList.value = false;
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
    return lines.fold(0.0, (sum, line) => sum + line.saleAmount);
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
  }) {
    return _submitSalesOrder(
      id: id,
      soNumber: soNumber,
      date: date,
      customerId: customerId,
      remarks: remarks,
      mode: mode,
      lines: lines,
      status: status,
    );
  }

  Future<bool> _submitSalesOrder({
    String? id,
    required String status,
    required String soNumber,
    required String date,
    required String customerId,
    required String remarks,
    required String mode,
    String sourcePoId = '',
    String poNumber = '',
    required List<SalesOrderLine> lines,
  }) async {
    if (isSaving.value) return false;

    isSaving.value = true;

    try {
      final body = <String, dynamic>{
        'soNumber': soNumber,
        'date': date,
        if (customerId.isNotEmpty) 'customerId': customerId,
        if (remarks.isNotEmpty) 'remarks': remarks,
        'status': status,
        'mode': mode,
        // Source PO information for conversions.
        if (sourcePoId.isNotEmpty) 'sourcePoId': sourcePoId,
        if (poNumber.isNotEmpty) 'poNumber': poNumber,
        'lines': lines.map((line) => line.toJson()).toList(),
      };

      consolePrint(
        id == null
            ? 'SALES ORDER CREATE REQUEST'
            : 'SALES ORDER UPDATE REQUEST',
      );
      consolePrint('SALES ORDER NUMBER: $soNumber');

      final response = id == null
          ? await ApiService.post(EndPoints.salesOrders, body)
          : await ApiService.put('${EndPoints.salesOrders}/$id', body);

      consolePrint('SALES ORDER SAVE STATUS: ${response?.statusCode}');

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201)) {
        consolePrint('SALES ORDER SAVE SUCCESS');
        successToast(
          id == null
              ? 'Sales order saved successfully.'
              : 'Sales order updated.',
        );
        await loadSalesOrders();
        return true;
      }

      final message = _extractMessage(response?.data);
      errorToast(
        message.isNotEmpty ? message : 'Unable to save sales order.',
      );
      return false;
    } finally {
      isSaving.value = false;
    }
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
