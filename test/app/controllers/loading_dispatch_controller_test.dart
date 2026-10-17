import 'package:cocoper_mobile/app/models/loading_dispatch.dart';
import 'package:cocoper_mobile/app/services/loading_dispatch_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validDispatch = LoadingDispatch(
    dispatchNumber: 'DSP-2026-1',
    customerId: 'customer-id',
    lorryNumber: 'TN-01-AB-1234',
    driverName: 'Driver One',
    driverMobile: '9876543210',
    dispatchStatus: 'Draft',
    lines: [
      LoadingDispatchLine(
        branchId: 'branch-id',
        date: '2026-10-17',
        itemId: 'item-id',
        bharthi: 'Standard',
        quantity: 10,
        pendingQuantity: 10,
      ),
    ],
  );

  test('validates complete draft dispatch with one or more loading lines', () {
    expect(LoadingDispatchService.validate(validDispatch), isNull);
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(lines: const []),
      ),
      'Add at least one loading line.',
    );
  });

  test('rejects invalid header and loading line values', () {
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(dispatchNumber: ''),
      ),
      'Enter a dispatch number.',
    );
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(customerId: ''),
      ),
      'Select a customer.',
    );
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(
          lines: const [
            LoadingDispatchLine(
              branchId: 'branch-id',
              date: '2026-02-30',
              itemId: 'item-id',
              bharthi: 'Standard',
              quantity: 10,
            ),
          ],
        ),
      ),
      'Loading line 1: select a valid date.',
    );
    expect(
      LoadingDispatchService.validate(
        validDispatch.copyWith(
          lines: const [
            LoadingDispatchLine(
              branchId: 'branch-id',
              date: '2026-10-17',
              itemId: 'item-id',
              bharthi: 'Standard',
              quantity: 0,
            ),
          ],
        ),
      ),
      'Loading line 1: enter a quantity greater than zero.',
    );
  });
}

extension on LoadingDispatch {
  LoadingDispatch copyWith({
    String? dispatchNumber,
    String? customerId,
    List<LoadingDispatchLine>? lines,
  }) =>
      LoadingDispatch(
        id: id,
        dispatchNumber: dispatchNumber ?? this.dispatchNumber,
        customerId: customerId ?? this.customerId,
        lorryNumber: lorryNumber,
        driverName: driverName,
        driverMobile: driverMobile,
        dispatchDate: dispatchDate,
        dispatchStatus: dispatchStatus,
        invoiceGenerated: invoiceGenerated,
        lines: lines ?? this.lines,
      );
}
