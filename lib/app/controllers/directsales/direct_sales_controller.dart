import 'package:dio/dio.dart' show DioException, Response;
import 'package:get/get.dart' hide Response;

import '../../helpers/flutter_toast.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/direct_sale.dart';
import '../../models/lookup_option.dart';
import '../../models/sales_order.dart';
import '../../controllers/salesorders/sales_order_controller.dart';
import '../../services/api_service.dart';
import '../../services/endpoints.dart';

typedef DirectSalesOrderGetRequest = Future<Response<dynamic>?> Function(
  String endpoint, {
  Map<String, dynamic>? queryParameters,
  Map<String, String>? headers,
});

typedef DirectSalesCreateRequest = Future<Response<dynamic>?> Function(
  String endpoint,
  dynamic body,
);

class DirectSaleLineValues {
  final double discount;
  final double piecesPercentage;
  final double actualQuantity;
  final double salesAmount;

  const DirectSaleLineValues({
    required this.discount,
    required this.piecesPercentage,
    required this.actualQuantity,
    required this.salesAmount,
  });
}

class DirectSalesController extends GetxController {
  DirectSalesController({
    DirectSalesOrderGetRequest? salesOrderGetRequest,
    DirectSalesCreateRequest? directSalesCreateRequest,
  })  : _salesOrderGetRequest = salesOrderGetRequest,
        _directSalesCreateRequest = directSalesCreateRequest;

  final DirectSalesOrderGetRequest? _salesOrderGetRequest;
  final DirectSalesCreateRequest? _directSalesCreateRequest;
  final salesOrdersForCustomer = <SalesOrder>[].obs;
  final selectedSalesOrderDetails = Rxn<SalesOrder>();
  final isLoadingSalesOrders = false.obs;
  final isLoadingSalesOrderDetails = false.obs;
  final hasSalesOrdersError = false.obs;
  final salesOrdersError = ''.obs;
  final salesOrderDetailsError = ''.obs;
  final salesOrdersCustomerId = ''.obs;
  int _salesOrdersRequestVersion = 0;
  int _salesOrderDetailsRequestVersion = 0;
  String _activeSalesOrdersBranchId = '';
  final Map<String, List<SalesOrder>> _salesOrdersCache = {};

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
  final lastCreatedDirectSaleNo = ''.obs;

  static double? parsePiecesPercentage(String? value) {
    if (value == null || value.trim().isEmpty) return 0;
    final parsed = double.tryParse(value.trim());
    if (parsed == null || !parsed.isFinite) return null;
    return parsed.clamp(0, 100).toDouble();
  }

  static DirectSaleLineValues calculateLineValues({
    required String mode,
    required double quantity,
    required double discount,
    required double piecesPercentage,
    required bool piecesPercentageEnabled,
    required double salesPrice,
  }) {
    final safeQuantity = _finiteOrZero(quantity);
    final safeDiscount = _finiteOrZero(discount);
    final safeSalesPrice = _finiteOrZero(salesPrice);
    final percentageIsActive =
        mode == SalesOrderController.modeTonage && piecesPercentageEnabled;
    final effectivePercentage = percentageIsActive
        ? _finiteOrZero(piecesPercentage).clamp(0, 100).toDouble()
        : 0.0;
    final effectiveDiscount = percentageIsActive
        ? safeQuantity / 100 * effectivePercentage
        : safeDiscount;
    final safeEffectiveDiscount = _finiteOrZero(effectiveDiscount);
    final actualQuantity = percentageIsActive
        ? SalesOrderController.roundValue(
            safeQuantity - safeEffectiveDiscount,
            6,
          )
        : SalesOrderController.calculateActualQuantity(
            mode: mode,
            quantity: safeQuantity,
            discount: safeDiscount,
            piecesPercentage: 0,
          );

    return DirectSaleLineValues(
      discount: safeEffectiveDiscount,
      piecesPercentage: effectivePercentage,
      actualQuantity: actualQuantity,
      salesAmount: SalesOrderController.calculateSaleAmount(
        safeSalesPrice,
        actualQuantity,
      ),
    );
  }

  static double _finiteOrZero(double value) => value.isFinite ? value : 0;

  static double calculateInvoiceTotal({
    required double salesAmount,
    required double gunnyBagAmount,
    required double additionalCharges,
    required double loadingCharges,
  }) {
    final total = _finiteOrZero(salesAmount) +
        _finiteOrZero(gunnyBagAmount) +
        _finiteOrZero(additionalCharges) +
        _finiteOrZero(loadingCharges);
    return SalesOrderController.roundValue(total, 2);
  }

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

  Future<void> loadSalesOrdersForCustomer(
    String customerId, {
    String? branchId,
    bool forceRefresh = false,
  }) async {
    final normalizedCustomerId = customerId.trim();
    final normalizedBranchId = branchId?.trim() ?? '';

    if (normalizedCustomerId.isEmpty) {
      clearSalesOrdersForCustomer();
      return;
    }

    if (!forceRefresh &&
        salesOrdersCustomerId.value == normalizedCustomerId &&
        _activeSalesOrdersBranchId == normalizedBranchId &&
        isLoadingSalesOrders.value) {
      return;
    }
    final requestVersion = ++_salesOrdersRequestVersion;
    salesOrdersCustomerId.value = normalizedCustomerId;
    _activeSalesOrdersBranchId = normalizedBranchId;
    salesOrdersForCustomer.clear();
    hasSalesOrdersError.value = false;
    salesOrdersError.value = '';
    isLoadingSalesOrders.value = true;

    final organizationId = (await SharedPrefsHelper.getString(
      SharedPrefsHelper.organizationId,
    ))
        .trim();
    if (requestVersion != _salesOrdersRequestVersion) return;

    if (organizationId.isEmpty) {
      _setSalesOrdersError(
        requestVersion,
        'Organization context is unavailable. Please sign in again.',
      );
      return;
    }

    final cacheKey =
        '$organizationId|$normalizedBranchId|$normalizedCustomerId';
    final cachedOrders = _salesOrdersCache[cacheKey];
    if (!forceRefresh && cachedOrders != null) {
      salesOrdersForCustomer.assignAll(cachedOrders);
      isLoadingSalesOrders.value = false;
      return;
    }

    try {
      final response = await (_salesOrderGetRequest ?? ApiService.get)(
        EndPoints.salesOrders,
        headers: normalizedBranchId.isEmpty
            ? null
            : {'x-branch-id': normalizedBranchId},
      );
      if (requestVersion != _salesOrdersRequestVersion) return;

      if (response?.statusCode != 200) {
        final statusCode = response?.statusCode;
        final error = statusCode == 401
            ? 'Your session has expired. Please sign in again.'
            : _extractError(
                response?.data,
                statusCode == 403
                    ? 'You do not have permission to view Sales Orders.'
                    : 'Unable to load Sales Orders. Please try again.',
              );
        _setSalesOrdersError(requestVersion, error);
        return;
      }

      final rows = _extractList(response?.data);
      if (rows == null) {
        _setSalesOrdersError(
          requestVersion,
          'Unable to read Sales Orders from the server.',
        );
        return;
      }

      final orders = rows
          .whereType<Map<dynamic, dynamic>>()
          .map((row) => SalesOrder.fromJson(Map<String, dynamic>.from(row)))
          .where((order) =>
              order.customerId == normalizedCustomerId &&
              (order.organizationId.isEmpty ||
                  order.organizationId == organizationId))
          .toList();
      _salesOrdersCache[cacheKey] = orders;
      salesOrdersForCustomer.assignAll(orders);
    } on DioException catch (error) {
      if (requestVersion != _salesOrdersRequestVersion) return;
      final statusCode = error.response?.statusCode;
      _setSalesOrdersError(
        requestVersion,
        statusCode == 401
            ? 'Your session has expired. Please sign in again.'
            : _extractError(
                error.response?.data,
                'Unable to load Sales Orders. Check your connection and retry.',
              ),
      );
    } finally {
      if (requestVersion == _salesOrdersRequestVersion) {
        isLoadingSalesOrders.value = false;
      }
    }
  }

  void clearSalesOrdersForCustomer() {
    _salesOrdersRequestVersion++;
    salesOrdersCustomerId.value = '';
    _activeSalesOrdersBranchId = '';
    salesOrdersForCustomer.clear();
    isLoadingSalesOrders.value = false;
    hasSalesOrdersError.value = false;
    salesOrdersError.value = '';
    clearSelectedSalesOrderDetails();
  }

  Future<SalesOrder?> loadSalesOrderDetails({
    required String salesOrderId,
    required String customerId,
    String? branchId,
    bool forceRefresh = false,
  }) async {
    final id = salesOrderId.trim();
    final expectedCustomerId = customerId.trim();
    if (id.isEmpty || expectedCustomerId.isEmpty) {
      _setSalesOrderDetailsError(
        ++_salesOrderDetailsRequestVersion,
        'Select a valid Sales Order for the selected customer.',
      );
      return null;
    }

    final selectedOrder =
        salesOrdersForCustomer.where((order) => order.id == id).firstOrNull;
    if (selectedOrder == null ||
        selectedOrder.customerId != expectedCustomerId) {
      _setSalesOrderDetailsError(
        ++_salesOrderDetailsRequestVersion,
        'This Sales Order is not available for the selected customer.',
      );
      return null;
    }

    final existingDetails = selectedSalesOrderDetails.value;
    if (!forceRefresh &&
        existingDetails?.id == id &&
        existingDetails?.customerId == expectedCustomerId) {
      return existingDetails;
    }

    final requestVersion = ++_salesOrderDetailsRequestVersion;
    selectedSalesOrderDetails.value = null;
    salesOrderDetailsError.value = '';
    isLoadingSalesOrderDetails.value = true;

    try {
      final organizationId = (await SharedPrefsHelper.getString(
        SharedPrefsHelper.organizationId,
      ))
          .trim();
      if (requestVersion != _salesOrderDetailsRequestVersion) return null;
      if (organizationId.isEmpty) {
        _setSalesOrderDetailsError(
          requestVersion,
          'Organization context is unavailable. Please sign in again.',
        );
        return null;
      }

      final normalizedBranchId = branchId?.trim() ?? '';
      final response = await (_salesOrderGetRequest ?? ApiService.get)(
        '${EndPoints.salesOrders}/$id',
        headers: normalizedBranchId.isEmpty
            ? null
            : {'x-branch-id': normalizedBranchId},
      );
      if (requestVersion != _salesOrderDetailsRequestVersion) return null;

      if (response?.statusCode != 200 ||
          (response?.data is Map && response?.data['success'] == false)) {
        final statusCode = response?.statusCode;
        _setSalesOrderDetailsError(
          requestVersion,
          statusCode == 401
              ? 'Your session has expired. Please sign in again.'
              : _extractError(
                  response?.data,
                  statusCode == 403
                      ? 'You do not have permission to view this Sales Order.'
                      : statusCode == 404
                          ? 'The selected Sales Order could not be found.'
                          : 'Unable to load Sales Order details.',
                ),
        );
        return null;
      }

      final order = SalesOrder.fromApiResponse(response?.data);
      if (order == null || order.id != id) {
        _setSalesOrderDetailsError(
          requestVersion,
          'The server returned invalid Sales Order details.',
        );
        return null;
      }
      if (order.customerId != expectedCustomerId ||
          (order.organizationId.isNotEmpty &&
              order.organizationId != organizationId) ||
          (normalizedBranchId.isNotEmpty &&
              order.branchId.isNotEmpty &&
              order.branchId != normalizedBranchId)) {
        _setSalesOrderDetailsError(
          requestVersion,
          'The selected Sales Order does not belong to this customer, organization, or branch.',
        );
        return null;
      }
      if (order.lines.isEmpty ||
          order.lines.any(
            (line) =>
                line.itemId.isEmpty ||
                !line.quantity.isFinite ||
                line.quantity <= 0 ||
                !line.saleCost.isFinite ||
                line.saleCost < 0 ||
                !items.any((item) => item.id == line.itemId),
          )) {
        _setSalesOrderDetailsError(
          requestVersion,
          'The selected Sales Order has incomplete details or an unavailable item.',
        );
        return null;
      }

      selectedSalesOrderDetails.value = order;
      return order;
    } on DioException catch (error) {
      if (requestVersion != _salesOrderDetailsRequestVersion) return null;
      _setSalesOrderDetailsError(
        requestVersion,
        _extractError(
          error.response?.data,
          'Unable to load Sales Order details. Check your connection and retry.',
        ),
      );
      return null;
    } catch (error) {
      if (requestVersion != _salesOrderDetailsRequestVersion) return null;
      _setSalesOrderDetailsError(
        requestVersion,
        'Unable to read Sales Order details: $error',
      );
      return null;
    } finally {
      if (requestVersion == _salesOrderDetailsRequestVersion) {
        isLoadingSalesOrderDetails.value = false;
      }
    }
  }

  void clearSelectedSalesOrderDetails() {
    _salesOrderDetailsRequestVersion++;
    selectedSalesOrderDetails.value = null;
    isLoadingSalesOrderDetails.value = false;
    salesOrderDetailsError.value = '';
  }

  void _setSalesOrderDetailsError(int requestVersion, String message) {
    if (requestVersion != _salesOrderDetailsRequestVersion) return;
    selectedSalesOrderDetails.value = null;
    salesOrderDetailsError.value = message;
    isLoadingSalesOrderDetails.value = false;
  }

  void _setSalesOrdersError(int requestVersion, String message) {
    if (requestVersion != _salesOrdersRequestVersion) return;
    salesOrdersForCustomer.clear();
    hasSalesOrdersError.value = true;
    salesOrdersError.value = message;
    isLoadingSalesOrders.value = false;
  }

  Future<bool> createDirectSale({
    required String customerId,
    required String branchId,
    required String invoiceDate,
    required String mode,
    required List<DirectSaleLine> lines,
    required List<DirectSaleGunnyBag> gunnyBags,
    required double additionalCharges,
    required double loadingCharges,
    String salesOrderNo = '',
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    if (lastCreatedDirectSaleNo.value.trim().isEmpty) {
      lastCreatedDirectSaleNo.value = await generateDirectSaleNumber();
    }

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
        'salesOrderNo': salesOrderNo.trim(),
        'organizationId': organizationId,
        'customerId': customerId,
        'branchId': branchId,
        'invoiceDate': invoiceDate,
        'mode': mode,
        'invoiceTotal': calculateInvoiceTotal(
          salesAmount: lineTotal,
          gunnyBagAmount: bagTotal,
          additionalCharges: additionalCharges,
          loadingCharges: loadingCharges,
        ),
        'charges': <dynamic>[],
        'lines': lines.map((line) => line.toJson()).toList(),
        'gunnyBags': gunnyBags.map((bag) => bag.toJson()).toList(),
      };

      final response = await (_directSalesCreateRequest ??
          (endpoint, payload) => ApiService.post(endpoint, payload))(
        EndPoints.directSales,
        body,
      );
      if (_isSuccessful(response)) {
        lastCreatedDirectSaleNo.value = _extractDirectSaleNo(response?.data);
        final saleNo = lastCreatedDirectSaleNo.value;
        successToast(saleNo.isEmpty
            ? 'Direct sale created successfully.'
            : 'Direct sale $saleNo created successfully.');
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

  Future<String> generateDirectSaleNumber() async {
    if (directSales.isEmpty) {
      final response = await ApiService.get(EndPoints.directSales);
      if (response?.statusCode == 200) {
        final sales = _extractList(response?.data);
        if (sales != null) {
          directSales.assignAll(
            sales.whereType<Map<dynamic, dynamic>>().map(
                (row) => DirectSale.fromJson(Map<String, dynamic>.from(row))),
          );
        }
      }
    }

    final organizationName = await SharedPrefsHelper.getString(
      SharedPrefsHelper.organizationName,
    );

    final initial = organizationName.trim().isNotEmpty
        ? organizationName.trim()[0].toUpperCase()
        : 'D';

    final prefix = '${initial}DSO-';
    var maxNumber = 0;

    for (final sale in directSales) {
      final number = sale.directSaleNo.toUpperCase();
      if (number.startsWith(prefix)) {
        final parsed = int.tryParse(number.substring(prefix.length));
        if (parsed != null && parsed > maxNumber) {
          maxNumber = parsed;
        }
      }
    }

    return '$prefix${(maxNumber + 1).toString().padLeft(2, '0')}';
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

  String _extractDirectSaleNo(dynamic data) {
    if (data is! Map) return '';

    final saleNo = data['directSaleNo']?.toString().trim() ?? '';
    if (saleNo.isNotEmpty) return saleNo;

    return _extractDirectSaleNo(data['data']);
  }
}
