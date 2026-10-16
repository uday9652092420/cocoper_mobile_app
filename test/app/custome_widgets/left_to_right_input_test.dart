import 'package:cocoper_mobile/app/custome_widgets/common_page_search.dart';
import 'package:cocoper_mobile/app/custome_widgets/custome_textbox_label.dart';
import 'package:cocoper_mobile/app/custome_widgets/custome_textbox_label_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared search field enters left to right', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommonPageSearch(
            txtHintValue: 'Search',
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField),
        matching: find.byType(TextField),
      ),
    );
    expect(field.textAlign, TextAlign.start);
    expect(field.textDirection, isNull);
    expect(Directionality.of(tester.element(find.byType(EditableText))),
        TextDirection.ltr);
  });

  testWidgets('shared labelled text box enters left to right', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomeTextBoxLabel(
            labelText: 'Name',
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField),
        matching: find.byType(TextField),
      ),
    );
    expect(field.textAlign, TextAlign.start);
    expect(field.textDirection, isNull);
    expect(Directionality.of(tester.element(find.byType(EditableText))),
        TextDirection.ltr);
  });

  testWidgets('shared text fields inherit RTL for Arabic text entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(
              children: [
                CommonPageSearch(txtHintValue: 'بحث'),
                CustomeTextBoxLabel(labelText: 'الاسم'),
                CustomeTextBoxLabelForm(labelText: 'الملاحظات'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = tester.widgetList<TextField>(find.byType(TextField));
    final editableFields = find.byType(EditableText).evaluate();
    expect(textFields, hasLength(3));
    expect(editableFields, hasLength(3));
    expect(textFields.every((field) => field.textDirection == null), isTrue);
    for (final field in editableFields) {
      expect(Directionality.of(field), TextDirection.rtl);
    }
  });
}
