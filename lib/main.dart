import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:get/get.dart';

import 'app/config/environment.dart';
import 'app/controllers/auth/lang_selection_controller.dart';
import 'app/helpers/shared_preferences.dart';
import 'app/localization/localization.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';

final Stopwatch _startupStopwatch = Stopwatch();

Future<void> main() async {
  if (!Environment.isProduction) {
    _startupStopwatch.start();
  }

  WidgetsFlutterBinding.ensureInitialized();
  _logStartupTiming('Flutter binding initialized');

  await SharedPrefsHelper.init();
  final localeValues = await Future.wait([
    SharedPrefsHelper.getString(
      SharedPrefsHelper.languageCode,
      defaultValue: Localization.defaultLocale.languageCode,
    ),
    SharedPrefsHelper.getString(
      SharedPrefsHelper.countryCode,
      defaultValue: Localization.defaultLocale.countryCode ?? '',
    ),
  ]);
  final savedLocale = Locale(localeValues[0], localeValues[1]);
  final initialLocale = Localization.supportedLocales.contains(savedLocale)
      ? savedLocale
      : Localization.defaultLocale;

  runApp(MyApp(initialLocale: initialLocale));
  _logStartupTiming('runApp invoked');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _logStartupTiming('First frame built');
    _configureSystemUi();
  });
}

void _configureSystemUi() {
  // AndroidManifest already locks portrait orientation. Defer system-bar
  // channel calls until after the first frame so they cannot delay first paint.
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
}

void _logStartupTiming(String step) {
  if (!Environment.isProduction) {
    debugPrint('[startup] ${_startupStopwatch.elapsedMilliseconds} ms: $step');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.initialLocale = Localization.defaultLocale,
  });

  final Locale initialLocale;

  @override
  Widget build(BuildContext context) {
    final languageController = Get.isRegistered<LangSelectionController>()
        ? Get.find<LangSelectionController>()
        : Get.put(LangSelectionController(), permanent: true);

    return Obx(() {
      final supportedLocales = languageController.supportedLocales;
      return GetMaterialApp(
        title: Environment.appName,

        locale: Get.locale ?? initialLocale,

        fallbackLocale: Localization.fallbackLocale,

        translations: Localization(),

        supportedLocales: supportedLocales,
        localeResolutionCallback: (locale, supportedLocales) =>
            locale ?? initialLocale,

        localizationsDelegates: const [
          _EnglishFallbackMaterialLocalizationsDelegate(),
          _EnglishFallbackCupertinoLocalizationsDelegate(),
        ],

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
        unknownRoute: GetPage(
          name: '/not-found',
          page: () => const _RouteNotFoundView(),
        ),

        builder: (context, child) {
          if (child == null) {
            return const SizedBox.shrink();
          }

          final locale = Get.locale ?? initialLocale;
          return Directionality(
            textDirection: Localization.isRightToLeft(locale)
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: child,
          );
        },
      );
    });
  }
}

class _EnglishFallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _EnglishFallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.delegate.load(
        Localization.localeEnglishUS,
      );

  @override
  bool shouldReload(
    covariant _EnglishFallbackMaterialLocalizationsDelegate old,
  ) =>
      false;
}

class _EnglishFallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _EnglishFallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.delegate.load(
        Localization.localeEnglishUS,
      );

  @override
  bool shouldReload(
    covariant _EnglishFallbackCupertinoLocalizationsDelegate old,
  ) =>
      false;
}

class _RouteNotFoundView extends StatelessWidget {
  const _RouteNotFoundView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route_outlined, size: 40),
                SizedBox(height: 12),
                Text(
                  'This page could not be found.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
