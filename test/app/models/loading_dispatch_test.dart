import 'package:cocoper_mobile/app/models/loading_dispatch.dart';
import 'package:cocoper_mobile/app/models/lookup_option.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the loading-dispatch list response shape', () {
    final dispatch = LoadingDispatch.fromJson({
      'id': 'LD-42',
      'dispatchNumber': 'DSP-2026-42',
      'customerId': 'customer-id',
      'lorryNumber': 'TN-01-AB-1234',
      'driverName': 'Driver One',
      'driverMobile': '9876543210',
      'dispatchDate': '2026-10-17T00:00:00.000Z',
      'dispatchStatus': 'Draft',
      'invoiceGenerated': false,
      'lines': [
        {
          'id': 'line-id',
          'branchId': 'branch-id',
          'date': '2026-10-16T00:00:00.000Z',
          'itemId': 'item-id',
          'bharthi': 'Standard',
          'quantity': '12.5',
          'loadedQuantity': 2,
          'pendingQuantity': 10.5,
        },
      ],
    });

    expect(dispatch.id, 'LD-42');
    expect(dispatch.dispatchNumber, 'DSP-2026-42');
    expect(dispatch.customerId, 'customer-id');
    expect(dispatch.dispatchDate, '2026-10-17');
    expect(dispatch.lines.single.date, '2026-10-16');
    expect(dispatch.lines.single.quantity, 12.5);
    expect(dispatch.lines.single.pendingQuantity, 10.5);
  });

  test('serializes edits with the existing ID but no dispatch number', () {
    const dispatch = LoadingDispatch(
      id: 'LD-42',
      dispatchNumber: 'DSP-2026-42',
      customerId: 'customer-id',
      lorryNumber: 'TN-01-AB-1234',
      driverName: 'Driver One',
      driverMobile: '9876543210',
      dispatchDate: '2026-10-17',
      dispatchStatus: 'Draft',
      lines: [
        LoadingDispatchLine(
          id: 'line-id',
          branchId: 'branch-id',
          date: '2026-10-16',
          itemId: 'item-id',
          bharthi: 'Standard',
          quantity: 12.5,
          pendingQuantity: 12.5,
        ),
      ],
    );

    final payload = dispatch.toRequestJson();
    expect(payload['id'], 'LD-42');
    expect(payload.containsKey('dispatchNumber'), isFalse);
    expect(payload['dispatchStatus'], 'Draft');
    expect((payload['lines'] as List).single['branchId'], 'branch-id');
  });

  test('omits generated ID and dispatch number from a new request', () {
    const dispatch = LoadingDispatch(
      customerId: 'customer-id',
      lorryNumber: 'TN-01-AB-1234',
      driverName: 'Driver One',
      driverMobile: '9876543210',
    );

    expect(dispatch.toRequestJson().containsKey('id'), isFalse);
    expect(dispatch.toRequestJson().containsKey('dispatchNumber'), isFalse);
  });

  test('maps customer lookup IDs and labels from API customer fields', () {
    final option = LookupOption.fromDynamic({
      'customer_id': 'customer-1',
      'customer_name': 'Customer One',
    });

    expect(option.id, 'customer-1');
    expect(option.label, 'Customer One');
  });
}
