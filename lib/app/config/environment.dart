final class Environment {
  static const appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'COCOPER',
  );
  static const isProduction = bool.fromEnvironment(
    'IS_PRODUCTION',
    defaultValue: bool.fromEnvironment('dart.vm.product'),
  );
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: isProduction
        ? 'https://cocoper.com/api/'
        : 'https://uat.cocoper.com/api/',
  );
}
