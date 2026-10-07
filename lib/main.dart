import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app/config/environment.dart';
import 'app/helpers/shared_preferences.dart';
import 'app/localization/localization.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientation is locked at the platform level (AndroidManifest), so these
  // window calls run without blocking the first frame.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await SharedPrefsHelper.init();

  // Draw behind the status and navigation bars so the UI fills the whole screen
  // (Android 15+ letterboxes apps that are not edge-to-edge).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  String languageCode = await SharedPrefsHelper.getString(
    SharedPrefsHelper.languageCode,
    defaultValue: 'en',
  );

  if (languageCode.isEmpty) {
    languageCode = 'en';
  }

  String countryCode = await SharedPrefsHelper.getString(
    SharedPrefsHelper.countryCode,
    defaultValue: 'US',
  );

  if (countryCode.isEmpty) {
    countryCode = 'US';
  }

  // Set the initial locale reactively so Get.updateLocale() (used by the
  // language picker and language-selection screen) can switch the whole app
  // later. Passing a fixed `locale:` to GetMaterialApp would prevent that.
  Get.updateLocale(Locale(languageCode, countryCode));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: Environment.appName,

      fallbackLocale: Localization.fallbackLocale,

      translations: Localization(),

      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,

      // ----------------------------------------------------------
      // INITIAL ROUTE
      // ----------------------------------------------------------

      initialRoute: AppPages.initialPage,

      // ----------------------------------------------------------
      // GETX ROUTES
      // ----------------------------------------------------------

      getPages: AppPages.routes,

      // ----------------------------------------------------------
      // PREVENT SYSTEM FONT SCALING FROM CHANGING UI
      // ----------------------------------------------------------

      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child,
        );
      },
    );
  }
}
