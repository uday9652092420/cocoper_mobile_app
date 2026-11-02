import 'package:cocoper_mobile/app/controllers/directsales/direct_sales_controller.dart';
import 'package:cocoper_mobile/app/helpers/shared_preferences.dart';
import 'package:cocoper_mobile/app/models/direct_sale.dart';
import 'package:cocoper_mobile/app/models/lookup_option.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:cocoper_mobile/app/views/directsales/viewsavedsale_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const sale = DirectSale(
    id: 'sale-1',
    directSaleNo: 'RDSO-05',
    salesOrderNo: 'SO-12',
    customerId: 'customer-1',
    customerName: 'Customer One',
    branchId: 'branch-1',
    branchName: 'Branch One',
    invoiceDate: '2026-10-10',
    mode: 'tonage',
    invoiceTotal: 150,
    status: 'Pending',
    approved: false,
    lines: [
      DirectSaleLine(
        itemId: 'item-1',
        itemName: 'Coconut Bondam',
        quantity: 100,
        discount: 25,
        piecesPercentage: 25,
        pieces: 10,
        actualQuantity: 75.4,
        salesPrice: 2,
        salesAmount: 150.4,
      ),
    ],
    gunnyBags: [
      DirectSaleGunnyBag(
        bagTypeId: 'bag-1',
        bharthiTypeId: 'bharthi-1',
        bagBharthi: 1.5,
        quantity: 2,
        rate: 3,
        amount: 6,
      ),
    ],
  );

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsHelper.init();
    Get.put<DirectSalesController>(_FakeDirectSalesController([sale]));
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('View action opens details for the selected Saved Sale',
      (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.savedDirectSales,
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RDSO-05'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(find.text('Direct Sale Details'), findsOneWidget);
    expect(find.text('RDSO-05'), findsWidgets);
    expect(find.text('Customer One'), findsOneWidget);
    expect(find.text('SO-12'), findsOneWidget);
    expect(find.text('Coconut Bondam'), findsOneWidget);
    expect(find.text('Pieces %'), findsOneWidget);
    expect(find.text('Actual Quantity'), findsOneWidget);
    expect(find.text('75'), findsOneWidget);
    expect(find.text('75.4'), findsNothing);
    expect(find.text('₹150'), findsOneWidget);
    expect(find.text('Gunny Bag 1'), findsOneWidget);
    expect(find.text('₹150.00'), findsWidgets);
  });

  testWidgets('Save Changes updates a pending sale and returns to the list', (
    tester,
  ) async {
    final controller =
        Get.find<DirectSalesController>() as _FakeDirectSalesController;
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.savedDirectSales,
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final saveButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Save Changes'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(saveButton.onPressed, isNotNull);
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(controller.updateCount, 1);
    expect(Get.currentRoute, Routes.savedDirectSales);
    expect(find.text('Approval: Pending'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('details view handles missing route model', (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: ViewSavedSaleView()),
    );

    expect(find.textContaining('Direct sale details are unavailable'),
        findsOneWidget);
  });

  testWidgets('editing a pending sale can approve and returns View only', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.savedDirectSales,
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.ancestor(
              of: find.text('Save Changes'),
              matching: find.byType(ElevatedButton),
            ),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.savedDirectSales);
    expect(find.text('Approval: Approved'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Delete'), findsNothing);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.text('Direct Sale Details'), findsOneWidget);
  });
}

class _FakeDirectSalesController extends DirectSalesController {
  _FakeDirectSalesController(List<DirectSale> seedSales)
      : sales = List<DirectSale>.of(seedSales);

  List<DirectSale> sales;

  @override
  Future<void> loadCreateLookups() async {
    customers.assignAll(const [
      LookupOption(id: 'customer-1', label: 'Customer One'),
    ]);
    branches.assignAll(const [
      LookupOption(id: 'branch-1', label: 'Branch One'),
    ]);
    items.assignAll(const [
      LookupOption(id: 'item-1', label: 'Coconut Bondam'),
    ]);
  }

  @override
  Future<void> loadDirectSales() async {
    directSales.assignAll(sales);
    customerNames['customer-1'] = 'Customer One';
    branchNames['branch-1'] = 'Branch One';
    isLoadingList.value = false;
    hasListError.value = false;
  }

  @override
  Future<bool> approveSale(DirectSale sale) async {
    sales = sales
        .map(
          (existing) => existing.id != sale.id
              ? existing
              : DirectSale(
                  id: existing.id,
                  directSaleNo: existing.directSaleNo,
                  salesOrderNo: existing.salesOrderNo,
                  customerId: existing.customerId,
                  customerName: existing.customerName,
                  branchId: existing.branchId,
                  branchName: existing.branchName,
                  invoiceDate: existing.invoiceDate,
                  mode: existing.mode,
                  invoiceTotal: existing.invoiceTotal,
                  status: 'Approved',
                  approved: true,
                  lines: existing.lines,
                  gunnyBags: existing.gunnyBags,
                ),
        )
        .toList();
    return true;
  }

  int updateCount = 0;

  @override
  Future<bool> updateDirectSale({
    required DirectSale sale,
    required String customerId,
    required String branchId,
    required String invoiceDate,
    required String mode,
    required List<DirectSaleLine> lines,
    required List<DirectSaleGunnyBag> gunnyBags,
    required double additionalCharges,
    required double loadingCharges,
    String salesOrderNo = '',
  }) async {
    updateCount++;
    final lineTotal = lines.fold<double>(
      0,
      (sum, line) => sum + line.salesAmount,
    );
    final bagTotal = gunnyBags.fold<double>(
      0,
      (sum, bag) => sum + bag.amount,
    );
    sales = sales
        .map(
          (existing) => existing.id != sale.id
              ? existing
              : DirectSale(
                  id: existing.id,
                  directSaleNo: existing.directSaleNo,
                  salesOrderNo: salesOrderNo,
                  customerId: customerId,
                  customerName: existing.customerName,
                  branchId: branchId,
                  branchName: existing.branchName,
                  invoiceDate: invoiceDate,
                  mode: mode,
                  invoiceTotal: DirectSalesController.calculateInvoiceTotal(
                    salesAmount: lineTotal,
                    gunnyBagAmount: bagTotal,
                    additionalCharges: additionalCharges,
                    loadingCharges: loadingCharges,
                  ),
                  status: existing.status,
                  approved: existing.approved,
                  lines: lines,
                  gunnyBags: gunnyBags,
                ),
        )
        .toList();
    return true;
  }
}
