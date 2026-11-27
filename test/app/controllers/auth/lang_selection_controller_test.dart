import 'package:cocoper_mobile/app/controllers/auth/lang_selection_controller.dart';
import 'package:cocoper_mobile/app/localization/localization.dart';
import 'package:cocoper_mobile/app/models/app_language.dart';
import 'package:cocoper_mobile/app/repositories/language_repository.dart';
import 'package:cocoper_mobile/app/helpers/shared_preferences.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String organizationId;
  late bool authenticated;
  late _FakeLanguageRepository repository;
  late LangSelectionController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      SharedPrefsHelper.languageCode: 'en',
      SharedPrefsHelper.countryCode: 'US',
    });
    await SharedPrefsHelper.init();
    Get.testMode = true;
    Get.clearTranslations();
    Get.locale = null;
    Get.fallbackLocale = null;
    organizationId = '';
    authenticated = false;
    repository = _FakeLanguageRepository();
    controller = LangSelectionController(
      repository: repository,
      readOrganizationId: () async => organizationId,
      hasAuthenticatedSession: () async => authenticated,
      onLanguageError: (_) {},
    );
  });

  tearDown(() async {
    Get.clearTranslations();
    Get.reset();
  });

  Future<void> mount(WidgetTester tester) async {
    Get.put<LangSelectionController>(controller, permanent: true);
    await tester.pumpWidget(
      GetMaterialApp(
        locale: Localization.localeEnglishUS,
        fallbackLocale: Localization.fallbackLocale,
        translations: Localization(),
        supportedLocales: Localization.supportedLocales,
        localizationsDelegates: const [
          _TestMaterialFallbackDelegate(),
          _TestCupertinoFallbackDelegate(),
        ],
        home: const _TranslationProbe(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<T> pumpUntilDone<T>(
    WidgetTester tester,
    Future<T> action,
  ) async {
    await tester.pumpAndSettle();
    final result = await action;
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('loads online languages and activates selected translations',
      (tester) async {
    await mount(tester);
    organizationId = 'org-a';
    authenticated = true;

    await pumpUntilDone(
      tester,
      controller.refreshForAuthenticatedSession(showErrors: false),
    );
    expect(
        controller.languages.map((language) => language.code), contains('te'));
    expect(repository.languageOrganizationIds, contains('org-a'));

    final changed = await pumpUntilDone(
      tester,
      controller.selectLanguage('te'),
    );

    expect(changed, isTrue);
    expect(Get.locale, Localization.localeTeluguIN);
    expect(find.text('org-a-te'), findsOneWidget);
    expect(
      await SharedPrefsHelper.getString(SharedPrefsHelper.languageCode),
      'te',
    );
  });

  testWidgets('keeps current locale and preference when translations fail',
      (tester) async {
    await mount(tester);
    organizationId = 'org-a';
    authenticated = true;
    await pumpUntilDone(
      tester,
      controller.refreshForAuthenticatedSession(showErrors: false),
    );

    repository.failTranslations = true;
    final changed = await pumpUntilDone(
      tester,
      controller.selectLanguage('te'),
    );

    expect(changed, isFalse);
    expect(Get.locale, Localization.localeEnglishUS);
    expect(
      await SharedPrefsHelper.getString(SharedPrefsHelper.languageCode),
      'en',
    );
    expect(controller.languageError.value, isNotEmpty);
  });

  testWidgets('organization changes discard prior translations',
      (tester) async {
    await mount(tester);
    organizationId = 'org-a';
    authenticated = true;
    await pumpUntilDone(
      tester,
      controller.refreshForAuthenticatedSession(showErrors: false),
    );
    await pumpUntilDone(tester, controller.selectLanguage('te'));
    expect(find.text('org-a-te'), findsOneWidget);

    organizationId = 'org-b';
    await pumpUntilDone(tester, controller.onAuthenticatedSessionChanged());

    expect(repository.translationOrganizationIds, contains('org-b'));
    expect(find.text('org-b-te'), findsOneWidget);
    expect(find.text('org-a-te'), findsNothing);
  });

  testWidgets('uses bundled language options when online loading fails',
      (tester) async {
    await mount(tester);
    organizationId = 'org-a';
    authenticated = true;
    repository.failLanguages = true;

    await pumpUntilDone(
      tester,
      controller.refreshForAuthenticatedSession(showErrors: false),
    );

    expect(controller.languages.map((language) => language.code),
        containsAll(['en', 'te', 'hi', 'ar']));
    expect(controller.languageError.value, contains('Built-in languages'));
  });
}

class _FakeLanguageRepository extends LanguageRepository {
  _FakeLanguageRepository() : super();

  bool failLanguages = false;
  bool failTranslations = false;
  final languageOrganizationIds = <String>[];
  final translationOrganizationIds = <String>[];

  @override
  Future<List<AppLanguage>> fetchLanguages({
    required String organizationId,
  }) async {
    languageOrganizationIds.add(organizationId);
    if (failLanguages) {
      throw const FormatException('language list unavailable');
    }
    return const [
      AppLanguage(code: 'en', name: 'English'),
      AppLanguage(code: 'te', name: 'తెలుగు'),
    ];
  }

  @override
  Future<Map<String, String>> fetchTranslations({
    required String organizationId,
    required String languageCode,
  }) async {
    translationOrganizationIds.add(organizationId);
    if (failTranslations) {
      throw Exception('translations unavailable');
    }
    return {
      for (final key in Localization.requiredResourceKeys)
        key: '$organizationId-$languageCode-$key',
      'home_tagline': '$organizationId-$languageCode',
    };
  }
}

class _TestMaterialFallbackDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _TestMaterialFallbackDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.delegate.load(
        Localization.localeEnglishUS,
      );

  @override
  bool shouldReload(_TestMaterialFallbackDelegate old) => false;
}

class _TestCupertinoFallbackDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _TestCupertinoFallbackDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.delegate.load(
        Localization.localeEnglishUS,
      );

  @override
  bool shouldReload(_TestCupertinoFallbackDelegate old) => false;
}

class _TranslationProbe extends StatelessWidget {
  const _TranslationProbe();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Text('home_tagline'.tr),
      );
}
