import 'package:get/get.dart';

import '../../helpers/console_print.dart';
import '../../models/purchase_invoice.dart';
import '../../services/api_service.dart';
import '../../services/endpoints.dart';

/// Loads and filters the Saved Purchase Invoices list.
class PurchaseInvoiceController extends GetxController {
  final purchaseInvoices = <PurchaseInvoice>[].obs;
  final isLoadingList = false.obs;
  final hasListError = false.obs;

  final searchQuery = ''.obs;

  Future<void> loadPurchaseInvoices() async {
    isLoadingList.value = true;
    hasListError.value = false;

    consolePrint('PURCHASE INVOICE LIST REQUEST');

    final response = await ApiService.get(EndPoints.purchaseInvoices);

    consolePrint('PURCHASE INVOICE LIST STATUS: ${response?.statusCode}');

    if (response?.statusCode == 200) {
      final data = _extractList(response?.data);
      if (data != null) {
        purchaseInvoices.value = data
            .whereType<Map<String, dynamic>>()
            .map(PurchaseInvoice.fromJson)
            .toList();
      } else {
        hasListError.value = true;
      }
    } else {
      hasListError.value = true;
    }

    isLoadingList.value = false;
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
}
