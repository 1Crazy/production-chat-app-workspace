import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? accessToken,
  }) async {
    final response = await _httpClient.get(
      _buildUri(path),
      headers: _buildHeaders(accessToken: accessToken),
    );
    return _decodeObject(response);
  }

  Future<List<dynamic>> getJsonList(String path, {String? accessToken}) async {
    final response = await _httpClient.get(
      _buildUri(path),
      headers: _buildHeaders(accessToken: accessToken),
    );
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final response = await _httpClient.post(
      _buildUri(path),
      headers: _buildHeaders(accessToken: accessToken),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final response = await _httpClient.patch(
      _buildUri(path),
      headers: _buildHeaders(accessToken: accessToken),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    String? accessToken,
  }) async {
    final response = await _httpClient.delete(
      _buildUri(path),
      headers: _buildHeaders(accessToken: accessToken),
    );
    return _decodeObject(response);
  }

  Uri _buildUri(String path) {
    return Uri.parse('$baseUrl$path');
  }

  Map<String, String> _buildHeaders({String? accessToken}) {
    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final jsonBody = _decodeBody(response);

    if (jsonBody is! Map<String, dynamic>) {
      throw ApiClientException('响应格式不正确', response.statusCode);
    }

    return jsonBody;
  }

  List<dynamic> _decodeList(http.Response response) {
    final jsonBody = _decodeBody(response);

    if (jsonBody is! List<dynamic>) {
      throw ApiClientException('响应格式不正确', response.statusCode);
    }

    return jsonBody;
  }

  dynamic _decodeBody(http.Response response) {
    final rawBody = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(rawBody);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString() ?? '请求失败'
          : '请求失败';
      throw ApiClientException(message, response.statusCode);
    }

    return decoded;
  }
}

class ApiClientException implements Exception {
  const ApiClientException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() {
    return 'ApiClientException(statusCode: $statusCode, message: $message)';
  }
}
