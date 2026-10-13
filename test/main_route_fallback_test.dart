import 'package:cocoper_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('unregistered routes show the not-found screen', (tester) async {
    Get.testMode = true;
    await tester.pumpWidget(const app.MyApp());
    await tester.pumpAndSettle();

    Get.toNamed<void>('/unregistered-test-route');
    await tester.pumpAndSettle();

    expect(find.text('This page could not be found.'), findsOneWidget);
  });
}
