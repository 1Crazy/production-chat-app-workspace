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
      final rawMessage = _extractServerMessage(decoded);
      throw ApiClientException(
        _friendlyApiMessage(response.statusCode, rawMessage),
        response.statusCode,
      );
    }

    return decoded;
  }
}

String _extractServerMessage(dynamic decoded) {
  if (decoded is Map<String, dynamic>) {
    final message = decoded['message'];

    if (message is List) {
      final translated = message
          .map((item) => _translateValidationMessage(item.toString()))
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false);

      if (translated.isNotEmpty) {
        return translated.join('；');
      }
    }

    if (message != null) {
      return _translateValidationMessage(message.toString());
    }
  }

  return '请求失败';
}

String formatDisplayError(Object error, {String fallback = '操作失败，请稍后再试'}) {
  if (error is ApiClientException) {
    return error.message;
  }

  if (error is FormatException) {
    return error.message.isEmpty ? fallback : error.message;
  }

  final raw = error.toString().trim();

  if (raw.isEmpty) {
    return fallback;
  }

  for (final prefix in ['Exception: ', 'Error: ']) {
    if (raw.startsWith(prefix)) {
      final cleaned = raw.substring(prefix.length).trim();
      return cleaned.isEmpty ? fallback : cleaned;
    }
  }

  return raw;
}

String _friendlyApiMessage(int statusCode, String message) {
  if (statusCode == 429) {
    switch (message) {
      case '登录尝试过于频繁，请稍后再试':
        return '登录尝试过于频繁，请 10 分钟后再试';
      case '注册尝试过于频繁，请稍后再试':
        return '注册尝试过于频繁，请 10 分钟后再试';
      case '验证码请求过于频繁，请稍后再试':
        return '验证码请求过于频繁，请 10 分钟后再试';
      case '重置密码尝试过于频繁，请稍后再试':
        return '重置密码尝试过于频繁，请 10 分钟后再试';
    }
  }

  return message;
}

String _translateValidationMessage(String rawMessage) {
  final message = rawMessage.trim();

  const exactMappings = {
    'identifier must be a string': '账号格式不正确',
    'purpose must be a string': '验证码用途不正确',
    'code must be a string': '验证码格式不正确',
    'password must be a string': '密码格式不正确',
    'deviceName must be a string': '本机名称格式不正确',
    'nickname must be a string': '昵称格式不正确',
    'purpose must be one of the following values: register, reset-password':
        '验证码用途不正确',
  };

  if (exactMappings.containsKey(message)) {
    return exactMappings[message]!;
  }

  final regexMappings = <RegExp, String>{
    RegExp(r'^identifier must match .+ regular expression$'):
        '账号格式不正确，请输入 3 到 64 位字母、数字或常见符号',
    RegExp(r'^identifier must be longer than or equal to 3 characters$'):
        '账号至少需要 3 个字符',
    RegExp(r'^identifier must be shorter than or equal to 64 characters$'):
        '账号最多支持 64 个字符',
    RegExp(r'^code must be longer than or equal to 4 characters$'):
        '验证码至少需要 4 位',
    RegExp(r'^code must be shorter than or equal to 8 characters$'):
        '验证码最多支持 8 位',
    RegExp(r'^password must be longer than or equal to 8 characters$'):
        '密码至少需要 8 个字符',
    RegExp(r'^password must be shorter than or equal to 72 characters$'):
        '密码最多支持 72 个字符',
    RegExp(r'^password must match .+ regular expression$'): '密码需要同时包含字母和数字',
    RegExp(r'^deviceName must be longer than or equal to 2 characters$'):
        '本机名称至少需要 2 个字符',
    RegExp(r'^deviceName must be shorter than or equal to 48 characters$'):
        '本机名称最多支持 48 个字符',
    RegExp(r'^nickname must be longer than or equal to 2 characters$'):
        '昵称至少需要 2 个字符',
    RegExp(r'^nickname must be shorter than or equal to 32 characters$'):
        '昵称最多支持 32 个字符',
  };

  for (final entry in regexMappings.entries) {
    if (entry.key.hasMatch(message)) {
      return entry.value;
    }
  }

  return message;
}

class ApiClientException implements Exception {
  const ApiClientException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() {
    return message;
  }
}
