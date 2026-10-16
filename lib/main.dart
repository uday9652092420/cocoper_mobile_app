import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app/config/environment.dart';
import 'app/localization/localization.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';

final Stopwatch _startupStopwatch = Stopwatch();

void main() {
  if (!Environment.isProduction) {
    _startupStopwatch.start();
  }

  WidgetsFlutterBinding.ensureInitialized();
  _logStartupTiming('Flutter binding initialized');

  runApp(const MyApp());
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: Environment.appName,

      locale: Localization.defaultLocale,

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
      unknownRoute: GetPage(
        name: '/not-found',
        page: () => const _RouteNotFoundView(),
      ),

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
