class AppConfig {
  const AppConfig._();

  // Example: https://yourdomain.com/server-manager/api
  // Leave empty to use local SQLite only.
  static const remoteApiBaseUrl = '';

  // Must match API_KEY in api/config.php.
  static const remoteApiKey = 'change-this-secret-key';

  static bool get hasRemoteApi => remoteApiBaseUrl.trim().isNotEmpty;
}
