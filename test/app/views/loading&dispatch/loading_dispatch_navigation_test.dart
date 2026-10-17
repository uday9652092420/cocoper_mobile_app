import 'package:cocoper_mobile/app/controllers/loading&dispatch/loading_dispatch_controller.dart';
import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/views/dashboard/operations_view.dart';
import 'package:cocoper_mobile/app/views/loading&dispatch/savedloading&dispatches_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('Operations opens the registered Loading & Dispatch screen',
      (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialBinding: _TestLoadingDispatchBinding(),
        initialRoute: '/test_operations',
        getPages: [
          GetPage(name: '/test_operations', page: () => const OperationsView()),
          ...AppPages.routes,
        ],
      ),
    );

    await tester.ensureVisible(find.text('Loading & Dispatch'));
    await tester.tap(find.text('Loading & Dispatch'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.savedLoadingDispatches);
    expect(find.byType(SavedLoadingDispatchesView), findsOneWidget);
    expect(find.text('Add New Dispatch'), findsOneWidget);
    expect(find.text('No saved dispatches.'), findsOneWidget);
  });
}

class _TestLoadingDispatchBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<LoadingDispatchController>(_TestLoadingDispatchController());
  }
}

class _TestLoadingDispatchController extends LoadingDispatchController {
  @override
  Future<void> loadLookups() async {}

  @override
  Future<void> loadDispatches({bool force = false}) async {}
}
