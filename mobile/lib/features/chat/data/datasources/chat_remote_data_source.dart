import 'package:production_chat_app/features/chat/data/dto/chat_history_page_dto.dart';
import 'package:production_chat_app/features/chat/data/dto/chat_message_dto.dart';
import 'package:production_chat_app/shared/network/api_client.dart';

class ChatRemoteDataSource {
  const ChatRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ChatHistoryPageDto> fetchHistory({
    required String accessToken,
    required String conversationId,
    int? beforeSequence,
    int limit = 20,
  }) async {
    final query = <String>[
      'limit=$limit',
      if (beforeSequence != null) 'beforeSequence=$beforeSequence',
    ].join('&');
    final response = await _apiClient.getJson(
      '/messages/conversations/$conversationId/history?$query',
      accessToken: accessToken,
    );

    return ChatHistoryPageDto.fromJson(response);
  }

  Future<ChatSyncResultDto> syncAfter({
    required String accessToken,
    required String conversationId,
    required int afterSequence,
    int limit = 100,
  }) async {
    final response = await _apiClient.getJson(
      '/messages/conversations/$conversationId/sync?afterSequence=$afterSequence&limit=$limit',
      accessToken: accessToken,
    );

    return ChatSyncResultDto.fromJson(response);
  }

  Future<ChatMessageDto> sendText({
    required String accessToken,
    required String conversationId,
    required String clientMessageId,
    required String text,
  }) async {
    final response = await _apiClient.postJson(
      '/messages',
      accessToken: accessToken,
      body: {
        'conversationId': conversationId,
        'clientMessageId': clientMessageId,
        'type': 'text',
        'text': text,
      },
    );

    return ChatMessageDto.fromJson(response['message'] as Map<String, dynamic>);
  }

  Future<void> updateReadCursor({
    required String accessToken,
    required String conversationId,
    required int lastReadSequence,
  }) async {
    await _apiClient.postJson(
      '/conversations/$conversationId/read-cursor',
      accessToken: accessToken,
      body: {'lastReadSequence': lastReadSequence},
    );
  }
}
