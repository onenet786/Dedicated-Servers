class AppConfig {
  const AppConfig._();

  // Example: https://yourdomain.com/server-manager/api
  // Leave empty to use local SQLite only.
  static const remoteApiBaseUrl = 'https://servers.flaura.pk';

  // Must match API_KEY in api/config.php.
  static const remoteApiKey = 'Admin786';

  static const whatsappWebhookUrl =
      'http://f:5678/webhook/whatsapp-invoice';

  static const whatsappSender = 'reports4';

  static bool get hasRemoteApi => remoteApiBaseUrl.trim().isNotEmpty;

  static bool get hasWhatsAppApi =>
      whatsappWebhookUrl.trim().isNotEmpty;
}
