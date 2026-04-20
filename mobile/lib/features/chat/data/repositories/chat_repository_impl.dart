import 'package:production_chat_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_history_page.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_sync_result.dart';
import 'package:production_chat_app/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl({required ChatRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final ChatRemoteDataSource _remoteDataSource;

  @override
  Future<ChatHistoryPage> fetchHistory({
    required String accessToken,
    required String conversationId,
    required String currentUserId,
    int? beforeSequence,
    int limit = 20,
  }) async {
    final dto = await _remoteDataSource.fetchHistory(
      accessToken: accessToken,
      conversationId: conversationId,
      beforeSequence: beforeSequence,
      limit: limit,
    );
    return dto.toEntity(currentUserId: currentUserId);
  }

  @override
  Future<ChatSyncResult> syncAfter({
    required String accessToken,
    required String conversationId,
    required int afterSequence,
    int limit = 100,
  }) async {
    final dto = await _remoteDataSource.syncAfter(
      accessToken: accessToken,
      conversationId: conversationId,
      afterSequence: afterSequence,
      limit: limit,
    );
    return dto.toEntity();
  }

  @override
  Future<ChatMessage> sendText({
    required String accessToken,
    required String conversationId,
    required String clientMessageId,
    required String text,
  }) async {
    final dto = await _remoteDataSource.sendText(
      accessToken: accessToken,
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      text: text,
    );
    return dto.toEntity();
  }

  @override
  Future<void> updateReadCursor({
    required String accessToken,
    required String conversationId,
    required int lastReadSequence,
  }) {
    return _remoteDataSource.updateReadCursor(
      accessToken: accessToken,
      conversationId: conversationId,
      lastReadSequence: lastReadSequence,
    );
  }
}
