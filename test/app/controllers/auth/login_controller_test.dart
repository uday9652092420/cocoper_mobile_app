import 'package:cocoper_mobile/app/controllers/auth/login_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoginController controller;

  setUp(() {
    controller = LoginController();
  });

  tearDown(() {
    controller.onClose();
  });

  test('accepts usernames supported by the login API', () {
    expect(controller.validateEmail('bunny'), isNull);
  });

  test('rejects an empty login identifier', () {
    expect(
      controller.validateEmail('  '),
      'Please enter your email or username',
    );
  });
}
