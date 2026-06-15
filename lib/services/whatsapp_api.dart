import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class WhatsAppApi {
  WhatsAppApi({
    http.Client? client,
    String? webhookUrl,
    String? sender,
  })  : _client = client ?? http.Client(),
        _webhookUrl = webhookUrl ?? AppConfig.whatsappWebhookUrl,
        _sender = sender ?? AppConfig.whatsappSender;

  final http.Client _client;
  final String _webhookUrl;
  final String _sender;

  bool get isConfigured => _webhookUrl.trim().isNotEmpty;

  Future<void> sendMessage({
    required String phone,
    required String message,
    required String clientName,
    String? pdfBase64,
    String? pdfFileName,
    String event = 'server.renewal_reminder',
  }) async {
    if (!isConfigured) {
      throw const WhatsAppApiException('WhatsApp webhook URL is not configured.');
    }

    final response = await _client
        .post(
          Uri.parse(_webhookUrl),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'phone': phone,
            'message': message,
            'event': event,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'sender': _sender,
            if (pdfBase64 != null && pdfBase64.isNotEmpty) 'pdf_base64': pdfBase64,
            if (pdfFileName != null && pdfFileName.isNotEmpty)
              'invoice': {
                'filename': pdfFileName,
                'pdf': pdfBase64,
              },
            'client': {
              'name': clientName,
              'phone': phone,
            },
          }),
        )
        .timeout(const Duration(seconds: 30));

    final decoded = _decode(response);
    if (decoded['success'] == false) {
      throw const WhatsAppApiException('WhatsApp gateway did not send the message.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Object? decoded;
    try {
      decoded = response.body.trim().isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } catch (_) {
      decoded = <String, dynamic>{'message': response.body};
    }

    final body = switch (decoded) {
      final Map<String, dynamic> map => map,
      final List<dynamic> list when list.isNotEmpty && list.first is Map<String, dynamic> =>
        list.first as Map<String, dynamic>,
      _ => <String, dynamic>{},
    };

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body['error']?.toString() ??
          body['message']?.toString() ??
          'WhatsApp webhook error';
      throw WhatsAppApiException(message);
    }
    return body;
  }
}

class WhatsAppApiException implements Exception {
  const WhatsAppApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
