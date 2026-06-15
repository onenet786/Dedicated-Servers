class AppConfig {
  const AppConfig._();

  // Example: https://yourdomain.com/server-manager/api
  // Leave empty to use local SQLite only.
  static const remoteApiBaseUrl = 'https://servers.flaura.pk';

  // Must match API_KEY in api/config.php.
  static const remoteApiKey = 'Admin786';

  static const whatsappApiBaseUrl = 'https://ledger.flaura.pk';

  // Bearer JWT from POST https://ledger.flaura.pk/api/auth/login.
  static const whatsappBearerToken = '';

  static const whatsappSender = 'reports4';

  static bool get hasRemoteApi => remoteApiBaseUrl.trim().isNotEmpty;

  static bool get hasWhatsAppApi =>
      whatsappApiBaseUrl.trim().isNotEmpty &&
      whatsappBearerToken.trim().isNotEmpty;
}
