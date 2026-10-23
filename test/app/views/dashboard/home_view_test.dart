import 'package:cocoper_mobile/app/controllers/dashboard/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:cocoper_mobile/app/views/dashboard/home_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:cocoper_mobile/app/localization/localization.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';

class _TestProfileController extends ProfileController {
  @override
  Future<void> loadBootstrap() async {}
}

Widget _homeApp() => GetMaterialApp(
      translations: Localization(),
      locale: Localization.defaultLocale,
      fallbackLocale: Localization.fallbackLocale,
      getPages: [
        GetPage(
          name: Routes.newPurchaseInvoice,
          page: () => const _DestinationPage('Purchase invoice module'),
        ),
        GetPage(
          name: Routes.newSaleOrder,
          page: () => const _DestinationPage('New sales order module'),
        ),
        GetPage(
          name: Routes.newCustomerReceipt,
          page: () => const _DestinationPage('Customer receipt module'),
        ),
      ],
      home: const HomeView(),
    );

class _DestinationPage extends StatelessWidget {
  const _DestinationPage(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(title));
}

void main() {
  tearDown(Get.reset);

  testWidgets('home dashboard uses Role and has no login role chooser', (
    tester,
  ) async {
    Get.put<ProfileController>(_TestProfileController());

    await tester.pumpWidget(_homeApp());

    expect(find.text('Choose login role'), findsNothing);
    expect(find.text('Finance Manager'), findsNothing);
    expect(find.text('Role'), findsOneWidget);
    expect(find.text('Role workspace'), findsNothing);
    expect(find.text('Search work, customer or voucher'), findsOneWidget);
    expect(find.text('Purchased'), findsOneWidget);
  });

  testWidgets('fast transaction cards open their matching operation forms', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Get.put<ProfileController>(_TestProfileController());

    await tester.pumpWidget(_homeApp());
    await tester.pumpAndSettle();

    final destinations = {
      'Purchase entry': 'Purchase invoice module',
      'New Sales order': 'New sales order module',
      'Payment receipt': 'Customer receipt module',
    };

    for (final entry in destinations.entries) {
      await tester.ensureVisible(find.text(entry.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);

      Get.back<void>();
      await tester.pumpAndSettle();
    }
  });
}
