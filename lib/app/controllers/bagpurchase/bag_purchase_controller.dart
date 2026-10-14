import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../config/environment.dart';
import '../../helpers/flutter_toast.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/bag_purchase.dart';
import '../../services/api_service.dart';
import '../../services/endpoints.dart';

class BagPurchaseController extends GetxController {
  final purchases = <BagPurchase>[].obs;
  final suppliers = <BagPurchaseLookup>[].obs;
  final branches = <BagPurchaseLookup>[].obs;
  final gunnyBags = <BagPurchaseLookup>[].obs;
  final isLoadingList = false.obs;
  final hasListError = false.obs;
  final listError = ''.obs;
  final isLoadingLookups = false.obs;
  final lookupError = ''.obs;
  final isSaving = false.obs;
  final deletingId = ''.obs;
  final searchQuery = ''.obs;
  final detail = Rxn<BagPurchase>();
  final isLoadingDetail = false.obs;
  final detailError = ''.obs;
  bool _reloadAfterCurrentLoad = false;

  List<BagPurchase> get filteredPurchases {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return purchases;

    return purchases.where((purchase) {
      return purchase.purchaseNumber.toLowerCase().contains(query) ||
          purchase.supplierName.toLowerCase().contains(query) ||
          purchase.supplierCode.toLowerCase().contains(query) ||
          purchase.supplierId.toLowerCase().contains(query) ||
          purchase.remarks.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  /// Loads the organization's saved bag purchases.
  ///
  /// The verified list contract is organization-scoped: the web client sends
  /// only the organization/auth headers and receives every bag purchase of the
  /// organization. The backend also narrows the list by `branchId` /
  /// `x-branch-id`, but a branch without bag purchases answers with
  /// `{success: true, data: []}` and HTTP 200, which is indistinguishable from
  /// an empty organization, so a branch-scoped list showed existing purchases
  /// as "0 purchases". Create, update, and delete still send the session branch.
  Future<void> loadPurchases() async {
    if (isLoadingList.value) {
      _reloadAfterCurrentLoad = true;
      return;
    }
    isLoadingList.value = true;
    hasListError.value = false;
    listError.value = '';

    try {
      final organizationId = await SharedPrefsHelper.getString(
        SharedPrefsHelper.organizationId,
      );
      if (organizationId.trim().isEmpty) {
        throw const _BagPurchaseRequestException(
          'Organization scope is unavailable. Please sign in again.',
        );
      }

      purchases.assignAll(await fetchPurchaseList(organizationId));
    } catch (error) {
      hasListError.value = true;
      listError.value =
          _exceptionMessage(error, 'Unable to load bag purchases.');
    } finally {
      isLoadingList.value = false;
      if (_reloadAfterCurrentLoad) {
        _reloadAfterCurrentLoad = false;
        await loadPurchases();
      }
    }
  }

  /// Requests the saved list. Overridable in tests to supply canned responses.
  @visibleForTesting
  Future<List<BagPurchase>> fetchPurchaseList(String organizationId) async {
    final response = await ApiService.get(
      EndPoints.bagPurchases,
      queryParameters: purchaseListQueryParameters(organizationId),
      headers: purchaseListHeaders(organizationId),
    );
    if (response?.statusCode != 200) {
      throw _BagPurchaseRequestException(
        _responseMessage(response?.data) ??
            'Unable to load bag purchases${_statusSuffix(response?.statusCode)}.',
      );
    }

    return decodePurchaseList(response?.data);
  }

  /// Organization scope of the saved list. No branch scope is sent: the
  /// verified web client lists every bag purchase of the organization, and the
  /// backend silently returns an empty array for a branch without purchases.
  @visibleForTesting
  static Map<String, dynamic> purchaseListQueryParameters(
    String organizationId,
  ) =>
      {'organizationId': organizationId};

  @visibleForTesting
  static Map<String, String> purchaseListHeaders(String organizationId) =>
      {'x-organization-id': organizationId};

  /// Loads supplier, branch, and gunny bag selectors.
  ///
  /// All three are organization-level master data. The working Direct Sales
  /// lookups fetch them without a branch header, so Bag Purchase does the same
  /// rather than scoping the gunny bag read by the selected branch. The branch
  /// argument is kept for call-site compatibility and only resolves scope.
  Future<void> loadLookups({String branchId = ''}) async {
    if (isLoadingLookups.value) return;

    isLoadingLookups.value = true;
    lookupError.value = '';

    try {
      await _readScope();

      final responses = await Future.wait([
        ApiService.get(EndPoints.suppliers),
        ApiService.get(EndPoints.branches),
        ApiService.get(EndPoints.gunnyBags),
      ]);

      final parsedSuppliers = _decodeLookupList(
        responses[0]?.data,
        nameKeys: const ['supplier_name', 'name', 'supplierName'],
        codeKeys: const ['supplier_code', 'code', 'supplierCode'],
      );
      final parsedBranches = _decodeLookupList(
        responses[1]?.data,
        nameKeys: const ['branch_name', 'name', 'branchName'],
        codeKeys: const ['branch_code', 'code', 'branchCode'],
      );
      if (responses[0]?.statusCode == 200) {
        suppliers.assignAll(parsedSuppliers);
      }
      if (responses[1]?.statusCode == 200) {
        branches.assignAll(parsedBranches);
      }

      final bagResponse = responses[2];
      _logBagLookupResponse(bagResponse?.statusCode, bagResponse?.data);
      final parsedBags = bagResponse?.statusCode == 200
          ? BagPurchaseLookup.decodeGunnyBagResponse(bagResponse?.data)
          : null;
      if (parsedBags != null) {
        gunnyBags.assignAll(parsedBags);
      }

      final failures = <String>[
        if (responses[0]?.statusCode != 200 || parsedSuppliers.isEmpty)
          _lookupFailure(
            'suppliers',
            responses[0]?.statusCode,
            responses[0]?.data,
          ),
        if (responses[1]?.statusCode != 200 || parsedBranches.isEmpty)
          _lookupFailure(
            'branches',
            responses[1]?.statusCode,
            responses[1]?.data,
          ),
        if (bagResponse?.statusCode != 200)
          _lookupFailure(
            'gunny bags',
            bagResponse?.statusCode,
            bagResponse?.data,
          )
        else if (parsedBags == null)
          'Gunny bag lookup returned an unsupported response format.'
        else if (parsedBags.isEmpty)
          'No gunny bags are available for this organization.',
      ];
      lookupError.value = failures.join(' ');
    } catch (error) {
      lookupError.value = _exceptionMessage(
        error,
        'Unable to load bag purchase options.',
      );
      if (!Environment.isProduction) {
        developer.log(
          'Bag purchase lookup failed before a complete response '
          '(${error.runtimeType}).',
          name: 'BagPurchaseController',
          level: 1000,
        );
      }
    } finally {
      isLoadingLookups.value = false;
    }
  }

  static String _lookupFailure(String name, int? statusCode, Object? data) {
    if (statusCode == null) {
      return 'The $name request did not receive an HTTP response.';
    }
    final message = _responseMessage(data);
    return message == null
        ? 'The $name request failed (HTTP $statusCode).'
        : 'The $name request failed (HTTP $statusCode): $message';
  }

  static void _logBagLookupResponse(int? statusCode, Object? data) {
    final topLevelKeys = data is Map<dynamic, dynamic>
        ? data.keys.map((key) => key.toString()).toList(growable: false)
        : const <String>[];
    if (!Environment.isProduction) {
      developer.log(
        'GET ${EndPoints.gunnyBags}: status=${statusCode ?? 'none'}, '
        'responseType=${data.runtimeType}, topLevelKeys=$topLevelKeys',
        name: 'BagPurchaseController',
      );
    }
  }

  Future<BagPurchase?> loadPurchase(
    String id, {
    String? branchId,
  }) async {
    isLoadingDetail.value = true;
    detailError.value = '';
    detail.value = null;
    try {
      final scope = await _readScope(branchOverride: branchId);
      final response = await ApiService.get(
        EndPoints.bagPurchase(id),
        queryParameters: {'organizationId': scope.organizationId},
        headers: _scopeHeaders(scope.organizationId, scope.branchId),
      );
      if (response?.statusCode != 200) {
        throw _BagPurchaseRequestException(
          _responseMessage(response?.data) ??
              'Unable to load bag purchase${_statusSuffix(response?.statusCode)}.',
        );
      }
      final purchase = BagPurchase.fromJson(_decodeObject(response?.data));
      if (purchase.id.isEmpty) {
        throw const _BagPurchaseRequestException(
          'The server response did not contain a bag purchase record.',
        );
      }
      detail.value = purchase;
      return purchase;
    } catch (error) {
      detailError.value =
          _exceptionMessage(error, 'Unable to load bag purchase.');
      return null;
    } finally {
      isLoadingDetail.value = false;
    }
  }

  Future<bool> createPurchase({
    required String date,
    required String supplierId,
    required String branchId,
    required String remarks,
    required List<BagPurchaseLine> lines,
    bool saveAndNew = false,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      final scope = await _readScope(branchOverride: branchId);
      final body = _requestBody(
        organizationId: scope.organizationId,
        branchId: branchId,
        date: date,
        supplierId: supplierId,
        remarks: remarks,
        lines: lines,
      );
      final response = await ApiService.post(
        EndPoints.bagPurchases,
        body,
        headers: _scopeHeaders(scope.organizationId, branchId),
      );
      if (!_isSuccess(response?.statusCode)) {
        errorToast(
          _responseMessage(response?.data) ??
              'Unable to save bag purchase${_statusSuffix(response?.statusCode)}.',
        );
        return false;
      }
      successToast(
        saveAndNew
            ? 'Bag purchase saved. You can enter another purchase.'
            : 'Bag purchase saved successfully.',
      );
      return true;
    } catch (error) {
      errorToast(_exceptionMessage(error, 'Unable to save bag purchase.'));
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> updatePurchase({
    required String id,
    required String date,
    required String supplierId,
    required String branchId,
    required String remarks,
    required List<BagPurchaseLine> lines,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      final scope = await _readScope(branchOverride: branchId);
      final response = await ApiService.put(
        EndPoints.bagPurchase(id),
        _requestBody(
          organizationId: scope.organizationId,
          branchId: branchId,
          date: date,
          supplierId: supplierId,
          remarks: remarks,
          lines: lines,
        ),
        headers: _scopeHeaders(scope.organizationId, branchId),
      );
      if (!_isSuccess(response?.statusCode)) {
        errorToast(
          _responseMessage(response?.data) ??
              'Unable to update bag purchase${_statusSuffix(response?.statusCode)}.',
        );
        return false;
      }
      successToast('Bag purchase updated successfully.');
      return true;
    } catch (error) {
      errorToast(_exceptionMessage(error, 'Unable to update bag purchase.'));
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deletePurchase(BagPurchase purchase) async {
    if (purchase.id.isEmpty) {
      errorToast('Cannot delete a bag purchase without a record ID.');
      return false;
    }
    if (deletingId.value.isNotEmpty) return false;
    deletingId.value = purchase.id;
    try {
      final scope = await _readScope(
        branchOverride: purchase.branchId.isEmpty ? null : purchase.branchId,
      );
      final response = await ApiService.delete(
        EndPoints.bagPurchase(purchase.id),
        headers: _scopeHeaders(scope.organizationId, scope.branchId),
      );
      if (!_isSuccess(response?.statusCode)) {
        errorToast(
          _responseMessage(response?.data) ??
              'Unable to delete bag purchase${_statusSuffix(response?.statusCode)}.',
        );
        return false;
      }
      successToast('Bag purchase deleted successfully.');
      await loadPurchases();
      return true;
    } catch (error) {
      errorToast(_exceptionMessage(error, 'Unable to delete bag purchase.'));
      return false;
    } finally {
      deletingId.value = '';
    }
  }

  Future<_BagPurchaseScope> _readScope({String? branchOverride}) async {
    final organizationId = await SharedPrefsHelper.getString(
      SharedPrefsHelper.organizationId,
    );
    final selectedBranch = branchOverride ??
        await SharedPrefsHelper.getString(SharedPrefsHelper.selectedBranchId);
    if (organizationId.trim().isEmpty) {
      throw const _BagPurchaseRequestException(
        'Organization scope is unavailable. Please sign in again.',
      );
    }
    return _BagPurchaseScope(organizationId, selectedBranch);
  }

  static Map<String, String> _scopeHeaders(
    String organizationId,
    String branchId,
  ) =>
      {
        'x-organization-id': organizationId,
        if (branchId.isNotEmpty) 'x-branch-id': branchId,
      };

  static Map<String, dynamic> _requestBody({
    required String organizationId,
    required String branchId,
    required String date,
    required String supplierId,
    required String remarks,
    required List<BagPurchaseLine> lines,
  }) =>
      {
        'purchase_date': date,
        'supplier_id': supplierId,
        'remarks': remarks,
        'organization_id': organizationId,
        'branch_id': branchId,
        'lines': lines.map((line) => line.toRequestJson()).toList(),
      };

  /// Decodes the verified saved-list envelope (`{success, data: [...]}`) and
  /// also accepts the bare-array and `items`/`records` wrappers.
  static List<BagPurchase> decodePurchaseList(Object? data) {
    Object? value = data;
    for (var depth = 0; depth < 3 && value is Map<dynamic, dynamic>; depth++) {
      value = value['data'] ?? value['items'] ?? value['records'];
    }
    if (value is! List) {
      throw const _BagPurchaseRequestException(
        'The server returned an invalid bag purchase list.',
      );
    }
    return value
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => BagPurchase.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static Map<String, dynamic> _decodeObject(Object? data) {
    Object? value = data;
    for (var depth = 0; depth < 3 && value is Map<dynamic, dynamic>; depth++) {
      final next = value['data'] ?? value['item'] ?? value['record'];
      if (next == null) break;
      value = next;
    }
    if (value is List && value.isNotEmpty) value = value.first;
    if (value is Map<dynamic, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    throw const _BagPurchaseRequestException(
      'The server returned an invalid bag purchase record.',
    );
  }

  static List<BagPurchaseLookup> _decodeLookupList(
    Object? data, {
    required List<String> nameKeys,
    required List<String> codeKeys,
    bool includeRate = false,
  }) {
    Object? value = data;
    for (var depth = 0; depth < 3 && value is Map<dynamic, dynamic>; depth++) {
      value = value['data'] ?? value['items'] ?? value['records'];
    }
    if (value is! List) return const [];

    return value
        .whereType<Map<dynamic, dynamic>>()
        .map((row) {
          final json = Map<String, dynamic>.from(row);
          String firstValue(List<String> keys) {
            for (final key in keys) {
              final item = json[key]?.toString().trim() ?? '';
              if (item.isNotEmpty) return item;
            }
            return '';
          }

          final id = firstValue(const ['id', '_id']);
          final name = firstValue(nameKeys);
          return BagPurchaseLookup(
            id: id,
            name: name.isEmpty ? id : name,
            code: firstValue(codeKeys),
            ratePerBag: includeRate
                ? BagPurchase.parseNumber(
                    json['rate_per_bag'] ?? json['ratePerBag'],
                  )
                : 0,
          );
        })
        .where((option) => option.id.isNotEmpty)
        .toList(growable: false);
  }

  static bool _isSuccess(int? status) =>
      status != null && status >= 200 && status < 300;

  static String? _responseMessage(Object? data) {
    if (data is! Map<dynamic, dynamic>) return null;
    final message = data['message'] ??
        data['error'] ??
        data['ErrorMessage'] ??
        data['detail'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
    if (message is List && message.isNotEmpty) {
      return message.map((item) => item.toString()).join('\n');
    }
    return null;
  }

  static String _exceptionMessage(Object error, String fallback) {
    if (error is _BagPurchaseRequestException) return error.message;
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? fallback : text;
  }

  static String _statusSuffix(int? status) =>
      status == null ? '' : ' (HTTP $status)';
}

class _BagPurchaseScope {
  const _BagPurchaseScope(this.organizationId, this.branchId);

  final String organizationId;
  final String branchId;
}

class _BagPurchaseRequestException implements Exception {
  const _BagPurchaseRequestException(this.message);

  final String message;
}
