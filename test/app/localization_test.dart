import 'package:cocoper_mobile/app/localization/localization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard translations and language options cover supported locales',
      () {
    final translationKeys = Localization().keys;

    expect(translationKeys.keys,
        containsAll(['en_US', 'te_IN', 'hi_IN', 'ar_SA']));
    expect(
      Localization.languageOptions.map((option) => option['code']),
      containsAll(['en', 'te', 'hi', 'ar']),
    );
    expect(translationKeys['te_IN']!['home_tagline'],
        isNot('All coconut operations'));
    expect(translationKeys['hi_IN']!['home_tagline'],
        isNot('All coconut operations'));
    expect(translationKeys['ar_SA']!['home_tagline'],
        isNot('All coconut operations'));
  });
}
