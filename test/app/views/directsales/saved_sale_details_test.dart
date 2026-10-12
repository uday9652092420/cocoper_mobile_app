import 'package:cocoper_mobile/app/controllers/directsales/direct_sales_controller.dart';
import 'package:cocoper_mobile/app/models/direct_sale.dart';
import 'package:cocoper_mobile/app/routes/app_routes.dart';
import 'package:cocoper_mobile/app/routes/app_pages.dart';
import 'package:cocoper_mobile/app/views/directsales/viewsavedsale_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

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
        actualQuantity: 75,
        salesPrice: 2,
        salesAmount: 150,
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

  setUp(() {
    Get.testMode = true;
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
    expect(find.text('Gunny Bag 1'), findsOneWidget);
    expect(find.text('₹150.00'), findsWidgets);
  });

  testWidgets('details view handles missing route model', (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: ViewSavedSaleView()),
    );

    expect(find.textContaining('Direct sale details are unavailable'),
        findsOneWidget);
  });
}

class _FakeDirectSalesController extends DirectSalesController {
  _FakeDirectSalesController(this.seedSales);

  final List<DirectSale> seedSales;

  @override
  Future<void> loadDirectSales() async {
    directSales.assignAll(seedSales);
    customerNames['customer-1'] = 'Customer One';
    branchNames['branch-1'] = 'Branch One';
    isLoadingList.value = false;
    hasListError.value = false;
  }
}
