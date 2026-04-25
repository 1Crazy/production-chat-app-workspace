import { PayloadTooLargeException } from '@nestjs/common';

import type { MediaAttachmentEntity } from '../entities/media-attachment.entity';
import { MediaAttachmentRepository } from '../repositories/media-attachment.repository';

import { MediaFilePolicyService } from './media-file-policy.service';
import { MediaObjectStorageService } from './media-object-storage.service';
import type { MediaProcessingWorkerService } from './media-processing-worker.service';
import { MediaService } from './media.service';

import type { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { InMemoryChatModelRepository } from '@app/infra/database/repositories/in-memory-chat-model.repository';

class FakeMediaObjectStorageService extends MediaObjectStorageService {
  private readonly uploadedObjects = new Map<
    string,
    {
      contentType: string;
      sizeBytes: number;
    }
  >();

  override async createSignedUpload(params: {
    objectKey: string;
    mimeType: string;
    expiresInSeconds: number;
  }): Promise<{
    uploadUrl: string;
    expiresAt: Date;
    requiredHeaders: Record<string, string>;
  }> {
    this.uploadedObjects.set(params.objectKey, {
      contentType: params.mimeType,
      sizeBytes: 1024,
    });

    return {
      uploadUrl:
        'http://localhost:9000/chat-dev/' +
        params.objectKey +
        '?signature=test-signature',
      expiresAt: new Date(Date.now() + params.expiresInSeconds * 1000),
      requiredHeaders: {
        'content-type': params.mimeType,
      },
    };
  }

  override async createSignedDownload(params: {
    objectKey: string;
    fileName: string;
    mimeType: string;
    expiresInSeconds: number;
  }): Promise<{
    downloadUrl: string;
    expiresAt: Date;
  }> {
    return {
      downloadUrl:
        'http://localhost:9000/chat-dev/' +
        params.objectKey +
        '?signature=download-signature',
      expiresAt: new Date(Date.now() + params.expiresInSeconds * 1000),
    };
  }

  override async inspectObject(params: {
    objectKey: string;
  }): Promise<{
    exists: boolean;
    contentType: string | null;
    sizeBytes: number | null;
  }> {
    const object = this.uploadedObjects.get(params.objectKey);

    return {
      exists: object != null,
      contentType: object?.contentType ?? null,
      sizeBytes: object?.sizeBytes ?? null,
    };
  }
}

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
      status: 'pending_upload',
      objectKey: params.objectKey,
      fileName: params.fileName,
      mimeType: params.mimeType,
      sizeBytes: params.sizeBytes,
      previewObjectKey: null,
      failureReason: null,
      uploadedAt: null,
      confirmedAt: null,
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
    entity.updatedAt = new Date();
    this.attachmentsById.set(entity.id, entity);
  }
}

class FakeMediaProcessingWorkerService {
  finalizedJobs: string[] = [];

  async enqueueAttachment(
    attachmentId: string,
    attachmentKind: string,
  ): Promise<void> {
    this.finalizedJobs.push(`${attachmentId}:${attachmentKind}`);
  }
}

describe('MediaService', () => {
  async function createFixture() {
    const chatModelRepository = new InMemoryChatModelRepository();
    const mediaAttachmentRepository = new InMemoryMediaAttachmentRepository();
    const mediaProcessingWorkerService = new FakeMediaProcessingWorkerService();
    const rateLimitService = {
      consumeOrThrow: jest.fn().mockResolvedValue(undefined),
    } as unknown as RateLimitService;
    const service = new MediaService(
      new FakeMediaObjectStorageService(),
      mediaAttachmentRepository,
      mediaProcessingWorkerService as unknown as MediaProcessingWorkerService,
      chatModelRepository,
      rateLimitService,
      new MediaFilePolicyService(),
    );
    const conversation = await chatModelRepository.createConversation({
      type: 'direct',
      createdBy: 'user-1',
      memberIds: ['user-1', 'user-2'],
    });

    return {
      chatModelRepository,
      conversation,
      mediaAttachmentRepository,
      mediaProcessingWorkerService,
      rateLimitService,
      service,
    };
  }

  it('should issue a signed upload token for a supported image', async () => {
    const fixture = await createFixture();

    const result = await fixture.service.requestUploadToken('user-1', {
      purpose: 'chat-message',
      conversationId: fixture.conversation.id,
      fileName: 'photo.png',
      mimeType: 'image/png',
      sizeBytes: 1024,
    });

    expect(result.method).toBe('PUT');
    expect(result.attachmentKind).toBe('image');
    expect(result.attachmentId).toEqual(expect.any(String));
    expect(result.objectKey).toContain(
      `chat-media/${fixture.conversation.id}/image/`,
    );
    expect(result.requiredHeaders['content-type']).toBe('image/png');
    expect(result.confirmPayload).toMatchObject({
      attachmentId: result.attachmentId,
      conversationId: fixture.conversation.id,
      fileName: 'photo.png',
      mimeType: 'image/png',
      sizeBytes: 1024,
      purpose: 'chat-message',
      attachmentKind: 'image',
    });
  });

  it('should reject upload token requests from non-members', async () => {
    const fixture = await createFixture();

    await expect(
      fixture.service.requestUploadToken('outsider', {
        purpose: 'chat-message',
        conversationId: fixture.conversation.id,
        fileName: 'photo.png',
        mimeType: 'image/png',
        sizeBytes: 1024,
      }),
    ).rejects.toThrow('你不是该会话成员');
  });

  it('should reject oversized files by policy', async () => {
    const fixture = await createFixture();

    await expect(
      fixture.service.requestUploadToken('user-1', {
        purpose: 'chat-message',
        conversationId: fixture.conversation.id,
        fileName: 'archive.zip',
        mimeType: 'application/zip',
        sizeBytes: 60 * 1024 * 1024,
      }),
    ).rejects.toBeInstanceOf(PayloadTooLargeException);
  });

  it('should confirm uploads into processing state and enqueue async work', async () => {
    const fixture = await createFixture();
    const fileToken = await fixture.service.requestUploadToken('user-1', {
      purpose: 'chat-message',
      conversationId: fixture.conversation.id,
      fileName: 'doc.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 1024,
    });
    const imageToken = await fixture.service.requestUploadToken('user-1', {
      purpose: 'chat-message',
      conversationId: fixture.conversation.id,
      fileName: 'photo.png',
      mimeType: 'image/png',
      sizeBytes: 1024,
    });

    const readyAttachment = await fixture.service.confirmUpload('user-1', {
      attachmentId: fileToken.attachmentId,
      objectKey: fileToken.objectKey,
    });
    const processingAttachment = await fixture.service.confirmUpload('user-1', {
      attachmentId: imageToken.attachmentId,
      objectKey: imageToken.objectKey,
    });

    expect(readyAttachment.status).toBe('processing');
    expect(readyAttachment.confirmedAt).toEqual(expect.any(String));
    expect(processingAttachment.status).toBe('processing');
    expect(fixture.mediaProcessingWorkerService.finalizedJobs).toEqual([
      `${fileToken.attachmentId}:file`,
      `${imageToken.attachmentId}:image`,
    ]);
  });

  it('should return signed access only for authorized members when ready', async () => {
    const fixture = await createFixture();
    const token = await fixture.service.requestUploadToken('user-1', {
      purpose: 'chat-message',
      conversationId: fixture.conversation.id,
      fileName: 'doc.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 1024,
    });

    await fixture.service.confirmUpload('user-1', {
      attachmentId: token.attachmentId,
      objectKey: token.objectKey,
    });
    const attachment = await fixture.mediaAttachmentRepository.getAttachmentOrThrow(
      token.attachmentId,
    );
    attachment.status = 'ready';
    await fixture.mediaAttachmentRepository.saveAttachment(attachment);

    const access = await fixture.service.getAttachmentAccess(
      'user-2',
      token.attachmentId,
    );

    expect(access.attachment.id).toBe(token.attachmentId);
    expect(access.downloadUrl).toContain(token.objectKey);
    await expect(
      fixture.service.getAttachmentAccess('outsider', token.attachmentId),
    ).rejects.toThrow('你不是该会话成员');
  });

  it('should block attachment access while processing', async () => {
    const fixture = await createFixture();
    const token = await fixture.service.requestUploadToken('user-1', {
      purpose: 'chat-message',
      conversationId: fixture.conversation.id,
      fileName: 'photo.png',
      mimeType: 'image/png',
      sizeBytes: 1024,
    });

    await fixture.service.confirmUpload('user-1', {
      attachmentId: token.attachmentId,
      objectKey: token.objectKey,
    });

    await expect(
      fixture.service.getAttachmentAccess('user-2', token.attachmentId),
    ).rejects.toThrow('附件仍在处理中');
  });

  it('should reject upload token requests when the limiter trips', async () => {
    const fixture = await createFixture();
    (
      fixture.rateLimitService as unknown as {
        consumeOrThrow: jest.Mock;
      }
    ).consumeOrThrow.mockRejectedValueOnce(
      new Error('上传请求过于频繁，请稍后再试'),
    );

    await expect(
      fixture.service.requestUploadToken('user-1', {
        purpose: 'chat-message',
        conversationId: fixture.conversation.id,
        fileName: 'photo.png',
        mimeType: 'image/png',
        sizeBytes: 1024,
      }),
    ).rejects.toThrow('上传请求过于频繁，请稍后再试');
  });
});
