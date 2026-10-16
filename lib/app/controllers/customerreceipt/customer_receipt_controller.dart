import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../helpers/flutter_toast.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/customer_receipt.dart';
import '../../models/lookup_option.dart';
import '../../services/api_service.dart';
import '../../services/endpoints.dart';

class CustomerReceiptController extends GetxController {
  final receipts = <CustomerReceipt>[].obs;
  final customers = <LookupOption>[].obs;
  final approvedInvoices = <CustomerReceiptInvoice>[].obs;
  final searchQuery = ''.obs;
  final isLoadingList = false.obs;
  final isLoadingForm = false.obs;
  final isSaving = false.obs;
  final hasListError = false.obs;
  final listError = ''.obs;
  final lookupError = ''.obs;
  Future<void>? _listRequest;
  bool _hasLoadedReceipts = false;

  Future<void> loadCustomers() async {
    try {
      final response = await ApiService.get(EndPoints.customers);
      final rows = _extractList(response?.data);
      if (response?.statusCode != 200 || rows == null) {
        lookupError.value =
            _message(response?.data, 'Unable to load customers.');
        return;
      }
      customers.assignAll(
        rows
            .map(LookupOption.fromDynamic)
            .where((option) => option.id.isNotEmpty),
      );
      lookupError.value = '';
    } catch (error) {
      lookupError.value = 'Unable to load customers: $error';
    }
  }

  List<CustomerReceipt> get filteredReceipts {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return receipts.toList();
    return receipts.where((receipt) {
      final customer = customerName(receipt.customerId).toLowerCase();
      return receipt.receiptNumber.toLowerCase().contains(query) ||
          customer.contains(query) ||
          receipt.invoiceNumber.toLowerCase().contains(query) ||
          receipt.remarks.toLowerCase().contains(query);
    }).toList();
  }

  String customerName(String id) {
    for (final customer in customers) {
      if (customer.id == id) return customer.label;
    }
    return id;
  }

  Future<void> loadCustomerReceipts() {
    final runningRequest = _listRequest;
    if (runningRequest != null) return runningRequest;
    final request = _performLoadCustomerReceipts();
    _listRequest = request;
    return request.whenComplete(() {
      if (identical(_listRequest, request)) _listRequest = null;
    });
  }

  Future<void> _performLoadCustomerReceipts() async {
    isLoadingList.value = true;
    hasListError.value = false;
    listError.value = '';
    try {
      final response = await ApiService.get(EndPoints.customerReceipts);
      final rows = _extractList(response?.data);
      if (response?.statusCode != 200 || rows == null) {
        hasListError.value = true;
        listError.value = _message(
          response?.data,
          'Unable to load customer receipts.',
        );
        return;
      }
      receipts.assignAll(
        rows
            .whereType<Map<dynamic, dynamic>>()
            .map((row) => CustomerReceipt.fromJson(
                  Map<String, dynamic>.from(row),
                )),
      );
      _hasLoadedReceipts = true;
    } catch (error) {
      hasListError.value = true;
      listError.value = 'Unable to load customer receipts: $error';
    } finally {
      isLoadingList.value = false;
    }
  }

  Future<void> loadFormLookups() async {
    if (isLoadingForm.value) return;
    isLoadingForm.value = true;
    lookupError.value = '';
    try {
      await loadCustomers();
      if (lookupError.value.isNotEmpty) return;

      final salesResponse = await ApiService.get(EndPoints.directSales);
      final salesRows = _extractList(salesResponse?.data);
      if (salesResponse?.statusCode != 200 || salesRows == null) {
        lookupError.value = _message(
          salesResponse?.data,
          'Unable to load approved invoices.',
        );
        return;
      }
      approvedInvoices.assignAll(
        salesRows
            .whereType<Map<dynamic, dynamic>>()
            .map((row) => Map<String, dynamic>.from(row))
            .where(_isApprovedSale)
            .map(CustomerReceiptInvoice.fromSaleJson)
            .where((invoice) => invoice.number.isNotEmpty),
      );
      if (!_hasLoadedReceipts || hasListError.value) {
        await loadCustomerReceipts();
      }
      if (hasListError.value) {
        lookupError.value = listError.value.isNotEmpty
            ? listError.value
            : 'Unable to load receipts.';
      }
    } catch (error) {
      lookupError.value = 'Unable to load receipt form options: $error';
    } finally {
      isLoadingForm.value = false;
    }
  }

  Future<String?> generateReceiptNumber() async {
    try {
      final response =
          await ApiService.get(EndPoints.nextCustomerReceiptNumber);
      if (response?.statusCode != 200) {
        errorToast(
          _message(response?.data, 'Unable to generate receipt number.'),
        );
        return null;
      }
      final number = parseReceiptNumberResponse(response?.data);
      if (number != null) return number;
      if (response?.data is Map && response?.data['success'] == false) {
        errorToast(
            _message(response?.data, 'Unable to generate receipt number.'));
      } else {
        errorToast('Unable to read the allocated receipt number.');
      }
    } catch (error) {
      errorToast('Unable to generate receipt number: $error');
    }
    return null;
  }

  static String? parseReceiptNumberResponse(dynamic data) {
    if (data is! Map || data['success'] != true) return null;
    final payload = data['data'];
    final value = payload is String
        ? payload
        : payload is Map
            ? payload['receipt_no']
            : null;
    final number = value?.toString().trim() ?? '';
    return number.isEmpty ? null : number;
  }

  Future<CustomerReceipt?> fetchReceipt(String id) async {
    await loadCustomerReceipts();
    if (hasListError.value) return null;
    for (final receipt in receipts) {
      if (receipt.id == id) return receipt;
    }
    return null;
  }

  Future<String> getReceiptOrganizationId() => SharedPrefsHelper.getString(
        SharedPrefsHelper.organizationId,
      );

  Future<Response<dynamic>?> createCustomerReceiptRequest(
    Map<String, dynamic> body,
  ) =>
      ApiService.post(EndPoints.customerReceipts, body);

  Future<Response<dynamic>?> updateCustomerReceiptRequest(
    String id,
    Map<String, dynamic> body,
  ) =>
      ApiService.put(EndPoints.customerReceipt(id), body);

  void showReceiptSaveError(String message) => errorToast(message);

  void showReceiptSaveSuccess(bool isEdit) => successToast(
        isEdit
            ? 'Customer receipt updated successfully.'
            : 'Customer receipt saved successfully.',
      );

  Future<bool> saveReceipt(
    CustomerReceipt receipt, {
    required bool isEdit,
    List<CustomerReceiptAttachment> attachments = const [],
  }) async {
    if (isSaving.value) return false;
    final validationError = validate(receipt);
    if (validationError != null) {
    showReceiptSaveError(validationError);
      return false;
    }
    isSaving.value = true;
    try {
      CustomerReceipt? latest;
      if (isEdit) {
        if (receipt.id.isEmpty) {
          showReceiptSaveError(
            'The receipt ID is missing; changes cannot be saved.',
          );
          return false;
        }
        latest = await fetchReceipt(receipt.id);
        if (latest == null) {
          showReceiptSaveError(
            hasListError.value
                ? 'Unable to verify the latest receipt.'
                : 'This receipt is no longer available.',
          );
          return false;
        }
        if (latest.status.trim().toLowerCase() != 'draft') {
          showReceiptSaveError('Only a Draft receipt can be edited.');
          return false;
        }
        if (attachments.isEmpty && !latest.hasAttachmentFields) {
          showReceiptSaveError(
            'The receipt API does not return existing attachments. Select '
            'replacement attachment(s) before saving to avoid clearing files.',
          );
          return false;
        }
      }

      final organizationId = await getReceiptOrganizationId();
      if (organizationId.isEmpty) {
        showReceiptSaveError(
          'Organization is not available. Please sign in again.',
        );
        return false;
      }

      final namesJson = attachments.isEmpty
          ? latest?.attachmentNamesJson
          : jsonEncode(
              attachments.map((attachment) => attachment.name).toList());
      final filesJson = attachments.isEmpty
          ? latest?.attachmentFilesJson
          : jsonEncode(
              attachments.map((attachment) => attachment.dataUrl).toList());
      final body = receipt.toRequestJson(
        organizationId: organizationId,
        attachmentNamesJson: namesJson,
        attachmentFilesJson: filesJson,
      );
      final response = isEdit
          ? await updateCustomerReceiptRequest(receipt.id, body)
          : await createCustomerReceiptRequest(body);
      if (!_isSuccessful(response)) {
        showReceiptSaveError(_message(
          response?.data,
          isEdit
              ? 'Unable to update customer receipt.'
              : 'Unable to save customer receipt.',
        ));
        return false;
      }
      await loadCustomerReceipts();
      showReceiptSaveSuccess(isEdit);
      return true;
    } catch (error) {
      showReceiptSaveError(
        'Unable to ${isEdit ? 'update' : 'save'} customer receipt: $error',
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteReceipt(CustomerReceipt receipt) async {
    if (isSaving.value) return false;
    if (receipt.id.isEmpty || receipt.status.trim().toLowerCase() != 'draft') {
      errorToast('Only a Draft receipt can be deleted.');
      return false;
    }
    isSaving.value = true;
    try {
      final latest = await fetchReceipt(receipt.id);
      if (latest == null || latest.status.trim().toLowerCase() != 'draft') {
        errorToast('This receipt is no longer an editable Draft.');
        return false;
      }
      final response = await ApiService.delete(
        EndPoints.customerReceipt(receipt.id),
      );
      if (!_isSuccessful(response)) {
        errorToast(
            _message(response?.data, 'Unable to delete customer receipt.'));
        return false;
      }
      await loadCustomerReceipts();
      successToast('Customer receipt deleted successfully.');
      return true;
    } catch (error) {
      errorToast('Unable to delete customer receipt: $error');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> approveReceipt(CustomerReceipt receipt) async {
    if (isSaving.value ||
        receipt.id.isEmpty ||
        receipt.status.trim().toLowerCase() != 'draft') {
      return false;
    }
    isSaving.value = true;
    try {
      final latest = await fetchReceipt(receipt.id);
      if (latest == null) {
        errorToast(
          hasListError.value
              ? 'Unable to verify the latest receipt.'
              : 'This receipt is no longer available.',
        );
        return false;
      }
      if (latest.status.trim().toLowerCase() != 'draft') {
        errorToast('Only a Draft receipt can be approved.');
        return false;
      }
      final response = await ApiService.post(
        EndPoints.customerReceiptApproval(receipt.id),
        null,
      );
      if (!_isSuccessful(response)) {
        errorToast(
          _message(response?.data, 'Unable to approve customer receipt.'),
        );
        return false;
      }
      await loadCustomerReceipts();
      successToast('Customer receipt approved successfully.');
      return true;
    } catch (error) {
      errorToast('Unable to approve customer receipt: $error');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  static String? validate(CustomerReceipt receipt) {
    if (receipt.receiptNumber.trim().isEmpty) {
      return 'Receipt number is required.';
    }
    final date = DateTime.tryParse(receipt.date);
    if (date == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(receipt.date) ||
        date.toIso8601String().substring(0, 10) != receipt.date) {
      return 'Enter a valid receipt date.';
    }
    if (receipt.customerId.trim().isEmpty) return 'Select a customer.';
    if (!const {'Invoice by Invoice', 'Cumulative'}
        .contains(receipt.invoiceMode)) {
      return 'Select an invoice mode.';
    }
    if (receipt.invoiceMode == 'Invoice by Invoice' &&
        receipt.invoiceNumber.trim().isEmpty) {
      return 'Select an invoice.';
    }
    if (receipt.paymentMode != 'Cash' && receipt.paymentMode != 'UPI') {
      return 'Select a supported payment mode.';
    }
    if (!receipt.amount.isFinite || receipt.amount <= 0) {
      return 'Amount must be greater than zero.';
    }
    if (receipt.amount != receipt.amount.roundToDouble()) {
      return 'Amount must be a whole number of rupees.';
    }
    return null;
  }

  bool _isApprovedSale(Map<String, dynamic> sale) {
    return sale['approved'] == true;
  }

  List<CustomerReceiptInvoice> invoicesForCustomer(
    String customerId, {
    String? excludingReceiptId,
  }) =>
      resolveCustomerInvoiceBalances(
        customerId,
        approvedInvoices,
        receipts,
        excludingReceiptId: excludingReceiptId,
      ).where((invoice) => invoice.outstanding > 0.01).toList();

  CustomerReceiptInvoice? invoiceForCustomer(
      String customerId, String invoiceNumber,
      {String? excludingReceiptId}) {
    for (final invoice in invoicesForCustomer(
      customerId,
      excludingReceiptId: excludingReceiptId,
    )) {
      if (invoice.number == invoiceNumber) return invoice;
    }
    return null;
  }

  static List<CustomerReceiptInvoice> resolveCustomerInvoiceBalances(
      String customerId,
      List<CustomerReceiptInvoice> allSales,
      List<CustomerReceipt> allReceipts,
      {String? excludingReceiptId}) {
    final customerSales = allSales
        .where((sale) => sale.customerId == customerId && sale.approved)
        .toList()
      ..sort((a, b) {
        final dateOrder = _sortDate(a.invoiceDate).compareTo(
          _sortDate(b.invoiceDate),
        );
        if (dateOrder != 0) return dateOrder;
        final createdOrder = _sortDate(a.createdAt).compareTo(
          _sortDate(b.createdAt),
        );
        if (createdOrder != 0) return createdOrder;
        return a.id.compareTo(b.id);
      });

    var remainingCumulative = allReceipts
        .where((receipt) =>
            receipt.customerId == customerId &&
            receipt.invoiceMode == 'Cumulative' &&
            receipt.id != excludingReceiptId)
        .fold<double>(0, (sum, receipt) => sum + receipt.amount);

    return customerSales.map((sale) {
      final invoiceKeys = {
        sale.displayNumber,
        sale.number,
        sale.id,
      }..removeWhere((value) => value.isEmpty);
      final directPaid = allReceipts
          .where((receipt) =>
              receipt.customerId == customerId &&
              receipt.id != excludingReceiptId &&
              receipt.invoiceNumber.isNotEmpty &&
              invoiceKeys.contains(receipt.invoiceNumber))
          .fold<double>(0, (sum, receipt) => sum + receipt.amount);

      var outstanding =
          (sale.total - directPaid).clamp(0.0, double.infinity).toDouble();
      final applied = remainingCumulative.clamp(0.0, outstanding).toDouble();
      outstanding =
          (outstanding - applied).clamp(0.0, double.infinity).toDouble();
      remainingCumulative = (remainingCumulative - applied)
          .clamp(0.0, double.infinity)
          .toDouble();

      return sale.withBalance(
        paid: (sale.total - outstanding).clamp(0.0, double.infinity).toDouble(),
        outstanding: outstanding,
      );
    }).toList();
  }

  static DateTime _sortDate(String value) =>
      DateTime.tryParse(value) ?? DateTime.utc(1970);

  List<dynamic>? _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      if (data['success'] == false) return null;
      final value = data['data'];
      if (value is List) return value;
      if (value is Map && value['success'] == false) return null;
      if (value is Map && value['data'] is List) {
        return value['data'] as List<dynamic>;
      }
    }
    return null;
  }

  bool _isSuccessful(dynamic response) =>
      response != null &&
      (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) &&
      !(response.data is Map && response.data['success'] == false);

  String _message(dynamic data, String fallback) {
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }
    }
    return fallback;
  }
}

class CustomerReceiptInvoice {
  final String id;
  final String number;
  final String displayNumber;
  final String customerId;
  final String customerName;
  final String invoiceDate;
  final String createdAt;
  final double total;
  final double paid;
  final double outstanding;
  final bool approved;

  const CustomerReceiptInvoice({
    required this.number,
    required this.customerId,
    required this.customerName,
    this.id = '',
    this.displayNumber = '',
    this.invoiceDate = '',
    this.createdAt = '',
    this.total = 0,
    this.paid = 0,
    this.outstanding = 0,
    this.approved = true,
  });

  factory CustomerReceiptInvoice.fromSaleJson(Map<String, dynamic> json) {
    final customer = json['customer'] is Map
        ? Map<String, dynamic>.from(json['customer'] as Map)
        : const <String, dynamic>{};
    final storedNumber = (json['invoice_no'] ?? '').toString().trim();
    final id = (json['id'] ?? json['_id'] ?? '').toString().trim();
    final displayNumber =
        (json['directSaleNo'] ?? json['direct_sale_no'] ?? storedNumber)
            .toString()
            .trim();
    return CustomerReceiptInvoice(
      id: id,
      number: storedNumber.isNotEmpty
          ? storedNumber
          : displayNumber.isNotEmpty
              ? displayNumber
              : id,
      displayNumber: displayNumber,
      customerId:
          (json['customer_id'] ?? json['customerId'] ?? customer['id'] ?? '')
              .toString()
              .trim(),
      customerName:
          (json['customer_name'] ?? customer['name'] ?? '').toString().trim(),
      invoiceDate: (json['invoiceDate'] ??
              json['invoice_date'] ??
              json['sale_date'] ??
              '')
          .toString()
          .trim(),
      createdAt: (json['createdAt'] ?? '').toString().trim(),
      total: _invoiceAmount(
        json['invoiceTotal'] ?? json['invoice_total'] ?? json['total_amount'],
      ),
      approved: json['approved'] == true,
    );
  }

  CustomerReceiptInvoice withBalance({
    required double paid,
    required double outstanding,
  }) =>
      CustomerReceiptInvoice(
        id: id,
        number: number,
        displayNumber: displayNumber,
        customerId: customerId,
        customerName: customerName,
        invoiceDate: invoiceDate,
        createdAt: createdAt,
        total: total,
        paid: paid,
        outstanding: outstanding,
        approved: approved,
      );

  static double _invoiceAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
