import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/server.dart';

class ServerApi {
  ServerApi({
    http.Client? client,
    String? baseUrl,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? AppConfig.remoteApiBaseUrl).replaceAll(RegExp(r'/+$'), ''),
        _apiKey = apiKey ?? AppConfig.remoteApiKey;

  final http.Client _client;
  final String _baseUrl;
  final String _apiKey;

  bool get isConfigured => _baseUrl.isNotEmpty;

  Uri _uri(String requestPath) => Uri.parse('$_baseUrl$requestPath');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Api-Key': _apiKey,
      };

  Future<List<ManagedServer>> fetchServers() async {
    final response = await _client
        .get(_uri('/servers.php'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    final body = _decode(response);
    final rows = body['data'] as List<dynamic>;
    return rows.cast<Map<String, Object?>>().map(ManagedServer.fromMap).toList();
  }

  Future<void> saveServer(ManagedServer server) async {
    final response = await _client
        .post(
          _uri('/servers.php'),
          headers: _headers,
          body: jsonEncode(server.toMap()),
        )
        .timeout(const Duration(seconds: 12));
    _decode(response);
  }

  Future<void> deleteServer(String id) async {
    final response = await _client
        .delete(
          _uri('/servers.php?id=${Uri.encodeComponent(id)}'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 12));
    _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const ServerApiException(
        'Hosted server returned an invalid response. Check the API URL and PHP error log.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ServerApiException(decoded['error']?.toString() ?? 'Remote server error');
    }
    return decoded;
  }
}

class ServerApiException implements Exception {
  const ServerApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
