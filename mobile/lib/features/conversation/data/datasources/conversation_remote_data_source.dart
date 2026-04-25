import 'package:production_chat_app/features/conversation/data/dto/conversation_summary_dto.dart';
import 'package:production_chat_app/shared/network/api_client.dart';

class ConversationRemoteDataSource {
  const ConversationRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<ConversationSummaryDto>> fetchRecent({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJsonList(
      '/conversations',
      accessToken: accessToken,
    );

    return response
        .map((item) {
          return ConversationSummaryDto.fromJson(item as Map<String, dynamic>);
        })
        .toList(growable: false);
  }

  Future<ConversationSummaryDto> getConversation({
    required String accessToken,
    required String conversationId,
  }) async {
    final response = await _apiClient.getJson(
      '/conversations/$conversationId',
      accessToken: accessToken,
    );

    return ConversationSummaryDto.fromConversationViewJson(response);
  }

  Future<String> createOrReuseDirectConversation({
    required String accessToken,
    required String targetHandle,
  }) async {
    final response = await _apiClient.postJson(
      '/conversations/direct',
      accessToken: accessToken,
      body: {'targetHandle': targetHandle},
    );

    final conversation = response['conversation'] as Map<String, dynamic>;
    return conversation['id'] as String;
  }

  Future<String> createGroupConversation({
    required String accessToken,
    required String title,
    required List<String> memberHandles,
  }) async {
    final response = await _apiClient.postJson(
      '/conversations/group',
      accessToken: accessToken,
      body: {
        'title': title,
        'memberHandles': memberHandles,
      },
    );

    final conversation = response['conversation'] as Map<String, dynamic>;
    return conversation['id'] as String;
  }
}
