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
import { MediaAttachmentRepository } from '../repositories/media-attachment.repository';

import { objectContentMatchesMimeType } from './media-content-sniffer.util';
import { MediaFilePolicyService } from './media-file-policy.service';
import { MediaObjectStorageService } from './media-object-storage.service';
import { MediaProcessingWorkerService } from './media-processing-worker.service';

import { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';

@Injectable()
export class MediaService {
  private readonly uploadExpiresInSeconds = 60 * 10;
  private readonly downloadExpiresInSeconds = 60 * 5;
  private readonly contentInspectBytes = 16 * 1024;

  constructor(
    private readonly mediaObjectStorageService: MediaObjectStorageService,
    private readonly mediaAttachmentRepository: MediaAttachmentRepository,
    private readonly mediaProcessingWorkerService: MediaProcessingWorkerService,
    private readonly chatModelRepository: ChatModelRepository,
    private readonly rateLimitService: RateLimitService,
    private readonly mediaFilePolicyService: MediaFilePolicyService,
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
    const fileExtension =
      this.mediaFilePolicyService.extractFileExtension(normalizedFileName);
    const filePolicy =
      this.mediaFilePolicyService.resolveFilePolicy(normalizedMimeType);

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
    const objectKey = this.mediaFilePolicyService.buildObjectKey({
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

    const objectHeadBytes = await this.mediaObjectStorageService.readObjectBytes({
      objectKey: attachment.objectKey,
      maxBytes: this.contentInspectBytes,
    });

    if (
      !objectHeadBytes ||
      !objectContentMatchesMimeType(attachment.mimeType, objectHeadBytes)
    ) {
      throw new BadRequestException('附件对象内容与申请记录不匹配');
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
