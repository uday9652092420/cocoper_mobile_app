import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('dynamic GetPage routes can return Boolean results', (
    tester,
  ) async {
    dynamic result;

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/source',
        getPages: [
          GetPage<dynamic>(
            name: '/source',
            page: () => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Get.toNamed<dynamic>('/destination');
                },
                child: const Text('Open destination'),
              ),
            ),
          ),
          GetPage<dynamic>(
            name: '/destination',
            page: () => Scaffold(
              body: TextButton(
                onPressed: () => Get.back<bool>(result: true),
                child: const Text('Return result'),
              ),
            ),
          ),
        ],
      ),
    );

    await tester.tap(find.text('Open destination'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return result'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
