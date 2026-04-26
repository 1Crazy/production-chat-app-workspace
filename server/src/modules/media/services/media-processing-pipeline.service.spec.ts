import type { MediaAttachmentEntity } from '../entities/media-attachment.entity';
import { MediaAttachmentRepository } from '../repositories/media-attachment.repository';

import { MediaObjectStorageService } from './media-object-storage.service';
import { MediaProcessingPipelineService } from './media-processing-pipeline.service';

class InMemoryMediaAttachmentRepository extends MediaAttachmentRepository {
  private readonly attachmentsById = new Map<string, MediaAttachmentEntity>();

  override async createPendingAttachment(params: {
    id: string;
    ownerId: string;
    conversationId: string;
    purpose: MediaAttachmentEntity['purpose'];
    attachmentKind: MediaAttachmentEntity['attachmentKind'];
    objectKey: string;
    fileName: string;
    mimeType: string;
    sizeBytes: number;
  }): Promise<MediaAttachmentEntity> {
    const now = new Date();
    const attachment: MediaAttachmentEntity = {
      id: params.id,
      ownerId: params.ownerId,
      conversationId: params.conversationId,
      purpose: params.purpose,
      attachmentKind: params.attachmentKind,
      status: 'processing',
      objectKey: params.objectKey,
      fileName: params.fileName,
      mimeType: params.mimeType,
      sizeBytes: params.sizeBytes,
      previewObjectKey: null,
      failureReason: null,
      uploadedAt: now,
      confirmedAt: now,
      createdAt: now,
      updatedAt: now,
    };

    this.attachmentsById.set(attachment.id, attachment);
    return attachment;
  }

  override async getAttachmentOrThrow(
    attachmentId: string,
  ): Promise<MediaAttachmentEntity> {
    const attachment = this.attachmentsById.get(attachmentId);

    if (!attachment) {
      throw new Error('附件不存在');
    }

    return attachment;
  }

  override async saveAttachment(entity: MediaAttachmentEntity): Promise<void> {
    this.attachmentsById.set(entity.id, entity);
  }
}

class FakeMediaObjectStorageService extends MediaObjectStorageService {
  objectExists = true;
  objectBytes = Buffer.from('89504e470d0a1a0a0000000d49484452', 'hex');

  override async createSignedUpload(): Promise<{
    uploadUrl: string;
    expiresAt: Date;
    requiredHeaders: Record<string, string>;
  }> {
    throw new Error('not used');
  }

  override async createSignedDownload(): Promise<{
    downloadUrl: string;
    expiresAt: Date;
  }> {
    throw new Error('not used');
  }

  override async inspectObject(): Promise<{
    exists: boolean;
    contentType: string | null;
    sizeBytes: number | null;
  }> {
    return {
      exists: this.objectExists,
      contentType: 'image/png',
      sizeBytes: 1024,
    };
  }

  override async readObjectBytes(): Promise<Buffer> {
    return this.objectBytes;
  }
}

describe('MediaProcessingPipelineService', () => {
  it('should advance processing attachments to ready when object is valid', async () => {
    const repository = new InMemoryMediaAttachmentRepository();
    const objectStorage = new FakeMediaObjectStorageService();
    const service = new MediaProcessingPipelineService(repository, objectStorage);
    const attachment = await repository.createPendingAttachment({
      id: 'attachment-1',
      ownerId: 'user-1',
      conversationId: 'conversation-1',
      purpose: 'chat-message',
      attachmentKind: 'image',
      objectKey: 'chat-media/object-1',
      fileName: 'photo.png',
      mimeType: 'image/png',
      sizeBytes: 1024,
    });

    await service.processAttachment(attachment.id);

    const updatedAttachment = await repository.getAttachmentOrThrow(
      attachment.id,
    );
    expect(updatedAttachment.status).toBe('ready');
  });

  it('should mark attachments as failed with reason', async () => {
    const repository = new InMemoryMediaAttachmentRepository();
    const objectStorage = new FakeMediaObjectStorageService();
    const service = new MediaProcessingPipelineService(repository, objectStorage);
    const attachment = await repository.createPendingAttachment({
      id: 'attachment-2',
      ownerId: 'user-1',
      conversationId: 'conversation-1',
      purpose: 'chat-message',
      attachmentKind: 'file',
      objectKey: 'chat-media/object-2',
      fileName: 'report.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 1024,
    });

    await service.markFailed(attachment.id, 'scan failed');

    const failedAttachment = await repository.getAttachmentOrThrow(
      attachment.id,
    );
    expect(failedAttachment.status).toBe('failed');
    expect(failedAttachment.failureReason).toBe('scan failed');
  });

  it('should reject invalid object signatures during async processing', async () => {
    const repository = new InMemoryMediaAttachmentRepository();
    const objectStorage = new FakeMediaObjectStorageService();
    objectStorage.objectBytes = Buffer.from('%PDF-1.7\n');
    const service = new MediaProcessingPipelineService(repository, objectStorage);
    const attachment = await repository.createPendingAttachment({
      id: 'attachment-3',
      ownerId: 'user-1',
      conversationId: 'conversation-1',
      purpose: 'chat-message',
      attachmentKind: 'image',
      objectKey: 'chat-media/object-3',
      fileName: 'photo.png',
      mimeType: 'image/png',
      sizeBytes: 1024,
    });

    await expect(service.processAttachment(attachment.id)).rejects.toThrow(
      '附件对象内容在异步处理阶段不匹配',
    );
  });
});
