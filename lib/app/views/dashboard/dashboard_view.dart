import 'package:cocoper_mobile/app/views/dashboard/home_view.dart';
import 'package:cocoper_mobile/app/views/dashboard/operations_view.dart';
import 'package:cocoper_mobile/app/views/dashboard/profile_view.dart';
import 'package:cocoper_mobile/app/views/dashboard/statements_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/dashboard/dashboard_controller.dart';
import '../../theme/app_theme.dart';

class DashboardView extends GetView<DashboardController> {
  DashboardView({super.key});

  final List<Widget> _pages = [
    const HomeView(),
    const OperationsView(),
    const StatementsView(),
    ProfileView(),
  ];

  @override
  final DashboardController controller = Get.put(
    DashboardController(),
  );

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomTheme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,

      body: Container(
        decoration: BoxDecoration(
          color: customTheme.bgColor,
        ),
        child: Obx(
          () => _pages[controller.selectedIndex.value],
        ),
      ),

      // Bottom Navigation (kept above the system navigation bar)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Theme(
          data: Theme.of(context).copyWith(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
          ),
          child: Obx(
            () {
              final List<String> labels = [
                'dashboard'.tr,
                'operations'.tr,
                'statements'.tr,
                'profile'.tr,
              ];

              const List<IconData> icons = [
                Icons.home_outlined,
                Icons.grid_view_outlined,
                Icons.pie_chart_outline,
                Icons.person_outline,
              ];

              return Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 3,
                      spreadRadius: 1,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: BottomNavigationBar(
                  elevation: 20,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: AppColors.bgLight,
                  currentIndex: controller.selectedIndex.value,
                  onTap: controller.updateIndex,
                  selectedItemColor: customTheme.primaryColor,
                  unselectedItemColor: customTheme.textLightGray,
                  showUnselectedLabels: true,
                  selectedLabelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  items: List.generate(
                    4,
                    (index) {
                      final isSelected =
                          controller.selectedIndex.value == index;

                      return BottomNavigationBarItem(
                        icon: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          child: Icon(
                            icons[index],
                            size: 23,
                            color: isSelected
                                ? customTheme.primaryColor
                                : customTheme.textLightGray,
                          ),
                        ),
                        label: labels[index],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
