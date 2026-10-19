import 'package:cocoper_mobile/app/custome_widgets/common_page_search.dart';
import 'package:cocoper_mobile/app/custome_widgets/app_status_badge.dart';
import 'package:cocoper_mobile/app/custome_widgets/custome_dropdown_form.dart';
import 'package:cocoper_mobile/app/custome_widgets/custome_textbox_label.dart';
import 'package:cocoper_mobile/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared controls fit a narrow screen with scaled text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.4),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CommonPageSearch(
                    txtHintValue: 'Search transactions',
                  ),
                  SizedBox(height: AppSpacing.lg),
                  CustomeTextBoxLabel(
                    labelText: 'Transaction description',
                    hintText: 'Enter a description',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byType(CommonPageSearch)),
      ).scale(16),
      closeTo(22.4, 0.01),
    );
  });

  test('theme defines shared colors and minimum touch target sizes', () {
    final theme = AppTheme.lightTheme;

    expect(theme.colorScheme.primary, AppColors.primaryLight);
    expect(theme.scaffoldBackgroundColor, AppColors.scaffoldBackground);
    expect(
        theme.elevatedButtonTheme.style?.minimumSize?.resolve({})?.height, 48);
    expect(
        theme.outlinedButtonTheme.style?.minimumSize?.resolve({})?.height, 48);
  });

  testWidgets('shared status badge uses the semantic success palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(child: AppStatusBadge(status: 'Approved')),
        ),
      ),
    );

    final badge = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Approved'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = badge.decoration! as BoxDecoration;

    expect(decoration.color, const Color(0xFFE7F3EC));
  });

  testWidgets('shared dropdown keeps the selected value and compact labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: CustomeDropdownForm(
              label: 'Branch',
              items: const <dynamic>[
                {'north': 'North Branch'},
                {'south': 'South Branch'},
              ],
              selectedKey: 'south',
              onChanged: (_) {},
              isRequired: true,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Branch'), findsOneWidget);
    expect(find.text('South Branch'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'south',
    );
  });
}
