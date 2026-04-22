import { randomUUID } from 'node:crypto';

import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  PayloadTooLargeException,
} from '@nestjs/common';

import { ConfirmUploadDto } from '../dto/confirm-upload.dto';
import {
  type MediaAttachmentAccessView,
  toMediaAttachmentView,
} from '../dto/media-attachment.dto';
import type { RequestUploadTokenDto } from '../dto/request-upload-token.dto';
import type { UploadTokenDto } from '../dto/upload-token.dto';
import type {
  MediaAttachmentKind,
} from '../entities/media-attachment.entity';
import { MediaAttachmentRepository } from '../repositories/media-attachment.repository';

import { MediaObjectStorageService } from './media-object-storage.service';
import { MediaProcessingWorkerService } from './media-processing-worker.service';

import { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';

type MediaFilePolicy = {
  attachmentKind: MediaAttachmentKind;
  maxSizeBytes: number;
  mimeToExtensions: Record<string, string[]>;
};

@Injectable()
export class MediaService {
  private readonly uploadExpiresInSeconds = 60 * 10;
  private readonly downloadExpiresInSeconds = 60 * 5;
  private readonly filePolicies: MediaFilePolicy[] = [
    {
      attachmentKind: 'image',
      maxSizeBytes: 15 * 1024 * 1024,
      mimeToExtensions: {
        'image/jpeg': ['jpg', 'jpeg'],
        'image/png': ['png'],
        'image/webp': ['webp'],
        'image/gif': ['gif'],
      },
    },
    {
      attachmentKind: 'audio',
      maxSizeBytes: 20 * 1024 * 1024,
      mimeToExtensions: {
        'audio/mpeg': ['mp3'],
        'audio/mp4': ['m4a', 'mp4'],
        'audio/wav': ['wav'],
        'audio/aac': ['aac'],
        'audio/ogg': ['ogg'],
      },
    },
    {
      attachmentKind: 'file',
      maxSizeBytes: 50 * 1024 * 1024,
      mimeToExtensions: {
        'application/pdf': ['pdf'],
        'text/plain': ['txt'],
        'application/zip': ['zip'],
        'application/msword': ['doc'],
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document': [
          'docx',
        ],
        'application/vnd.ms-excel': ['xls'],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': [
          'xlsx',
        ],
        'application/vnd.ms-powerpoint': ['ppt'],
        'application/vnd.openxmlformats-officedocument.presentationml.presentation': [
          'pptx',
        ],
      },
    },
  ];

  constructor(
    private readonly mediaObjectStorageService: MediaObjectStorageService,
    private readonly mediaAttachmentRepository: MediaAttachmentRepository,
    private readonly mediaProcessingWorkerService: MediaProcessingWorkerService,
    private readonly chatModelRepository: ChatModelRepository,
    private readonly rateLimitService: RateLimitService,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'media',
      status: 'ready',
    };
  }

  async requestUploadToken(
    requesterUserId: string,
    dto: RequestUploadTokenDto,
  ): Promise<UploadTokenDto> {
    await this.rateLimitService.consumeOrThrow({
      scope: 'media.request-upload-token',
      actorKey: requesterUserId,
      limit: 20,
      windowMs: 10 * 60 * 1000,
      message: '上传请求过于频繁，请稍后再试',
      metadata: {
        conversationId: dto.conversationId,
        sizeBytes: dto.sizeBytes,
      },
    });
    await this.assertConversationMembership(
      dto.conversationId,
      requesterUserId,
    );

    const normalizedFileName = dto.fileName.trim();
    const normalizedMimeType = dto.mimeType.trim().toLowerCase();
    const fileExtension = this.extractFileExtension(normalizedFileName);
    const filePolicy = this.resolveFilePolicy(normalizedMimeType);

    if (!filePolicy) {
      throw new BadRequestException('不支持的附件 MIME 类型');
    }

    if (!filePolicy.mimeToExtensions[normalizedMimeType]?.includes(fileExtension)) {
      throw new BadRequestException('文件扩展名与 MIME 类型不匹配');
    }

    if (dto.sizeBytes > filePolicy.maxSizeBytes) {
      throw new PayloadTooLargeException(
        `附件超过上限，当前类型最大允许 ${filePolicy.maxSizeBytes} 字节`,
      );
    }

    const attachmentId = randomUUID();
    const objectKey = this.buildObjectKey({
      attachmentId,
      conversationId: dto.conversationId,
      attachmentKind: filePolicy.attachmentKind,
      fileName: normalizedFileName,
    });
    const signedUpload =
      await this.mediaObjectStorageService.createSignedUpload({
        objectKey,
        mimeType: normalizedMimeType,
        expiresInSeconds: this.uploadExpiresInSeconds,
      });

    await this.mediaAttachmentRepository.createPendingAttachment({
      id: attachmentId,
      ownerId: requesterUserId,
      conversationId: dto.conversationId,
      purpose: dto.purpose,
      attachmentKind: filePolicy.attachmentKind,
      objectKey,
      fileName: normalizedFileName,
      mimeType: normalizedMimeType,
      sizeBytes: dto.sizeBytes,
    });

    return {
      attachmentId,
      objectKey,
      uploadUrl: signedUpload.uploadUrl,
      method: 'PUT',
      expiresAt: signedUpload.expiresAt.toISOString(),
      requiredHeaders: signedUpload.requiredHeaders,
      attachmentKind: filePolicy.attachmentKind,
      confirmPayload: {
        attachmentId,
        conversationId: dto.conversationId,
        objectKey,
        fileName: normalizedFileName,
        mimeType: normalizedMimeType,
        sizeBytes: dto.sizeBytes,
        purpose: dto.purpose,
        attachmentKind: filePolicy.attachmentKind,
      },
    };
  }

  async confirmUpload(
    requesterUserId: string,
    dto: ConfirmUploadDto,
  ) {
    const attachment = await this.mediaAttachmentRepository.getAttachmentOrThrow(
      dto.attachmentId,
    );

    if (attachment.ownerId !== requesterUserId) {
      throw new ForbiddenException('你不能确认他人的附件上传');
    }

    await this.assertConversationMembership(
      attachment.conversationId,
      requesterUserId,
    );

    if (attachment.objectKey !== dto.objectKey.trim()) {
      throw new BadRequestException('附件对象键不匹配');
    }

    if (attachment.status !== 'pending_upload') {
      return toMediaAttachmentView(attachment);
    }

    const objectMetadata = await this.mediaObjectStorageService.inspectObject({
      objectKey: attachment.objectKey,
    });

    if (!objectMetadata.exists) {
      throw new BadRequestException('附件对象尚未上传完成');
    }

    if (
      objectMetadata.contentType != null &&
      objectMetadata.contentType !== attachment.mimeType
    ) {
      throw new BadRequestException('附件对象类型与申请记录不匹配');
    }

    if (
      objectMetadata.sizeBytes != null &&
      objectMetadata.sizeBytes !== attachment.sizeBytes
    ) {
      throw new BadRequestException('附件对象大小与申请记录不匹配');
    }

    attachment.status = 'processing';
    attachment.uploadedAt = new Date();
    attachment.confirmedAt = attachment.uploadedAt;
    attachment.failureReason = null;
    await this.mediaAttachmentRepository.saveAttachment(attachment);
    await this.mediaProcessingWorkerService.enqueueAttachment(
      attachment.id,
      attachment.attachmentKind,
    );

    return toMediaAttachmentView(attachment);
  }

  async getAttachmentAccess(
    requesterUserId: string,
    attachmentId: string,
  ): Promise<MediaAttachmentAccessView> {
    const attachment = await this.mediaAttachmentRepository.getAttachmentOrThrow(
      attachmentId,
    );

    await this.assertConversationMembership(
      attachment.conversationId,
      requesterUserId,
    );

    if (attachment.status === 'pending_upload') {
      throw new ConflictException('附件尚未完成上传确认');
    }

    if (attachment.status === 'processing') {
      throw new ConflictException('附件仍在处理中');
    }

    if (attachment.status === 'failed') {
      throw new ConflictException('附件处理失败，当前不可访问');
    }

    const signedDownload =
      await this.mediaObjectStorageService.createSignedDownload({
        objectKey: attachment.objectKey,
        fileName: attachment.fileName,
        mimeType: attachment.mimeType,
        expiresInSeconds: this.downloadExpiresInSeconds,
      });

    return {
      attachment: toMediaAttachmentView(attachment),
      downloadUrl: signedDownload.downloadUrl,
      expiresAt: signedDownload.expiresAt.toISOString(),
    };
  }

  private resolveFilePolicy(mimeType: string): MediaFilePolicy | null {
    for (const policy of this.filePolicies) {
      if (policy.mimeToExtensions[mimeType] != null) {
        return policy;
      }
    }

    return null;
  }

  private extractFileExtension(fileName: string): string {
    const dotIndex = fileName.lastIndexOf('.');

    if (dotIndex <= 0 || dotIndex === fileName.length - 1) {
      throw new BadRequestException('文件名必须包含合法扩展名');
    }

    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  private buildObjectKey(params: {
    attachmentId: string;
    conversationId: string;
    attachmentKind: MediaAttachmentKind;
    fileName: string;
  }): string {
    const now = new Date();
    const safeBaseName = params.fileName
      .replace(/[^a-zA-Z0-9._-]+/g, '_')
      .replace(/_+/g, '_');

    return [
      'chat-media',
      params.conversationId,
      params.attachmentKind,
      `${now.getUTCFullYear().toString().padStart(4, '0')}`,
      `${(now.getUTCMonth() + 1).toString().padStart(2, '0')}`,
      `${params.attachmentId}-${safeBaseName}`,
    ].join('/');
  }

  private async assertConversationMembership(
    conversationId: string,
    userId: string,
  ): Promise<void> {
    await this.chatModelRepository.getConversationOrThrow(conversationId);

    if (!(await this.chatModelRepository.isConversationMember(conversationId, userId))) {
      throw new ForbiddenException('你不是该会话成员');
    }
  }
}
