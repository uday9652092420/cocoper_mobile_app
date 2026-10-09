import 'package:get/get.dart';

import '../../helpers/flutter_toast.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/direct_sale.dart';
import '../../models/lookup_option.dart';
import '../../controllers/salesorders/sales_order_controller.dart';
import '../../services/api_service.dart';
import '../../services/endpoints.dart';

class DirectSalesController extends GetxController {
  final directSales = <DirectSale>[].obs;
  final customers = <LookupOption>[].obs;
  final branches = <LookupOption>[].obs;
  final items = <LookupOption>[].obs;
  final gunnyBagTypes = <DirectSaleBagType>[].obs;
  final customerNames = <String, String>{}.obs;
  final branchNames = <String, String>{}.obs;
  final searchQuery = ''.obs;
  final isLoadingList = false.obs;
  final hasListError = false.obs;
  final listError = ''.obs;
  final isLoadingLookups = false.obs;
  final hasLookupError = false.obs;
  final lookupError = ''.obs;
  final isSaving = false.obs;
  final actionInProgressId = ''.obs;

  Future<void> loadDirectSales() async {
    isLoadingList.value = true;
    hasListError.value = false;
    listError.value = '';

    final responses = await Future.wait([
      ApiService.get(EndPoints.directSales),
      ApiService.get(EndPoints.customers),
      ApiService.get(EndPoints.branches),
    ]);

    final salesResponse = responses[0];
    if (salesResponse?.statusCode != 200) {
      hasListError.value = true;
      listError.value = _extractError(
        salesResponse?.data,
        'Unable to load direct sales.',
      );
      isLoadingList.value = false;
      return;
    }

    final sales = _extractList(salesResponse?.data);
    if (sales == null) {
      hasListError.value = true;
      listError.value = 'Unable to read direct sales from the server.';
      isLoadingList.value = false;
      return;
    }

    directSales.assignAll(
      sales
          .whereType<Map<dynamic, dynamic>>()
          .map((row) => DirectSale.fromJson(Map<String, dynamic>.from(row))),
    );
    customerNames.assignAll(_lookupMap(responses[1]?.data));
    branchNames.assignAll(_lookupMap(responses[2]?.data));
    isLoadingList.value = false;
  }

  Future<void> loadCreateLookups() async {
    isLoadingLookups.value = true;
    hasLookupError.value = false;
    lookupError.value = '';

    final responses = await Future.wait([
      ApiService.get(EndPoints.customers),
      ApiService.get(EndPoints.branches),
      ApiService.get(EndPoints.items),
      ApiService.get(EndPoints.gunnyBags),
    ]);

    customers.assignAll(_lookupOptions(responses[0]?.data));
    branches.assignAll(_lookupOptions(responses[1]?.data));
    items.assignAll(_lookupOptions(responses[2]?.data));
    gunnyBagTypes.assignAll(_bagTypeOptions(responses[3]?.data));

    if (customers.isEmpty || branches.isEmpty || items.isEmpty) {
      hasLookupError.value = true;
      lookupError.value = 'Unable to load required sales lookups.';
    }
    isLoadingLookups.value = false;
  }

  Future<bool> createDirectSale({
    required String customerId,
    required String branchId,
    required String invoiceDate,
    required String mode,
    required List<DirectSaleLine> lines,
    required List<DirectSaleGunnyBag> gunnyBags,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;

    try {
      final organizationId = await SharedPrefsHelper.getString(
        SharedPrefsHelper.organizationId,
      );
      if (organizationId.trim().isEmpty) {
        errorToast(
            'Organization context is unavailable. Please sign in again.');
        return false;
      }

      final lineTotal = lines.fold<double>(
        0,
        (sum, line) => sum + line.salesAmount,
      );
      final bagTotal = gunnyBags.fold<double>(
        0,
        (sum, bag) => sum + bag.amount,
      );

      final body = <String, dynamic>{
        'directSaleNo': '',
        'salesOrderNo': '',
        'organizationId': organizationId,
        'customerId': customerId,
        'branchId': branchId,
        'invoiceDate': invoiceDate,
        'mode': mode,
        'invoiceTotal':
            SalesOrderController.roundValue(lineTotal + bagTotal, 2),
        'charges': <dynamic>[],
        'lines': lines.map((line) => line.toJson()).toList(),
        'gunnyBags': gunnyBags.map((bag) => bag.toJson()).toList(),
      };

      final response = await ApiService.post(EndPoints.directSales, body);
      if (_isSuccessful(response)) {
        successToast('Direct sale created successfully.');
        return true;
      }

      errorToast(
          _extractError(response?.data, 'Unable to create direct sale.'));
      return false;
    } catch (error) {
      errorToast('Unable to create direct sale. $error');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> approveSale(DirectSale sale) async {
    if (sale.id.isEmpty ||
        sale.approved != false ||
        actionInProgressId.value.isNotEmpty) {
      return false;
    }
    actionInProgressId.value = sale.id;
    try {
      final response = await ApiService.post(
        '${EndPoints.directSales}/${sale.id}/approve',
        null,
      );
      if (_isSuccessful(response)) {
        successToast('Direct sale approved.');
        await loadDirectSales();
        return true;
      }
      errorToast(
          _extractError(response?.data, 'Unable to approve direct sale.'));
      return false;
    } finally {
      actionInProgressId.value = '';
    }
  }

  Future<bool> deleteSale(DirectSale sale) async {
    if (sale.id.isEmpty ||
        sale.approved != false ||
        actionInProgressId.value.isNotEmpty) {
      return false;
    }
    actionInProgressId.value = sale.id;
    try {
      final response = await ApiService.delete(
        '${EndPoints.directSales}/${sale.id}',
      );
      if (_isSuccessful(response)) {
        successToast('Direct sale deleted.');
        await loadDirectSales();
        return true;
      }
      errorToast(
          _extractError(response?.data, 'Unable to delete direct sale.'));
      return false;
    } finally {
      actionInProgressId.value = '';
    }
  }

  List<DirectSale> get filteredSales {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return directSales;

    return directSales.where((sale) {
      return sale.directSaleNo.toLowerCase().contains(query) ||
          customerName(sale).toLowerCase().contains(query) ||
          branchName(sale).toLowerCase().contains(query) ||
          sale.mode.toLowerCase().contains(query);
    }).toList();
  }

  String customerName(DirectSale sale) {
    return customerNames[sale.customerId] ??
        (sale.customerName.isEmpty ? sale.customerId : sale.customerName);
  }

  String branchName(DirectSale sale) {
    return branchNames[sale.branchId] ??
        (sale.branchName.isEmpty ? sale.branchId : sale.branchName);
  }

  List<dynamic>? _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final rows = data['data'];
      if (rows is List) return rows;
    }
    return null;
  }

  Map<String, String> _lookupMap(dynamic data) {
    final rows = _extractList(data);
    if (rows == null) return const {};

    final names = <String, String>{};
    for (final row in rows) {
      final option = LookupOption.fromDynamic(row);
      if (option.id.isNotEmpty && option.label.isNotEmpty) {
        names[option.id] = option.label;
      }
    }
    return names;
  }

  List<LookupOption> _lookupOptions(dynamic data) {
    final rows = _extractList(data);
    if (rows == null) return const [];
    return rows
        .map(LookupOption.fromDynamic)
        .where((option) => option.id.isNotEmpty)
        .toList();
  }

  List<DirectSaleBagType> _bagTypeOptions(dynamic data) {
    final rows = _extractList(data);
    if (rows == null) return const [];
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => DirectSaleBagType.fromJson(
              Map<String, dynamic>.from(row),
            ))
        .where((option) => option.id.isNotEmpty)
        .toList();
  }

  bool _isSuccessful(dynamic response) {
    return response != null &&
        (response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 204) &&
        !(response.data is Map && response.data['success'] == false);
  }

  String _extractError(dynamic data, String fallback) {
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }
    }
    return fallback;
  }
}
