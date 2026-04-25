part of 'push_notification_service.dart';

String? _firstNonEmptyString(
  Map<String, dynamic> data,
  List<String> candidates,
) {
  for (final key in candidates) {
    final rawValue = data[key];

    if (rawValue is String && rawValue.trim().isNotEmpty) {
      return rawValue.trim();
    }
  }

  return null;
}

String? _extractConversationId(Map<String, dynamic> data) {
  final directValue = _firstNonEmptyString(data, const [
    'conversationId',
    'conversation_id',
    'chatConversationId',
    'targetConversationId',
  ]);

  if (directValue != null) {
    return directValue;
  }

  final routeLikeValue = _firstNonEmptyString(data, const [
    'route',
    'deepLink',
    'deeplink',
    'link',
  ]);

  if (routeLikeValue == null) {
    return null;
  }

  final uri = Uri.tryParse(routeLikeValue);

  if (uri == null) {
    return _extractConversationIdFromPath(routeLikeValue);
  }

  final queryConversationId = uri.queryParameters['conversationId'];

  if (queryConversationId != null && queryConversationId.trim().isNotEmpty) {
    return queryConversationId.trim();
  }

  return _extractConversationIdFromPath(uri.path);
}

int? _parseInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is String) {
    return int.tryParse(value);
  }

  return null;
}

String? _extractConversationIdFromPath(String path) {
  final normalizedPath = path.trim();

  if (normalizedPath.isEmpty) {
    return null;
  }

  final segments = normalizedPath
      .split('/')
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);

  for (var index = 0; index < segments.length - 1; index += 1) {
    if (segments[index] == 'conversations') {
      return segments[index + 1];
    }
  }

  return null;
}
