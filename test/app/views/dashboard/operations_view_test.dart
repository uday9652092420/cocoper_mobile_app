import 'package:cocoper_mobile/app/views/dashboard/operations_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('Operations does not show the removed Cash & Bank module', (
    tester,
  ) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: OperationsView()),
    );

    expect(find.text('Cash & Bank'), findsNothing);
  });
}
