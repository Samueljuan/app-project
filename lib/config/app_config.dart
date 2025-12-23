const String kAppsScriptUrl = String.fromEnvironment(
  'APPS_SCRIPT_URL',
  defaultValue: '',
);

const String kLoginUsername =
    String.fromEnvironment('LOGIN_USERNAME', defaultValue: '');
const String kLoginPassword =
    String.fromEnvironment('LOGIN_PASSWORD', defaultValue: '');
const String kLoginPasswordHash =
    String.fromEnvironment('LOGIN_PASSWORD_HASH', defaultValue: '');
