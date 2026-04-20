import 'package:production_chat_app/features/conversation/data/datasources/conversation_remote_data_source.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/conversation/domain/repositories/conversation_repository.dart';

class ConversationRepositoryImpl implements ConversationRepository {
  const ConversationRepositoryImpl({
    required ConversationRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final ConversationRemoteDataSource _remoteDataSource;

  @override
  Future<List<ConversationSummary>> fetchRecent({
    required String accessToken,
  }) async {
    final dtos = await _remoteDataSource.fetchRecent(accessToken: accessToken);
    return dtos.map((dto) => dto.toEntity()).toList(growable: false);
  }

  @override
  Future<ConversationSummary?> findById({
    required String accessToken,
    required String conversationId,
  }) async {
    try {
      final dto = await _remoteDataSource.getConversation(
        accessToken: accessToken,
        conversationId: conversationId,
      );
      return dto.toEntity();
    } catch (_) {
      final conversations = await fetchRecent(accessToken: accessToken);

      for (final conversation in conversations) {
        if (conversation.id == conversationId) {
          return conversation;
        }
      }

      return null;
    }
  }

  @override
  Future<String> createOrReuseDirectConversation({
    required String accessToken,
    required String targetHandle,
  }) {
    return _remoteDataSource.createOrReuseDirectConversation(
      accessToken: accessToken,
      targetHandle: targetHandle,
    );
  }
}
