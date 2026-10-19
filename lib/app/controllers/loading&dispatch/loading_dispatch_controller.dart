import 'package:get/get.dart';

import '../../helpers/flutter_toast.dart';
import '../../models/bag_purchase.dart';
import '../../models/loading_dispatch.dart';
import '../../models/lookup_option.dart';
import '../../services/loading_dispatch_service.dart';

class LoadingDispatchController extends GetxController {
  LoadingDispatchController({
    LoadingDispatchService? service,
  }) : _service = service ?? LoadingDispatchService();

  final LoadingDispatchService _service;
  final dispatches = <LoadingDispatch>[].obs;
  final customers = <LookupOption>[].obs;
  final branches = <LookupOption>[].obs;
  final items = <LookupOption>[].obs;
  final gunnyBags = <BagPurchaseLookup>[].obs;
  final searchQuery = ''.obs;
  final detail = Rxn<LoadingDispatch>();
  final isLoadingList = false.obs;
  final isLoadingLookups = false.obs;
  final isLoadingDetail = false.obs;
  final isSaving = false.obs;
  final actionInProgressId = ''.obs;
  final hasListError = false.obs;
  final listError = ''.obs;
  final lookupError = ''.obs;
  final detailError = ''.obs;
  Future<void>? _listRequest;
  Future<void>? _lookupRequest;

  List<LoadingDispatch> get filteredDispatches {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return dispatches.toList(growable: false);
    return dispatches.where((dispatch) {
      return dispatch.dispatchNumber.toLowerCase().contains(query) ||
          customerName(dispatch.customerId).toLowerCase().contains(query) ||
          dispatch.lorryNumber.toLowerCase().contains(query) ||
          dispatch.driverName.toLowerCase().contains(query) ||
          dispatch.driverMobile.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  String customerName(String id) => _lookupName(customers, id);
  String branchName(String id) => _lookupName(branches, id);
  String itemName(String id) => _lookupName(items, id);
  String gunnyBagLabelForBharthi(String value) {
    for (final option in gunnyBags) {
      if (option.name == value) return option.label;
    }
    return value;
  }

  Future<void> loadDispatches({bool force = false}) async {
    final running = _listRequest;
    if (running != null) {
      if (!force) return running;
      await running;
    }
    final request = _performLoadDispatches();
    _listRequest = request;
    try {
      await request;
    } finally {
      if (identical(_listRequest, request)) _listRequest = null;
    }
  }

  Future<void> _performLoadDispatches() async {
    isLoadingList.value = true;
    hasListError.value = false;
    listError.value = '';
    try {
      dispatches.assignAll(await _service.fetchDispatches());
    } catch (error) {
      hasListError.value = true;
      listError.value = 'Unable to load dispatches: $error';
    } finally {
      isLoadingList.value = false;
    }
  }

  Future<void> refreshDispatches() => loadDispatches(force: true);

  Future<void> loadLookups() {
    final running = _lookupRequest;
    if (running != null) return running;
    final request = _performLoadLookups();
    _lookupRequest = request;
    return request.whenComplete(() {
      if (identical(_lookupRequest, request)) _lookupRequest = null;
    });
  }

  Future<void> _performLoadLookups() async {
    isLoadingLookups.value = true;
    lookupError.value = '';
    try {
      await Future.wait<void>([
        _service.fetchCustomers().then(customers.assignAll),
        _service.fetchBranches().then(branches.assignAll),
        _service.fetchItems().then(items.assignAll),
        _service.fetchGunnyBags().then(gunnyBags.assignAll),
      ]);
      final missing = <String>[
        if (customers.isEmpty) 'customers',
        if (branches.isEmpty) 'branches',
        if (items.isEmpty) 'items',
        if (gunnyBags.isEmpty)
          'the Gunny Bag master has no configured records for this '
              'organization',
      ];
      if (missing.isNotEmpty) {
        throw LoadingDispatchException(
          'No ${missing.join(', ')} are available for loading dispatch.',
        );
      }
    } catch (error) {
      lookupError.value = 'Unable to load dispatch options: $error';
    } finally {
      isLoadingLookups.value = false;
    }
  }

  Future<LoadingDispatch?> loadDispatchById(String id) async {
    detail.value = null;
    detailError.value = '';
    if (id.trim().isEmpty) {
      detailError.value = 'The dispatch ID is missing.';
      return null;
    }
    isLoadingDetail.value = true;
    try {
      final records = await _service.fetchDispatches();
      dispatches.assignAll(records);
      for (final dispatch in records) {
        if (dispatch.id == id) {
          detail.value = dispatch;
          return dispatch;
        }
      }
      detailError.value = 'Loading dispatch not found.';
      return null;
    } catch (error) {
      detailError.value = 'Unable to load dispatch: $error';
      return null;
    } finally {
      isLoadingDetail.value = false;
    }
  }

  Future<bool> saveDispatch(LoadingDispatch dispatch) async {
    if (isSaving.value) return false;
    final validationError = LoadingDispatchService.validate(dispatch);
    if (validationError != null) {
      await errorToast(validationError);
      return false;
    }
    isSaving.value = true;
    try {
      await _service.saveDispatch(dispatch);
      await refreshDispatches();
      if (hasListError.value) {
        await errorToast(
          'Dispatch saved, but the listing could not be refreshed: '
          '${listError.value}',
        );
      } else {
        await successToast(
          dispatch.id.isEmpty
              ? 'Dispatch saved as draft.'
              : 'Dispatch updated successfully.',
        );
      }
      return true;
    } catch (error) {
      await errorToast('Unable to save dispatch: $error');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteDispatch(LoadingDispatch dispatch) async {
    if (actionInProgressId.value.isNotEmpty) return false;
    actionInProgressId.value = dispatch.id;
    try {
      await _service.deleteDispatch(dispatch.id);
      await refreshDispatches();
      if (hasListError.value) {
        await errorToast(
          'Dispatch deleted, but the listing could not be refreshed: '
          '${listError.value}',
        );
      } else {
        await successToast('Dispatch deleted successfully.');
      }
      return true;
    } catch (error) {
      await errorToast('Unable to delete dispatch: $error');
      return false;
    } finally {
      actionInProgressId.value = '';
    }
  }

  static String _lookupName(List<LookupOption> options, String id) {
    for (final option in options) {
      if (option.id == id) return option.label;
    }
    return id;
  }
}
