import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../helpers/flutter_toast.dart';
import '../../helpers/shared_preferences.dart';
import '../../models/lookup_option.dart';
import '../../models/purchase_invoice.dart';
import '../../models/supplier_payment.dart';
import '../../repositories/supplier_payment_repository.dart';

const _maxSupplierPaymentFileBytes = 10 * 1024 * 1024;
const _maxSupplierPaymentRequestBytes = 15 * 1024 * 1024;

class SupplierPaymentController extends GetxController {
  SupplierPaymentController({
    SupplierPaymentRepository? repository,
  }) : _repository = repository ?? SupplierPaymentRepository();

  final SupplierPaymentRepository _repository;
  final payments = <SupplierPayment>[].obs;
  final suppliers = <LookupOption>[].obs;
  final purchaseInvoices = <PurchaseInvoice>[].obs;
  final searchQuery = ''.obs;
  final detail = Rxn<SupplierPayment>();
  final isLoadingList = false.obs;
  final isLoadingLookups = false.obs;
  final isLoadingDetail = false.obs;
  final isSaving = false.obs;
  final hasListError = false.obs;
  final listError = ''.obs;
  final lookupError = ''.obs;
  final detailError = ''.obs;
  Future<void>? _lookupsRequest;

  List<SupplierPayment> get filteredPayments {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return payments.toList(growable: false);
    return payments.where((payment) {
      return payment.paymentNumber.toLowerCase().contains(query) ||
          payment.supplierName.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  List<PurchaseInvoice> invoicesForSupplier(
    String supplierId, {
    SupplierPayment? editing,
  }) =>
      purchaseInvoices.where((invoice) {
        if (invoice.id.isEmpty || invoice.supplierId != supplierId) {
          return false;
        }
        if (editing?.purchaseInvoiceId == invoice.id) return true;
        return invoice.status.trim().toLowerCase() == 'approved' &&
            invoice.outstandingAmount > 0;
      }).toList(growable: false);

  double outstandingForInvoice(
    PurchaseInvoice invoice, {
    SupplierPayment? editing,
  }) {
    final currentPaymentApplies = editing != null &&
        editing.invoiceMode == 'Invoice by Invoice' &&
        editing.purchaseInvoiceId == invoice.id;
    return invoice.outstandingAmount +
        (currentPaymentApplies ? editing.amount : 0);
  }

  Future<void> loadSupplierPayments() async {
    if (isLoadingList.value) return;
    isLoadingList.value = true;
    hasListError.value = false;
    listError.value = '';
    try {
      payments.assignAll(await _repository.fetchSupplierPayments());
    } catch (error) {
      hasListError.value = true;
      listError.value = 'Unable to load supplier payments: $error';
    } finally {
      isLoadingList.value = false;
    }
  }

  Future<void> refreshSupplierPayments() => loadSupplierPayments();

  Future<void> searchSupplierPayments(String value) async {
    searchQuery.value = value;
  }

  Future<void> loadLookups() {
    final runningRequest = _lookupsRequest;
    if (runningRequest != null) return runningRequest;
    final request = _performLoadLookups();
    _lookupsRequest = request;
    return request.whenComplete(() {
      if (identical(_lookupsRequest, request)) _lookupsRequest = null;
    });
  }

  Future<void> _performLoadLookups() async {
    isLoadingLookups.value = true;
    lookupError.value = '';
    try {
      await Future.wait([
        _repository.fetchSuppliers().then(suppliers.assignAll),
        _repository.fetchPurchaseInvoices().then(purchaseInvoices.assignAll),
      ]);
    } catch (error) {
      lookupError.value = 'Unable to load supplier payment options: $error';
    } finally {
      isLoadingLookups.value = false;
    }
  }

  Future<SupplierPayment?> loadSupplierPaymentById(String id) async {
    detail.value = null;
    detailError.value = '';
    if (id.trim().isEmpty) {
      detailError.value = 'The supplier payment ID is missing.';
      return null;
    }
    isLoadingDetail.value = true;
    try {
      // The backend has no GET /supplier-payments/:id route. Its listing
      // returns full records by ID, including both attachment fields.
      final records = await _repository.fetchSupplierPayments();
      payments.assignAll(records);
      for (final payment in records) {
        if (payment.id == id) {
          detail.value = payment;
          return payment;
        }
      }
      detailError.value = 'Supplier payment not found.';
      return null;
    } catch (error) {
      detailError.value = 'Unable to load supplier payment: $error';
      return null;
    } finally {
      isLoadingDetail.value = false;
    }
  }

  Future<String?> generatePaymentNumber() async {
    try {
      return await _repository.fetchNextPaymentNumber();
    } catch (error) {
      errorToast('Unable to generate a payment number: $error');
      return null;
    }
  }

  Future<bool> createSupplierPayment(
    SupplierPayment payment, {
    List<SupplierPaymentAttachment> attachments = const [],
  }) =>
      _save(
        payment,
        isEdit: false,
        attachments: attachments,
      );

  Future<bool> updateSupplierPayment(
    SupplierPayment payment, {
    required SupplierPayment existingPayment,
    required bool replaceAttachments,
    List<SupplierPaymentAttachment> attachments = const [],
  }) =>
      _save(
        payment,
        isEdit: true,
        existingPayment: existingPayment,
        replaceAttachments: replaceAttachments,
        attachments: attachments,
      );

  Future<bool> _save(
    SupplierPayment payment, {
    required bool isEdit,
    SupplierPayment? existingPayment,
    bool replaceAttachments = false,
    List<SupplierPaymentAttachment> attachments = const [],
  }) async {
    if (isSaving.value) return false;
    final validationError = validate(payment, isEdit: isEdit);
    if (validationError != null) {
      errorToast(validationError);
      return false;
    }
    final invoiceError = _validateInvoice(payment, existingPayment);
    if (invoiceError != null) {
      errorToast(invoiceError);
      return false;
    }
    if (isEdit && existingPayment?.canSafelyPreserveAttachments != true) {
      errorToast(
        'Existing attachment data is unavailable. This payment cannot be '
        'updated safely.',
      );
      return false;
    }
    if (replaceAttachments && attachments.isEmpty) {
      errorToast('Select at least one attachment to replace existing files.');
      return false;
    }

    final selectedBytes = attachments.fold<int>(
      0,
      (total, attachment) => total + attachment.bytes.length,
    );
    if (selectedBytes > _maxSupplierPaymentFileBytes) {
      errorToast('Selected attachments exceed the 10 MB total size limit.');
      return false;
    }

    isSaving.value = true;
    try {
      final organizationId = await SharedPrefsHelper.getString(
        SharedPrefsHelper.organizationId,
      );
      if (organizationId.trim().isEmpty) {
        errorToast('Organization is unavailable. Please sign in again.');
        return false;
      }

      String? namesJson;
      String? filesJson;
      if ((!isEdit || replaceAttachments) && attachments.isNotEmpty) {
        namesJson = jsonEncode(
          attachments.map((attachment) => attachment.name).toList(),
        );
        filesJson = jsonEncode(
          attachments.map((attachment) => attachment.dataUrl).toList(),
        );
      } else if (isEdit) {
        namesJson = existingPayment!.attachmentNamesJson;
        filesJson = existingPayment.attachmentFilesJson;
      }

      final body = payment.toRequestJson(
        organizationId: organizationId,
        attachmentNamesJson: namesJson,
        attachmentFilesJson: filesJson,
      );
      if (utf8.encode(jsonEncode(body)).length >
          _maxSupplierPaymentRequestBytes) {
        errorToast(
          'Attachments make the payment request exceed the server limit. '
          'Replace them with smaller files.',
        );
        return false;
      }

      final response = isEdit
          ? await _repository.updateSupplierPayment(payment.id, body)
          : await _repository.createSupplierPayment(body);
      if (!SupplierPaymentRepository.isSuccessfulResponse(response)) {
        errorToast(SupplierPaymentRepository.responseMessage(
          response?.data,
          isEdit
              ? 'Unable to update supplier payment.'
              : 'Unable to save supplier payment.',
        ));
        return false;
      }

      await loadSupplierPayments();
      if (hasListError.value) {
        errorToast(
          'Payment was saved, but the saved payment list could not be refreshed: '
          '${listError.value}',
        );
      } else {
        successToast(
          isEdit
              ? 'Supplier payment updated successfully.'
              : 'Supplier payment saved successfully.',
        );
      }
      return true;
    } catch (error) {
      errorToast(
        'Unable to ${isEdit ? 'update' : 'save'} supplier payment: $error',
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  @visibleForTesting
  static String? validate(SupplierPayment payment, {required bool isEdit}) {
    if (payment.paymentNumber.trim().isEmpty) {
      return 'Payment number is required.';
    }
    final date = DateTime.tryParse(payment.date);
    if (date == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(payment.date) ||
        date.toIso8601String().substring(0, 10) != payment.date) {
      return 'Enter a valid payment date.';
    }
    if (payment.supplierId.trim().isEmpty) return 'Select a supplier.';
    if (!const {'Invoice by Invoice', 'Cumulative'}
        .contains(payment.invoiceMode)) {
      return 'Select an invoice mode.';
    }
    if (payment.invoiceMode == 'Invoice by Invoice' &&
        payment.purchaseInvoiceId.trim().isEmpty) {
      return 'Select a purchase invoice.';
    }
    if (!const {'Cash', 'Bank', 'UPI'}.contains(payment.paymentMode)) {
      return 'Select a supported payment mode.';
    }
    if (!payment.amount.isFinite || payment.amount <= 0) {
      return 'Enter an amount greater than zero.';
    }
    if (isEdit && payment.id.trim().isEmpty) {
      return 'The supplier payment ID is missing.';
    }
    return null;
  }

  String? _validateInvoice(
    SupplierPayment payment,
    SupplierPayment? existingPayment,
  ) {
    if (payment.invoiceMode == 'Cumulative') return null;
    final sameInvoice = existingPayment != null &&
        existingPayment.supplierId == payment.supplierId &&
        existingPayment.invoiceMode == 'Invoice by Invoice' &&
        existingPayment.purchaseInvoiceId == payment.purchaseInvoiceId;
    PurchaseInvoice? selected;
    for (final invoice in purchaseInvoices) {
      if (invoice.id == payment.purchaseInvoiceId) {
        selected = invoice;
        break;
      }
    }
    if (selected == null) {
      if (sameInvoice && payment.amount == existingPayment.amount) return null;
      return 'The selected purchase invoice is unavailable. Reload invoices '
          'before changing its payment.';
    }
    if (selected.supplierId != payment.supplierId) {
      return 'The purchase invoice does not belong to the selected supplier.';
    }
    if (!sameInvoice &&
        (selected.status.trim().toLowerCase() != 'approved' ||
            selected.outstandingAmount <= 0)) {
      return 'Select an approved purchase invoice with an outstanding balance.';
    }
    final available =
        selected.outstandingAmount + (sameInvoice ? existingPayment.amount : 0);
    if (payment.amount > available + 0.01) {
      return 'Amount exceeds the available invoice balance.';
    }
    return null;
  }
}
