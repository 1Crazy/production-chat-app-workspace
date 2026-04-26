import { Injectable } from '@nestjs/common';

import type { MediaAttachmentEntity } from '../entities/media-attachment.entity';
import { MediaAttachmentRepository } from '../repositories/media-attachment.repository';

import { objectContentMatchesMimeType } from './media-content-sniffer.util';
import { MediaObjectStorageService } from './media-object-storage.service';

@Injectable()
export class MediaProcessingPipelineService {
  private readonly contentInspectBytes = 16 * 1024;

  constructor(
    private readonly mediaAttachmentRepository: MediaAttachmentRepository,
    private readonly mediaObjectStorageService: MediaObjectStorageService,
  ) {}

  async processAttachment(attachmentId: string): Promise<void> {
    const attachment = await this.mediaAttachmentRepository.getAttachmentOrThrow(
      attachmentId,
    );

    if (attachment.status !== 'processing') {
      return;
    }

    const objectMetadata = await this.mediaObjectStorageService.inspectObject({
      objectKey: attachment.objectKey,
    });

    if (!objectMetadata.exists) {
      throw new Error('附件对象缺失，无法继续处理');
    }

    if (
      objectMetadata.contentType != null &&
      objectMetadata.contentType !== attachment.mimeType
    ) {
      throw new Error('附件对象 MIME 类型在异步处理阶段不匹配');
    }

    if (
      objectMetadata.sizeBytes != null &&
      objectMetadata.sizeBytes !== attachment.sizeBytes
    ) {
      throw new Error('附件对象大小在异步处理阶段不匹配');
    }

    const objectHeadBytes = await this.mediaObjectStorageService.readObjectBytes({
      objectKey: attachment.objectKey,
      maxBytes: this.contentInspectBytes,
    });

    if (
      !objectHeadBytes ||
      !objectContentMatchesMimeType(attachment.mimeType, objectHeadBytes)
    ) {
      throw new Error('附件对象内容在异步处理阶段不匹配');
    }

    // 这里先把不同附件类型的后处理入口拆出来，后续接真实缩略图、转码、扫描服务时
    // 只需要替换对应分支实现，不需要重写确认上传和消息发送链路。
    switch (attachment.attachmentKind) {
      case 'image':
        await this.prepareImagePreview(attachment);
        break;
      case 'audio':
        await this.prepareAudioVariant(attachment);
        break;
      case 'file':
        await this.runSecurityScan(attachment);
        break;
    }

    attachment.status = 'ready';
    attachment.failureReason = null;
    await this.mediaAttachmentRepository.saveAttachment(attachment);
  }

  async markFailed(attachmentId: string, failureReason: string): Promise<void> {
    const attachment = await this.mediaAttachmentRepository.getAttachmentOrThrow(
      attachmentId,
    );

    attachment.status = 'failed';
    attachment.failureReason = failureReason;
    await this.mediaAttachmentRepository.saveAttachment(attachment);
  }

  private async prepareImagePreview(
    attachment: MediaAttachmentEntity,
  ): Promise<void> {
    // 真实缩略图生成器接入前，先保留独立扩展点和 preview 字段入口。
    attachment.previewObjectKey = null;
  }

  private async prepareAudioVariant(
    attachment: MediaAttachmentEntity,
  ): Promise<void> {
    // 真实转码器接入前，先保留独立扩展点，确保异步任务边界稳定。
    attachment.previewObjectKey = null;
  }

  private async runSecurityScan(
    attachment: MediaAttachmentEntity,
  ): Promise<void> {
    // 真实扫描服务接入前，先保留独立扩展点，避免后续再改业务主链路。
    attachment.previewObjectKey = null;
  }
}
