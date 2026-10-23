import 'dart:async';

import 'package:cocoper_mobile/app/controllers/profit_loss_controller.dart';
import 'package:cocoper_mobile/app/models/profit_loss_statement.dart';
import 'package:cocoper_mobile/app/services/profit_loss_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledProfitLossService extends ProfitLossService {
  _ControlledProfitLossService(this.result);

  final Future<ProfitLossStatement> Function() result;
  var calls = 0;

  @override
  Future<ProfitLossStatement> load({
    required DateTime fromDate,
    required DateTime toDate,
    String? organizationId,
  }) {
    calls++;
    return result();
  }
}

const _statement = ProfitLossStatement(
  openingUnits: 1,
  openingAmount: 100,
  purchaseUnits: 0,
  purchaseAmount: 0,
  salesUnits: 0,
  salesAmount: 120,
  closingUnits: 1,
  closingAmount: 100,
  expenses: 10,
  otherIncome: 0,
  costOfGoodsSold: 0,
  grossProfit: 120,
  netProfit: 110,
  hasData: true,
);

void main() {
  test('rejects invalid dates without requesting the service', () async {
    final service = _ControlledProfitLossService(() async => _statement);
    final controller = ProfitLossController(
      service: service,
      now: DateTime(2025, 5, 31),
    );
    controller.setFromDate(DateTime(2025, 5, 20));
    controller.setToDate(DateTime(2025, 5, 10));

    expect(await controller.applyDateRange(), isFalse);
    expect(controller.filterErrorMessage.value,
        'To Date must be on or after From Date.');
    expect(service.calls, 0);
  });

  test('prevents duplicate loads and stores the successful response', () async {
    final completer = Completer<ProfitLossStatement>();
    final service = _ControlledProfitLossService(() => completer.future);
    final controller = ProfitLossController(
      service: service,
      now: DateTime(2025, 5, 31),
    );

    final firstLoad = controller.load();
    expect(controller.isLoading.value, isTrue);
    await controller.load();
    expect(service.calls, 1);

    completer.complete(_statement);
    await firstLoad;
    expect(controller.isLoading.value, isFalse);
    expect(controller.statement.value, same(_statement));
    expect(controller.errorMessage.value, isEmpty);
  });

  test('shows an error and allows a later retry', () async {
    var shouldFail = true;
    final service = _ControlledProfitLossService(() async {
      if (shouldFail) throw Exception('Server unavailable');
      return _statement;
    });
    final controller = ProfitLossController(
      service: service,
      now: DateTime(2025, 5, 31),
    );

    await controller.load();
    expect(controller.errorMessage.value, 'Server unavailable');
    expect(controller.statement.value, isNull);

    shouldFail = false;
    await controller.load();
    expect(controller.errorMessage.value, isEmpty);
    expect(controller.statement.value, same(_statement));
    expect(service.calls, 2);
  });
}
