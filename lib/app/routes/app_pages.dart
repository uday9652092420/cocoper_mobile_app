import 'package:cocoper_mobile/app/bindings/auth/login_binding.dart';
import 'package:cocoper_mobile/app/bindings/bagpurchase/bag_purchase_binding.dart';
import 'package:cocoper_mobile/app/bindings/cash&bankexpenses/cash_bank_expenses_binding.dart';
import 'package:cocoper_mobile/app/bindings/dashboard/dashboard_bindings.dart';
import 'package:cocoper_mobile/app/bindings/loading&dispatch/loading_dispatch_binding.dart';
import 'package:cocoper_mobile/app/bindings/customerreceipt/customer_receipt_binding.dart';
import 'package:cocoper_mobile/app/bindings/directsales/direct_sales_binding.dart';
import 'package:cocoper_mobile/app/bindings/purchaseinvoice/purchase_invoice_binding.dart';
import 'package:cocoper_mobile/app/bindings/purchaseorder/purchase_order_binding.dart';
import 'package:cocoper_mobile/app/bindings/salesorders/sales_order_binding.dart';
import 'package:cocoper_mobile/app/bindings/supplierpayments/supplier_payment_binding.dart';
import 'package:cocoper_mobile/app/views/auth/login_page_view.dart';
import 'package:cocoper_mobile/app/views/bagpurchase/savedbagpurchases_view.dart';
import 'package:cocoper_mobile/app/views/bagpurchase/newbagpurchase_view.dart';
import 'package:cocoper_mobile/app/views/bagpurchase/editbagpurchase_view.dart';
import 'package:cocoper_mobile/app/views/bagpurchase/viewbagpurchase_view.dart';
import 'package:cocoper_mobile/app/views/dashboard/dashboard_view.dart';
import 'package:cocoper_mobile/app/views/customerreceipt/savedcustomerreceipt_view.dart';
import 'package:cocoper_mobile/app/views/customerreceipt/newcustomerreceipt_view.dart';
import 'package:cocoper_mobile/app/views/customerreceipt/editcustomerreceipt_view.dart';
import 'package:cocoper_mobile/app/views/loading&dispatch/editloading&dispatch_view.dart';
import 'package:cocoper_mobile/app/views/loading&dispatch/newloading&dispatch_view.dart';
import 'package:cocoper_mobile/app/views/loading&dispatch/savedloading&dispatches_view.dart';
import 'package:cocoper_mobile/app/views/loading&dispatch/viewloading&dispacth_view.dart';
import 'package:cocoper_mobile/app/views/cash&bankexpenses/editcash&bankexpenses_view.dart';
import 'package:cocoper_mobile/app/views/cash&bankexpenses/newbank&cashexpenses_view.dart';
import 'package:cocoper_mobile/app/views/cash&bankexpenses/savedcash&bankexpenses_view.dart';
import 'package:cocoper_mobile/app/views/cash&bankexpenses/viewcash&bankexpenses_view.dart';
import 'package:cocoper_mobile/app/views/directsales/editsales_view.dart';
import 'package:cocoper_mobile/app/views/directsales/savedsales_view.dart';
import 'package:cocoper_mobile/app/views/directsales/viewsavedsale_view.dart';
import 'package:cocoper_mobile/app/views/purchaseorder/editpurchaseorder_view.dart';
import 'package:cocoper_mobile/app/views/purchaseorder/newpurchaseorder_view.dart';
import 'package:cocoper_mobile/app/views/purchaseorder/purchaseorder_view.dart';
import 'package:cocoper_mobile/app/views/purchaseinvoice/editpurchaseinvoice_view.dart';
import 'package:cocoper_mobile/app/views/purchaseinvoice/newpurchaseinvoice_view.dart';
import 'package:cocoper_mobile/app/views/purchaseinvoice/purchaseinvoicedetail_view.dart';
import 'package:cocoper_mobile/app/views/purchaseinvoice/savedpurchaseinvoices_view.dart';
import 'package:cocoper_mobile/app/views/salesorders/newsaleorder_view.dart';
import 'package:cocoper_mobile/app/views/salesorders/editsalesorder_view.dart';
import 'package:cocoper_mobile/app/views/salesorders/savedsalesorders_view.dart';
import 'package:cocoper_mobile/app/views/salesorders/viewsalesorder_view.dart';
import 'package:cocoper_mobile/app/views/supplierpayments/editsupplierpayments_view.dart';
import 'package:cocoper_mobile/app/views/supplierpayments/newsupplierpayments_view.dart';
import 'package:cocoper_mobile/app/views/supplierpayments/savedsupplierpayments_view.dart';
import 'package:cocoper_mobile/app/views/supplierpayments/viewsupplierpayment_view.dart';
import 'package:get/get.dart';
import 'package:cocoper_mobile/app/views/directsales/new_direct_sale_view.dart';
import 'package:cocoper_mobile/app/models/statements_report.dart';
import 'package:cocoper_mobile/app/views/reportsstatements/customerstatement_view.dart';
import 'package:cocoper_mobile/app/views/reportsstatements/pending&dispatch_view.dart';
import 'package:cocoper_mobile/app/views/reportsstatements/purchaseregister_view.dart';
import 'package:cocoper_mobile/app/views/reportsstatements/salesregister_view.dart';
import 'package:cocoper_mobile/app/views/reportsstatements/statements_report_view.dart';
import 'package:cocoper_mobile/app/views/reportsstatements/supplierstatement_view.dart';

import 'app_routes.dart';

class AppPages {
  static const initialPage = Routes.loginPage;

  static final routes = <GetPage<dynamic>>[
    // ============================================================
    // LOGIN
    // ============================================================

    GetPage(
      name: Routes.loginPage,
      page: () => const LoginPageView(),
      binding: LoginBinding(),
    ),

    // ============================================================
    // DASHBOARD
    // ============================================================

    GetPage(
      name: Routes.dashboard,
      page: () => DashboardView(),
      binding: DashboardBindings(),
    ),

    // ============================================================
    // PURCHASE ORDER
    // ============================================================

    GetPage(
      name: Routes.purchaseOrder,
      page: () => const PurchaseOrderView(),
      binding: PurchaseOrderBinding(),
    ),

    GetPage(
      name: Routes.savedBagPurchases,
      page: () => const SavedBagPurchasesView(),
      binding: BagPurchaseBinding(),
    ),

    GetPage(
      name: Routes.newBagPurchase,
      page: () => const NewBagPurchaseView(),
      binding: BagPurchaseBinding(),
    ),

    GetPage(
      name: Routes.editBagPurchase,
      page: () => const EditBagPurchaseView(),
      binding: BagPurchaseBinding(),
    ),

    GetPage(
      name: Routes.viewBagPurchase,
      page: () => const ViewBagPurchaseView(),
      binding: BagPurchaseBinding(),
    ),

    GetPage(
      name: Routes.newPurchaseOrder,
      page: () => const NewPurchaseOrderView(),
      binding: PurchaseOrderBinding(),
    ),

    GetPage(
      name: Routes.editPurchaseOrder,
      page: () => const EditPurchaseOrderView(),
      binding: PurchaseOrderBinding(),
    ),

    GetPage(
      name: Routes.newSaleOrder,
      page: () => const NewSaleOrderView(),
      binding: SalesOrderBinding(),
    ),

    GetPage(
      name: Routes.savedSalesOrders,
      page: () => const SavedSalesOrdersView(),
      binding: SalesOrderBinding(),
    ),

    GetPage(
      name: Routes.editSalesOrder,
      page: () {
        final arguments = Get.arguments;
        return EditSalesOrderView(
          orderId: arguments is String ? arguments : '',
        );
      },
      binding: SalesOrderBinding(),
    ),

    GetPage(
      name: Routes.viewSalesOrder,
      page: () {
        final arguments = Get.arguments;
        return ViewSalesOrderView(
          orderId: arguments is String ? arguments : '',
        );
      },
      binding: SalesOrderBinding(),
    ),

    GetPage(
      name: Routes.purchaseInvoices,
      page: () => const SavedPurchaseInvoicesView(),
      binding: PurchaseInvoiceBinding(),
    ),

    GetPage(
      name: Routes.savedCustomerReceipts,
      page: () => const SavedCustomerReceiptsView(),
      binding: CustomerReceiptBinding(),
    ),
    GetPage(
      name: Routes.newCustomerReceipt,
      page: () => const NewCustomerReceiptView(),
      binding: CustomerReceiptBinding(),
    ),
    GetPage(
      name: Routes.editCustomerReceipt,
      page: () {
        final arguments = Get.arguments;
        return EditCustomerReceiptView(
          receiptId: arguments is String ? arguments : '',
        );
      },
      binding: CustomerReceiptBinding(),
    ),

    GetPage(
      name: Routes.savedSupplierPayments,
      page: () => const SavedSupplierPaymentsView(),
      binding: SupplierPaymentBinding(),
    ),
    GetPage(
      name: Routes.newSupplierPayment,
      page: () => const NewSupplierPaymentView(),
      binding: SupplierPaymentBinding(),
    ),
    GetPage(
      name: Routes.editSupplierPayment,
      page: () {
        final argument = Get.arguments;
        return EditSupplierPaymentView(
          paymentId: argument is String ? argument : '',
        );
      },
      binding: SupplierPaymentBinding(),
    ),
    GetPage(
      name: Routes.viewSupplierPayment,
      page: () {
        final argument = Get.arguments;
        return ViewSupplierPaymentView(
          paymentId: argument is String ? argument : '',
        );
      },
      binding: SupplierPaymentBinding(),
    ),

    GetPage(
      name: Routes.savedLoadingDispatches,
      page: () => const SavedLoadingDispatchesView(),
      binding: LoadingDispatchBinding(),
    ),
    GetPage(
      name: Routes.newLoadingDispatch,
      page: () => const NewLoadingDispatchView(),
      binding: LoadingDispatchBinding(),
    ),
    GetPage(
      name: Routes.editLoadingDispatch,
      page: () {
        final argument = Get.arguments;
        return EditLoadingDispatchView(
          dispatchId: argument is String ? argument : '',
        );
      },
      binding: LoadingDispatchBinding(),
    ),
    GetPage(
      name: Routes.viewLoadingDispatch,
      page: () {
        final argument = Get.arguments;
        return ViewLoadingDispatchView(
          dispatchId: argument is String ? argument : '',
        );
      },
      binding: LoadingDispatchBinding(),
    ),

    GetPage(
      name: Routes.savedCashBankExpenses,
      page: () => const SavedCashBankExpensesView(),
      binding: CashBankExpensesBinding(),
    ),
    GetPage(
      name: Routes.newCashBankExpense,
      page: () => const NewCashBankExpenseView(),
      binding: CashBankExpensesBinding(),
    ),
    GetPage(
      name: Routes.editCashBankExpense,
      page: () {
        final argument = Get.arguments;
        return EditCashBankExpenseView(
          expenseId: argument is String ? argument : '',
        );
      },
      binding: CashBankExpensesBinding(),
    ),
    GetPage(
      name: Routes.viewCashBankExpense,
      page: () {
        final argument = Get.arguments;
        return ViewCashBankExpenseView(
          expenseId: argument is String ? argument : '',
        );
      },
      binding: CashBankExpensesBinding(),
    ),

    GetPage(
      name: Routes.savedDirectSales,
      page: () => const SavedSalesView(),
      binding: DirectSalesBinding(),
    ),
    GetPage(
      name: Routes.newDirectSale,
      page: () => const NewDirectSaleView(),
      binding: DirectSalesBinding(),
    ),

    GetPage(
      name: Routes.editDirectSale,
      page: () => const EditSalesView(),
      binding: DirectSalesBinding(),
    ),
    GetPage(
      name: Routes.viewDirectSale,
      page: () => const ViewSavedSaleView(),
      binding: DirectSalesBinding(),
    ),

    GetPage(
      name: Routes.newPurchaseInvoice,
      page: () => const NewPurchaseInvoiceView(),
      binding: PurchaseInvoiceBinding(),
    ),

    GetPage(
      name: Routes.editPurchaseInvoice,
      page: () => const EditPurchaseInvoiceView(),
      binding: PurchaseInvoiceBinding(),
    ),

    GetPage(
      name: Routes.purchaseInvoiceDetail,
      page: () => const PurchaseInvoiceDetailView(),
      binding: PurchaseInvoiceBinding(),
    ),
    GetPage(
      name: Routes.purchaseRegisterReport,
      page: () => const PurchaseRegisterView(),
      binding: StatementsReportBinding(StatementsReportType.purchaseRegister),
    ),
    GetPage(
      name: Routes.salesRegisterReport,
      page: () => const SalesRegisterView(),
      binding: StatementsReportBinding(StatementsReportType.salesRegister),
    ),
    GetPage(
      name: Routes.supplierStatementReport,
      page: () => const SupplierStatementView(),
      binding: StatementsReportBinding(StatementsReportType.supplierStatement),
    ),
    GetPage(
      name: Routes.customerStatementReport,
      page: () => const CustomerStatementView(),
      binding: StatementsReportBinding(StatementsReportType.customerStatement),
    ),
    GetPage(
      name: Routes.pendingDispatchReport,
      page: () => const PendingDispatchView(),
      binding: StatementsReportBinding(StatementsReportType.pendingDispatch),
    ),
  ];
}
