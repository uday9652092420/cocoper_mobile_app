import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../helpers/shared_preferences.dart';
import '../models/profit_loss_statement.dart';
import '../services/profit_loss_service.dart';

class ProfitLossController extends GetxController {
  ProfitLossController({
    required ProfitLossService service,
    DateTime? now,
  }) : this._(
          service: service,
          today: now ?? DateTime.now(),
        );

  ProfitLossController._({
    required ProfitLossService service,
    required DateTime today,
  })  : _service = service,
        fromDate = DateTime(today.year, today.month - 1, today.day).obs,
        toDate = DateTime(today.year, today.month, today.day).obs;

  final ProfitLossService _service;

  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final filterErrorMessage = ''.obs;
  final statement = Rxn<ProfitLossStatement>();
  final organizationName = ''.obs;
  final Rx<DateTime> fromDate;
  final Rx<DateTime> toDate;

  String? _organizationId;

  String get scopeLabel {
    final name = organizationName.value.trim();
    return name.isEmpty ? 'All branches' : '$name · All branches';
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      _organizationId = await SharedPrefsHelper.getString(
        SharedPrefsHelper.organizationId,
      );
      organizationName.value = await SharedPrefsHelper.getString(
        SharedPrefsHelper.organizationName,
      );
      await load();
    } catch (error) {
      errorMessage.value = _message(error);
    }
  }

  Future<void> load() async {
    if (isLoading.value) return;
    if (_day(toDate.value).isBefore(_day(fromDate.value))) {
      filterErrorMessage.value = 'To Date must be on or after From Date.';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    filterErrorMessage.value = '';
    statement.value = null;
    try {
      statement.value = await _service.load(
        fromDate: fromDate.value,
        toDate: toDate.value,
        organizationId: _organizationId,
      );
    } catch (error) {
      errorMessage.value = _message(error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> applyDateRange() async {
    if (_day(toDate.value).isBefore(_day(fromDate.value))) {
      filterErrorMessage.value = 'To Date must be on or after From Date.';
      return false;
    }
    await load();
    return true;
  }

  void setFromDate(DateTime date) {
    fromDate.value = _day(date);
    filterErrorMessage.value = '';
  }

  void setToDate(DateTime date) {
    toDate.value = _day(date);
    filterErrorMessage.value = '';
  }

  String get reportingPeriod =>
      '${DateFormatters.shortDate(fromDate.value)} – '
      '${DateFormatters.shortDate(toDate.value)}';

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _message(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }
}

abstract final class DateFormatters {
  static String shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} '
      '${_monthNames[date.month - 1]} ${date.year}';

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}
