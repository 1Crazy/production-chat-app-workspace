import '../entities/media_attachment.dart';

abstract class MediaRepository {
  Future<List<MediaAttachment>> fetchPending();
}
