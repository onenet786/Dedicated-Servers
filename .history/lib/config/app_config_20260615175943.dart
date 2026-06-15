class AppConfig {
  const AppConfig._();

  // Example: https://yourdomain.com/server-manager/api
  // Leave empty to use local SQLite only.
  static const remoteApiBaseUrl = 'https://servers.flaura.pk';

  // Must match API_KEY in api/config.php.
  static const remoteApiKey = 'Admin786';

  static const whatsappApiBaseUrl = 'https://ledger.flaura.pk';

  // Bearer JWT from POST https://ledger.flaura.pk/api/auth/login.
  static const whatsappBearerToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImE5MTUxM2Q5LTgwZDAtNDUzYy05YWJmLWUwYWVlZTNkOTEzZSIsImVtYWlsIjoiYWFxdWVlbEBnbWFpbC5jb20iLCJyb2xlIjoiYWRtaW4iLCJjb21wYW55SWQiOiI3NmRjZWE3ZC01NjQ3LTQ3NzMtYjNhZC0xNjFiNDY4MTk2M2YiLCJmdWxsTmFtZSI6IkFxZWVsIFVyIFJlaG1hbiIsImlhdCI6MTc4MTUyODE4MiwiZXhwIjoxNzgyMTMyOTgyfQ.77ULS1JPSxgvzeb1wvrZlNR4UUuEKS0bw2TKFQ7EZwI';

  static const whatsappSender = 'reports4';

  static bool get hasRemoteApi => remoteApiBaseUrl.trim().isNotEmpty;

  static bool get hasWhatsAppApi =>
      whatsappApiBaseUrl.trim().isNotEmpty &&
      whatsappBearerToken.trim().isNotEmpty;
}
