import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app/config/environment.dart';
import 'app/helpers/shared_preferences.dart';
import 'app/localization/localization.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientation is locked at the platform level (AndroidManifest), so these
  // window calls run without blocking the first frame.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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

  runApp(const MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_restoreSavedLocale());
  });
}

Future<void> _restoreSavedLocale() async {
  try {
    await SharedPrefsHelper.init();
    final localeValues = await Future.wait([
      SharedPrefsHelper.getString(
        SharedPrefsHelper.languageCode,
        defaultValue: 'en',
      ),
      SharedPrefsHelper.getString(
        SharedPrefsHelper.countryCode,
        defaultValue: 'US',
      ),
    ]);

    final languageCode = localeValues[0].isEmpty ? 'en' : localeValues[0];
    final countryCode = localeValues[1].isEmpty ? 'US' : localeValues[1];

    // Keep locale changes reactive without delaying the initial route.
    Get.updateLocale(Locale(languageCode, countryCode));
  } catch (error) {
    debugPrint('Unable to restore saved locale: $error');
  }
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
