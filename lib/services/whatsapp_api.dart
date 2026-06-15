import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class WhatsAppApi {
  WhatsAppApi({
    http.Client? client,
    String? baseUrl,
    String? bearerToken,
    String? sender,
  })  : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? AppConfig.whatsappApiBaseUrl).replaceAll(RegExp(r'/+$'), ''),
        _bearerToken = bearerToken ?? AppConfig.whatsappBearerToken,
        _sender = sender ?? AppConfig.whatsappSender;

  final http.Client _client;
  final String _baseUrl;
  final String _bearerToken;
  final String _sender;

  bool get isConfigured =>
      _baseUrl.trim().isNotEmpty && _bearerToken.trim().isNotEmpty;

  Future<void> sendMessage({
    required String phone,
    required String message,
    required String clientName,
    String event = 'server.renewal_reminder',
  }) async {
    if (!isConfigured) {
      throw const WhatsAppApiException('WhatsApp API token is not configured.');
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/whatsapp/send'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_bearerToken',
      },
      body: jsonEncode({
        'phone': phone,
        'message': message,
        'event': event,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'sender': _sender,
        'client': {
          'name': clientName,
          'phone': phone,
        },
      }),
    );

    final decoded = _decode(response);
    if (decoded['success'] == false) {
      throw const WhatsAppApiException('WhatsApp gateway did not send the message.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['error']?.toString() ?? 'WhatsApp gateway error';
      throw WhatsAppApiException(message);
    }
    return decoded;
  }
}

class WhatsAppApiException implements Exception {
  const WhatsAppApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
