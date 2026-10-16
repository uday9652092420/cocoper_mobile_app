import 'dart:async';

import 'package:cocoper_mobile/app/controllers/salesorders/sales_order_controller.dart';
import 'package:cocoper_mobile/app/models/sales_order.dart';
import 'package:cocoper_mobile/app/models/sales_order_line.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _LatestOrderController extends SalesOrderController {
  SalesOrder? latestOrder;
  int refreshCount = 0;
  Completer<SalesOrder?>? pendingOrder;

  @override
  Future<SalesOrder?> fetchSalesOrderById(String id) {
    refreshCount++;
    if (pendingOrder != null) return pendingOrder!.future;
    return Future.value(latestOrder);
  }
}

SalesOrderLine _validLine({
  String mode = SalesOrderController.modeTonage,
  double quantity = 10,
  double discount = 0,
  double saleCost = 25,
}) {
  final actualQuantity = SalesOrderController.calculateActualQuantity(
    mode: mode,
    quantity: quantity,
    discount: discount,
    piecesPercentage: 0,
  );
  final saleAmount =
      SalesOrderController.calculateSaleAmount(saleCost, actualQuantity);
  return SalesOrderLine(
    itemId: 'item-1',
    quantity: quantity,
    discount: discount,
    pieces: 5,
    baseCost: SalesOrderController.calculateBaseCost(saleAmount, 5),
    actualQuantity: actualQuantity,
    saleCost: saleCost,
    saleAmount: saleAmount,
    amount: saleAmount,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(toastChannel, (_) async => true);

  group('Sales Order edit validation', () {
    String? validate({
      String date = '2026-10-16',
      String mode = SalesOrderController.modeTonage,
      List<SalesOrderLine>? lines,
    }) {
      return SalesOrderController.validateSalesOrder(
        soNumber: 'SO-10',
        date: date,
        customerId: 'customer-1',
        mode: mode,
        lines: lines ?? [_validLine()],
      );
    }

    test('accepts valid editable Sales Order data', () {
      expect(validate(), isNull);
    });

    test('rejects missing mandatory fields and invalid dates', () {
      expect(
        SalesOrderController.validateSalesOrder(
          soNumber: '',
          date: '2026-10-16',
          customerId: 'customer-1',
          mode: SalesOrderController.modeTonage,
          lines: [_validLine()],
        ),
        isNotNull,
      );
      expect(validate(date: '2026-02-30'), isNotNull);
      expect(
        validate(mode: SalesOrderController.modeTonagePercentage),
        isNotNull,
      );
      expect(validate(lines: const []), isNotNull);
    });

    test('rejects non-positive quantities or prices', () {
      expect(validate(lines: [_validLine(quantity: 0)]), isNotNull);
      expect(validate(lines: [_validLine(saleCost: 0)]), isNotNull);
      expect(
        validate(
          mode: SalesOrderController.modeLessing,
          lines: [
            _validLine(
              mode: SalesOrderController.modeLessing,
              discount: 100,
            ),
          ],
        ),
        isNotNull,
      );
    });

    test('only Draft is editable; unknown statuses fail closed', () {
      expect(
        SalesOrderController.canEditSalesOrder(
          const SalesOrder(status: ' Draft '),
        ),
        isTrue,
      );
      expect(
        SalesOrderController.canEditSalesOrder(
          const SalesOrder(status: 'Approved'),
        ),
        isFalse,
      );
      expect(
        SalesOrderController.canEditSalesOrder(
          const SalesOrder(status: 'Awaiting Review'),
        ),
        isFalse,
      );
    });

    test('total falls back to legacy amount when saleAmount is absent', () {
      expect(
        SalesOrderController.calculateTotalAmount(
          const [SalesOrderLine(amount: 42)],
        ),
        42,
      );
    });

    test(
        'update rechecks latest server status and never updates changed status',
        () async {
      final controller = _LatestOrderController()
        ..latestOrder = const SalesOrder(id: 'so-1', status: 'Approved');

      final updated = await controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );

      expect(updated, isFalse);
      expect(controller.refreshCount, 1);
      expect(controller.isSaving.value, isFalse);
    });

    test('update rejects invalid values before refreshing or submitting',
        () async {
      final controller = _LatestOrderController()
        ..latestOrder = const SalesOrder(id: 'so-1', status: 'Draft');

      final updated = await controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine(quantity: 0)],
      );

      expect(updated, isFalse);
      expect(controller.refreshCount, 0);
      expect(controller.isSaving.value, isFalse);
    });

    test('duplicate update attempts are prevented while refresh is pending',
        () async {
      final controller = _LatestOrderController()
        ..pendingOrder = Completer<SalesOrder?>();
      final firstRequest = controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );
      await Future<void>.delayed(Duration.zero);

      final duplicateRequest = await controller.updateSalesOrder(
        id: 'so-1',
        status: 'Draft',
        soNumber: 'SO-1',
        date: '2026-10-16',
        customerId: 'customer-1',
        remarks: '',
        mode: SalesOrderController.modeTonage,
        lines: [_validLine()],
      );
      controller.pendingOrder!.complete(
        const SalesOrder(id: 'so-1', status: 'Approved'),
      );

      expect(duplicateRequest, isFalse);
      expect(await firstRequest, isFalse);
      expect(controller.refreshCount, 1);
      expect(controller.isSaving.value, isFalse);
    });
  });
}
