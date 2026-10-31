import 'package:cocoper_mobile/app/controllers/directsales/direct_sales_controller.dart';
import 'package:cocoper_mobile/app/controllers/salesorders/sales_order_controller.dart';
import 'package:cocoper_mobile/app/models/direct_sale.dart';
import 'package:cocoper_mobile/app/models/lookup_option.dart';
import 'package:cocoper_mobile/app/helpers/shared_preferences.dart';
import 'package:cocoper_mobile/app/views/directsales/new_direct_sale_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  DirectSaleLineValues calculate({
    String mode = SalesOrderController.modeTonage,
    double quantity = 100,
    double discount = 0,
    double piecesPercentage = 0,
    bool enabled = false,
    double salesPrice = 2,
  }) {
    return DirectSalesController.calculateLineValues(
      mode: mode,
      quantity: quantity,
      discount: discount,
      piecesPercentage: piecesPercentage,
      piecesPercentageEnabled: enabled,
      salesPrice: salesPrice,
    );
  }

  group('Direct Sales line calculations', () {
    test('disabled Pieces % preserves the existing Tonnage calculation', () {
      final values = calculate(quantity: 100, discount: 20);
      final expected = SalesOrderController.calculateActualQuantity(
        mode: SalesOrderController.modeTonage,
        quantity: 100,
        discount: 20,
        piecesPercentage: 0,
      );

      expect(values.actualQuantity, expected);
      expect(values.discount, 20);
      expect(values.piecesPercentage, 0);
    });

    test('enabled Pieces % at zero replaces manual discount with zero', () {
      final values = calculate(discount: 20, enabled: true);

      expect(values.discount, 0);
      expect(values.actualQuantity, 100);
      expect(values.piecesPercentage, 0);
    });

    test('25, 50, and 100 percent calculate percentage discounts', () {
      for (final testCase in [
        (percentage: 25.0, discount: 25.0, actual: 75.0),
        (percentage: 50.0, discount: 50.0, actual: 50.0),
        (percentage: 100.0, discount: 100.0, actual: 0.0),
      ]) {
        final values = calculate(
          piecesPercentage: testCase.percentage,
          enabled: true,
        );

        expect(values.piecesPercentage, testCase.percentage);
        expect(values.discount, testCase.discount);
        expect(values.actualQuantity, testCase.actual);
      }
    });

    test('blank percentage parses as zero', () {
      expect(DirectSalesController.parsePiecesPercentage(''), 0);
      expect(DirectSalesController.parsePiecesPercentage('  '), 0);
    });

    test('nonnumeric and non-finite percentages are rejected', () {
      expect(DirectSalesController.parsePiecesPercentage('abc'), isNull);
      expect(DirectSalesController.parsePiecesPercentage('NaN'), isNull);
      expect(DirectSalesController.parsePiecesPercentage('Infinity'), isNull);
      expect(
        calculate(piecesPercentage: double.nan, enabled: true).piecesPercentage,
        0,
      );
      expect(
        calculate(
          piecesPercentage: double.infinity,
          enabled: true,
        ).piecesPercentage,
        0,
      );
    });

    test('negative and over-100 percentage input is clamped', () {
      expect(DirectSalesController.parsePiecesPercentage('-10'), 0);
      expect(DirectSalesController.parsePiecesPercentage('150'), 100);
      expect(calculate(piecesPercentage: -10, enabled: true).discount, 0);
      expect(calculate(piecesPercentage: 150, enabled: true).discount, 100);
    });

    test('quantity changes recalculate the effective discount and quantity',
        () {
      final first =
          calculate(quantity: 100, piecesPercentage: 25, enabled: true);
      final changed =
          calculate(quantity: 200, piecesPercentage: 25, enabled: true);

      expect(first.discount, 25);
      expect(changed.discount, 50);
      expect(changed.actualQuantity, 150);
    });

    test('percentage changes recalculate the effective discount and quantity',
        () {
      final first =
          calculate(quantity: 100, piecesPercentage: 25, enabled: true);
      final changed =
          calculate(quantity: 100, piecesPercentage: 75, enabled: true);

      expect(first.actualQuantity, 75);
      expect(changed.discount, 75);
      expect(changed.actualQuantity, 25);
    });

    test('percentage takes precedence over manual discount only while enabled',
        () {
      final enabled = calculate(
        quantity: 100,
        discount: 20,
        piecesPercentage: 25,
        enabled: true,
      );
      final disabled = calculate(
        quantity: 100,
        discount: 20,
        piecesPercentage: 25,
      );

      expect(enabled.discount, 25);
      expect(enabled.actualQuantity, 75);
      expect(disabled.discount, 20);
      expect(disabled.piecesPercentage, 0);
      expect(
        disabled.actualQuantity,
        SalesOrderController.calculateActualQuantity(
          mode: SalesOrderController.modeTonage,
          quantity: 100,
          discount: 20,
          piecesPercentage: 0,
        ),
      );
    });

    test('separate rows retain independent percentage values', () {
      final rows = [
        calculate(quantity: 100, piecesPercentage: 10, enabled: true),
        calculate(quantity: 200, piecesPercentage: 40, enabled: true),
      ];

      expect(rows[0].discount, 10);
      expect(rows[0].actualQuantity, 90);
      expect(rows[1].discount, 80);
      expect(rows[1].actualQuantity, 120);
    });

    test('Pieces mode ignores percentage and keeps Lessing behavior', () {
      final values = calculate(
        mode: SalesOrderController.modeLessing,
        quantity: 100,
        discount: 10,
        piecesPercentage: 80,
        enabled: true,
      );

      expect(values.discount, 10);
      expect(values.piecesPercentage, 0);
      expect(values.actualQuantity, 90);
    });

    test('actual quantity rounds to six decimal places', () {
      final values = calculate(
        quantity: 1.23456789,
        enabled: true,
      );

      expect(values.actualQuantity, closeTo(1.234568, 0.00000001));
    });

    test('sales amount rounds to two decimal places', () {
      final values = calculate(
        quantity: 1.23456789,
        enabled: true,
        salesPrice: 1.23,
      );

      expect(values.salesAmount, 1.52);
    });

    test('existing non-percentage Tonnage and Pieces formulas are unchanged',
        () {
      final tonnage = calculate(quantity: 3, discount: 100);
      final pieces = calculate(
        mode: SalesOrderController.modeLessing,
        quantity: 12,
        discount: 2,
      );

      expect(tonnage.actualQuantity, 2.727273);
      expect(pieces.actualQuantity, 10);
    });
  });

  group('Direct Sales invoice totals', () {
    double total({
      double salesAmount = 0,
      double gunnyBagAmount = 0,
      double additionalCharges = 0,
      double loadingCharges = 0,
    }) {
      return DirectSalesController.calculateInvoiceTotal(
        salesAmount: salesAmount,
        gunnyBagAmount: gunnyBagAmount,
        additionalCharges: additionalCharges,
        loadingCharges: loadingCharges,
      );
    }

    test('empty charges count as zero', () {
      expect(total(salesAmount: 100, gunnyBagAmount: 25), 125);
      expect(total(), 0);
    });

    test('additional charge only is included', () {
      expect(total(additionalCharges: 125.50), 125.50);
    });

    test('loading charge only is included', () {
      expect(total(loadingCharges: 50.25), 50.25);
    });

    test('both decimal charges are included once with item and bag amounts',
        () {
      expect(
        total(
          salesAmount: 100,
          gunnyBagAmount: 10,
          additionalCharges: 1.25,
          loadingCharges: 2.50,
        ),
        113.75,
      );
    });

    test('cleared charges are zero and non-finite input cannot poison total',
        () {
      expect(
        total(
          salesAmount: 100,
          additionalCharges: double.nan,
          loadingCharges: double.infinity,
        ),
        100,
      );
      expect(total(additionalCharges: 0, loadingCharges: 0), 0);
    });
  });

  group('Direct Sales line serialization', () {
    test('disabled percentage serializes as zero', () {
      final values = calculate(quantity: 100, discount: 20);
      final line = DirectSaleLine(
        itemId: 'item-1',
        quantity: 100,
        discount: values.discount,
        piecesPercentage: values.piecesPercentage,
        actualQuantity: values.actualQuantity,
        salesPrice: 2,
        salesAmount: values.salesAmount,
      );

      expect(line.toJson()['piecesPercentage'], 0);
      expect(line.toJson()['discount'], 20);
    });

    test('enabled percentage serializes effective values consistently', () {
      final values = calculate(
        quantity: 100,
        discount: 20,
        piecesPercentage: 25,
        enabled: true,
      );
      final line = DirectSaleLine(
        itemId: 'item-1',
        quantity: 100,
        discount: values.discount,
        piecesPercentage: values.piecesPercentage,
        actualQuantity: values.actualQuantity,
        salesPrice: 2,
        salesAmount: values.salesAmount,
      );
      final json = line.toJson();

      expect(json['piecesPercentage'], 25);
      expect(json['discount'], 25);
      expect(json['actualQuantity'], 75);
      expect(json['salesAmount'], 150);
      expect(
          json.keys,
          containsAll([
            'itemId',
            'quantity',
            'discount',
            'piecesPercentage',
            'actualQuantity',
            'salesPrice',
            'salesAmount',
          ]));
    });
  });

  group('Direct Sales Pieces % editor', () {
    setUp(() async {
      Get.testMode = true;
      SharedPreferences.setMockInitialValues({});
      await SharedPrefsHelper.init();
      Get.put<DirectSalesController>(_FakeDirectSalesController());
    });

    tearDown(() {
      Get.reset();
    });

    Future<void> pumpForm(WidgetTester tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(home: NewDirectSaleView()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('percentage inputs track checkbox, rows, and quantity mode',
        (tester) async {
      await pumpForm(tester);

      final initialFieldCount = find.byType(TextFormField).evaluate().length;
      expect(find.byType(Checkbox), findsOneWidget);

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(initialFieldCount + 1));

      await tester.ensureVisible(find.text('Add Line'));
      await tester.tap(find.text('Add Line'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(initialFieldCount + 6));

      await tester.ensureVisible(find.text('Pieces').first);
      await tester.tap(find.text('Pieces').first);
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(initialFieldCount + 4));

      await tester.ensureVisible(find.text('Tonnage'));
      await tester.tap(find.text('Tonnage'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(initialFieldCount + 4));

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(initialFieldCount + 6));
    });

    testWidgets('percentage discount replaces then restores manual discount',
        (tester) async {
      await pumpForm(tester);

      Finder fieldAt(int index) => find.byType(TextFormField).at(index);

      await tester.ensureVisible(fieldAt(2));
      await tester.enterText(fieldAt(2), '100');
      await tester.enterText(fieldAt(3), '20');
      await tester.enterText(fieldAt(5), '2');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.enterText(fieldAt(4), '25');
      await tester.pumpAndSettle();

      final activeDiscount = tester.widget<TextFormField>(fieldAt(3));
      expect(activeDiscount.controller!.text, '25.0');
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: fieldAt(3),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );
      expect(find.text('₹150.00'), findsWidgets);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      final restoredDiscount = tester.widget<TextFormField>(fieldAt(3));
      expect(restoredDiscount.controller!.text, '20');
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: fieldAt(3),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isFalse,
      );
    });

    testWidgets('charge fields accept, update, edit, and clear amounts',
        (tester) async {
      await pumpForm(tester);

      Finder additionalField() {
        final fields = find.byType(TextFormField);
        return fields.at(fields.evaluate().length - 2);
      }

      Finder loadingField() => find.byType(TextFormField).last;

      await tester.ensureVisible(additionalField());
      await tester.enterText(additionalField(), '125.50');
      await tester.pumpAndSettle();
      expect(find.text('₹125.50'), findsWidgets);

      await tester.ensureVisible(loadingField());
      await tester.enterText(loadingField(), '50.25');
      await tester.pumpAndSettle();
      expect(find.text('₹175.75'), findsWidgets);

      await tester.enterText(additionalField(), '10.25');
      await tester.pumpAndSettle();
      expect(find.text('₹60.50'), findsWidgets);

      await tester.enterText(additionalField(), '');
      await tester.pumpAndSettle();
      expect(find.text('₹50.25'), findsWidgets);

      await tester.enterText(loadingField(), '');
      await tester.pumpAndSettle();
      expect(find.text('₹0.00'), findsWidgets);
    });

    testWidgets('Bag Bharthi accepts a user-entered value', (tester) async {
      await pumpForm(tester);

      final bagBharthiField = find.byKey(const ValueKey('bag-bharthi-0'));
      await tester.ensureVisible(bagBharthiField);
      await tester.enterText(bagBharthiField, '2.75');
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(bagBharthiField);
      expect(field.controller!.text, '2.75');
      expect(
        tester.widget<TextField>(
          find.descendant(
            of: bagBharthiField,
            matching: find.byType(TextField),
          ),
        ).readOnly,
        isFalse,
      );
    });
  });
}

class _FakeDirectSalesController extends DirectSalesController {
  @override
  Future<void> loadCreateLookups() async {
    customers
        .assignAll(const [LookupOption(id: 'customer-1', label: 'Customer')]);
    branches.assignAll(const [LookupOption(id: 'branch-1', label: 'Branch')]);
    items.assignAll(const [LookupOption(id: 'item-1', label: 'Item')]);
    gunnyBagTypes.assignAll(const [
      DirectSaleBagType(
        id: 'bag-type-1',
        label: 'Gunny Bag',
        bagBharthi: 1.5,
      ),
    ]);
    hasLookupError.value = false;
    isLoadingLookups.value = false;
  }

  @override
  Future<String> generateDirectSaleNumber() async => 'DSO-01';
}
