import 'dart:math' as math;

import 'package:get/get.dart';

import '../../helpers/console_print.dart';
import '../../helpers/flutter_toast.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/lookup_option.dart';
import '../../models/purchase_invoice.dart';
import '../../models/purchase_invoice_line.dart';
import '../../models/purchase_order.dart';
import '../../services/api_service.dart';
import '../../services/endpoints.dart';

/// Handles the Purchase Invoice list, lookups, calculations and the
/// create/save/update/approve/delete flows against the COCOPER backend.
class PurchaseInvoiceController extends GetxController {
  // ============================================================
  // LIST STATE
  // ============================================================

  final purchaseInvoices = <PurchaseInvoice>[].obs;
  final isLoadingList = false.obs;
  final hasListError = false.obs;
  final listError = ''.obs;

  final searchQuery = ''.obs;

  // ============================================================
  // LOOKUP STATE
  // ============================================================

  final suppliers = <LookupOption>[].obs;
  final items = <LookupOption>[].obs;
  final branches = <LookupOption>[].obs;
  final purchaseOrders = <PurchaseOrder>[].obs;
  final isLoadingLookups = false.obs;

  // ============================================================
  // SAVING STATE
  // ============================================================

  final isSaving = false.obs;

  // ============================================================
  // LIST
  // ============================================================

  Future<void> loadPurchaseInvoices() async {
    isLoadingList.value = true;
    hasListError.value = false;
    listError.value = '';

    consolePrint('PURCHASE INVOICE LIST REQUEST');

    final response = await ApiService.get(EndPoints.purchaseInvoices);

    consolePrint('PURCHASE INVOICE LIST STATUS: ${response?.statusCode}');

    if (response == null) {
      isLoadingList.value = false;
      hasListError.value = true;
      listError.value = 'Unable to load purchase invoices.';
      return;
    }

    final data = response.data;

    if (response.statusCode == 200 && data is List) {
      purchaseInvoices.value = data
          .whereType<Map<String, dynamic>>()
          .map(PurchaseInvoice.fromJson)
          .toList();
      isLoadingList.value = false;
      consolePrint(
        'PURCHASE INVOICE LIST SUCCESS: ${purchaseInvoices.length}',
      );
      return;
    }

    isLoadingList.value = false;
    hasListError.value = true;
    listError.value = _extractMessage(data).isNotEmpty
        ? _extractMessage(data)
        : 'Unable to load purchase invoices.';
  }

  /// Client-side search across invoice number, supplier and branch — mirrors
  /// the web "Search by invoice no, supplier, branch…" behaviour.
  List<PurchaseInvoice> get filteredInvoices {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return purchaseInvoices;

    return purchaseInvoices.where((invoice) {
      return invoice.invoiceNumber.toLowerCase().contains(query) ||
          invoice.supplierName.toLowerCase().contains(query) ||
          invoice.branchName.toLowerCase().contains(query);
    }).toList();
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
      _loadPurchaseOrders(),
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

  Future<void> _loadPurchaseOrders() async {
    // NOTE: /purchase-orders returns a raw array.
    final response = await ApiService.get(EndPoints.purchaseOrders);
    final data = response?.data;

    if (response?.statusCode == 200 && data is List) {
      purchaseOrders.value = data
          .whereType<Map<String, dynamic>>()
          .map(PurchaseOrder.fromJson)
          .toList();
    }
  }

  /// Purchase Orders eligible for PO → Purchase Invoice conversion:
  /// status == "Approved" AND purchaseOrderInvoiceStatus == false.
  List<PurchaseOrder> get eligiblePurchaseOrders {
    return purchaseOrders.where((po) {
      final approved = po.status.trim().toLowerCase() == 'approved';
      final invoiceStatus = po.purchaseOrderInvoiceStatus.trim().toLowerCase();
      final notInvoiced = invoiceStatus.isEmpty ||
          invoiceStatus == 'false' ||
          invoiceStatus == '0';
      return approved && notInvoiced;
    }).toList();
  }

  /// Eligible purchase orders as id/label pairs for the form's PO selector.
  List<LookupOption> get purchaseOrderOptions {
    return eligiblePurchaseOrders
        .map(
          (po) => LookupOption(
            id: po.id,
            label: po.poNumber.isEmpty
                ? po.supplierName
                : (po.supplierName.isEmpty
                    ? po.poNumber
                    : '${po.poNumber} — ${po.supplierName}'),
          ),
        )
        .toList();
  }

  // ============================================================
  // CREATE FORM PREPARATION
  // ============================================================

  /// Loads lookups (and the saved list, so numbering is correct) and returns
  /// a suggested invoice number.
  Future<String> prepareCreate() async {
    await Future.wait([
      loadLookups(),
      if (purchaseInvoices.isEmpty) loadPurchaseInvoices(),
    ]);

    return generateInvoiceNumber();
  }

  // ============================================================
  // INVOICE NUMBER GENERATION
  // ============================================================

  /// Reproduces the web client-side numbering: <OrganizationInitial>PI-<NN>.
  Future<String> generateInvoiceNumber() async {
    final organizationName = await SharedPrefsHelper.getString(
      SharedPrefsHelper.organizationName,
    );

    final initial = organizationName.trim().isNotEmpty
        ? organizationName.trim()[0].toUpperCase()
        : 'P';

    final prefix = '${initial}PI-';

    var maxNumber = 0;
    for (final invoice in purchaseInvoices) {
      final number = invoice.invoiceNumber.toUpperCase();
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
  // CALCULATIONS (verified Purchase Invoice contract)
  // ============================================================

  static const String modeTonage = 'tonage';
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

  /// Purchase Invoice actual quantity is rounded to an integer.
  ///
  /// Tonnage:       quantity × 1000 / (1000 + discount)
  /// Tonnage + %:   quantity − (quantity × piecesPercentage / 100)
  /// Lessing:       quantity − discount
  static double calculateActualQuantity({
    required String mode,
    required double quantity,
    required double discount,
    required double piecesPercentage,
  }) {
    switch (mode) {
      case modeLessing:
        return roundValue(quantity - discount, 0);

      case modeTonage:
      default:
        if (piecesPercentage > 0) {
          final percentage = percentageDiscount(quantity, piecesPercentage);
          return roundValue(quantity - percentage, 0);
        }
        final denominator = 1000 + discount;
        final safeDenominator = denominator == 0 ? 1.0 : denominator;
        return roundValue(quantity * 1000 / safeDenominator, 0);
    }
  }

  static double calculatePurchaseAmount(
    double purchaseCost,
    double actualQuantity,
  ) {
    return roundValue(purchaseCost * actualQuantity, 2);
  }

  static double calculateBaseCost(double purchaseAmount, double pieces) {
    if (pieces <= 0) return 0;
    return roundValue(purchaseAmount / pieces, 2);
  }

  // ============================================================
  // CREATE / UPDATE
  // ============================================================

  Future<bool> createPurchaseInvoice({
    required String invoiceNo,
    required String supplierId,
    required String branchId,
    required String purchaseOrderId,
    required String date, // DD/MM/YYYY
    required String mode,
    required double loadingCost,
    required double marketCess,
    required double bagsAndSticks,
    required double freight,
    required double grandTotal,
    required double outstandingAmount,
    required List<PurchaseInvoiceLine> lines,
  }) {
    return _submit(
      invoiceNo: invoiceNo,
      supplierId: supplierId,
      branchId: branchId,
      purchaseOrderId: purchaseOrderId,
      date: date,
      mode: mode,
      loadingCost: loadingCost,
      marketCess: marketCess,
      bagsAndSticks: bagsAndSticks,
      freight: freight,
      grandTotal: grandTotal,
      outstandingAmount: outstandingAmount,
      status: 'Draft',
      lines: lines,
    );
  }

  Future<bool> updatePurchaseInvoice({
    required String id,
    required String status,
    required String invoiceNo,
    required String supplierId,
    required String branchId,
    required String purchaseOrderId,
    required String date, // DD/MM/YYYY
    required String mode,
    required double loadingCost,
    required double marketCess,
    required double bagsAndSticks,
    required double freight,
    required double grandTotal,
    required double outstandingAmount,
    required List<PurchaseInvoiceLine> lines,
  }) {
    return _submit(
      id: id,
      invoiceNo: invoiceNo,
      supplierId: supplierId,
      branchId: branchId,
      purchaseOrderId: purchaseOrderId,
      date: date,
      mode: mode,
      loadingCost: loadingCost,
      marketCess: marketCess,
      bagsAndSticks: bagsAndSticks,
      freight: freight,
      grandTotal: grandTotal,
      outstandingAmount: outstandingAmount,
      status: status,
      lines: lines,
    );
  }

  Future<bool> _submit({
    String? id,
    required String invoiceNo,
    required String supplierId,
    required String branchId,
    required String purchaseOrderId,
    required String date,
    required String mode,
    required double loadingCost,
    required double marketCess,
    required double bagsAndSticks,
    required double freight,
    required double grandTotal,
    required double outstandingAmount,
    required String status,
    required List<PurchaseInvoiceLine> lines,
  }) async {
    if (isSaving.value) return false;

    isSaving.value = true;

    try {
      final organizationId = await SharedPrefsHelper.getString(
        SharedPrefsHelper.organizationId,
      );

      final body = <String, dynamic>{
        'invoiceNo': invoiceNo,
        'organizationId': organizationId,
        'supplierId': supplierId,
        'branchId': branchId,
        if (purchaseOrderId.isNotEmpty) 'purchaseOrderId': purchaseOrderId,
        'invoiceDate': date,
        'mode': mode,
        'loadingCost': loadingCost,
        'marketCess': marketCess,
        'bagsAndSticks': bagsAndSticks,
        'freight': freight,
        'grandTotal': grandTotal,
        'outstandingAmount': outstandingAmount,
        'status': status,
        'lines': lines.map((line) => line.toJson()).toList(),
      };

      consolePrint(
        id == null
            ? 'PURCHASE INVOICE CREATE REQUEST'
            : 'PURCHASE INVOICE UPDATE REQUEST',
      );
      consolePrint('PURCHASE INVOICE NUMBER: $invoiceNo');

      final response = id == null
          ? await ApiService.post(EndPoints.purchaseInvoices, body)
          : await ApiService.put('${EndPoints.purchaseInvoices}/$id', body);

      consolePrint('PURCHASE INVOICE SAVE STATUS: ${response?.statusCode}');

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201)) {
        consolePrint('PURCHASE INVOICE SAVE SUCCESS');
        successToast(
          id == null
              ? 'Purchase invoice saved successfully.'
              : 'Purchase invoice updated.',
        );
        await loadPurchaseInvoices();
        return true;
      }

      final message = _extractMessage(response?.data);
      errorToast(
        message.isNotEmpty ? message : 'Unable to save purchase invoice.',
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // ============================================================
  // APPROVE / DELETE
  // ============================================================

  Future<bool> approvePurchaseInvoice(String id) async {
    if (isSaving.value) return false;
    isSaving.value = true;

    try {
      consolePrint('PURCHASE INVOICE APPROVE REQUEST: $id');

      final response = await ApiService.put(
        '${EndPoints.purchaseInvoices}/$id',
        <String, dynamic>{'status': 'Approved'},
      );

      consolePrint('PURCHASE INVOICE APPROVE STATUS: ${response?.statusCode}');

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201)) {
        successToast('Purchase invoice approved.');
        await loadPurchaseInvoices();
        return true;
      }

      final message = _extractMessage(response?.data);
      errorToast(
        message.isNotEmpty ? message : 'Unable to approve purchase invoice.',
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deletePurchaseInvoice(String id) async {
    consolePrint('PURCHASE INVOICE DELETE REQUEST: $id');

    final response = await ApiService.delete(
      '${EndPoints.purchaseInvoices}/$id',
    );

    consolePrint('PURCHASE INVOICE DELETE STATUS: ${response?.statusCode}');

    if (response != null && response.statusCode == 200) {
      successToast('Purchase invoice deleted.');
      await loadPurchaseInvoices();
      return true;
    }

    final message = _extractMessage(response?.data);
    errorToast(
      message.isNotEmpty ? message : 'Unable to delete purchase invoice.',
    );
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
