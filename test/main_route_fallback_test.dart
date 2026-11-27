import 'package:cocoper_mobile/main.dart' as app;
import 'package:cocoper_mobile/app/services/mobile_app_permissions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cocoper_mobile/app/helpers/shared_preferences.dart';

void main() {
  testWidgets('unregistered routes show the not-found screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsHelper.init();
    Get.testMode = true;
    await tester.pumpWidget(const app.MyApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    MobileAppPermissions.beginSession(
      const MobileAppPermissions(
        mobileAppLogin: true,
        mobileAppLabourAttendance: false,
      ),
    );

    Get.toNamed<void>('/unregistered-test-route');
    await tester.pumpAndSettle();

    expect(find.text('This page could not be found.'), findsOneWidget);
  });
}
