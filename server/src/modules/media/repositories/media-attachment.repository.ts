import type { MediaAttachmentEntity } from '../entities/media-attachment.entity';

export abstract class MediaAttachmentRepository {
  abstract createPendingAttachment(params: {
    id: string;
    ownerId: string;
    conversationId: string;
    purpose: MediaAttachmentEntity['purpose'];
    attachmentKind: MediaAttachmentEntity['attachmentKind'];
    objectKey: string;
    fileName: string;
    mimeType: string;
    sizeBytes: number;
  }): Promise<MediaAttachmentEntity>;

  abstract getAttachmentOrThrow(
    attachmentId: string,
  ): Promise<MediaAttachmentEntity>;

  abstract saveAttachment(entity: MediaAttachmentEntity): Promise<void>;
}
