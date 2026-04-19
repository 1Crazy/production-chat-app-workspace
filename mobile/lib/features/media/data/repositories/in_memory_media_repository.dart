import 'package:production_chat_app/features/media/domain/entities/media_attachment.dart';
import 'package:production_chat_app/features/media/domain/repositories/media_repository.dart';

class InMemoryMediaRepository implements MediaRepository {
  @override
  Future<List<MediaAttachment>> fetchPending() async {
    return const [];
  }
}
