import { Injectable, NotFoundException } from '@nestjs/common';
import type { MediaAttachment } from '@prisma/client';

import type { MediaAttachmentEntity } from '../entities/media-attachment.entity';

import { MediaAttachmentRepository } from './media-attachment.repository';

import { PrismaService } from '@app/infra/database/prisma.service';

@Injectable()
export class PrismaMediaAttachmentRepository extends MediaAttachmentRepository {
  constructor(private readonly prismaService: PrismaService) {
    super();
  }

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
    const attachment = await this.prismaService.mediaAttachment.create({
      data: {
        id: params.id,
        ownerId: params.ownerId,
        conversationId: params.conversationId,
        purpose: params.purpose,
        attachmentKind: params.attachmentKind,
        objectKey: params.objectKey,
        fileName: params.fileName,
        mimeType: params.mimeType,
        sizeBytes: params.sizeBytes,
      },
    });

    return this.toEntity(attachment);
  }

  override async getAttachmentOrThrow(
    attachmentId: string,
  ): Promise<MediaAttachmentEntity> {
    const attachment = await this.prismaService.mediaAttachment.findUnique({
      where: {
        id: attachmentId,
      },
    });

    if (!attachment) {
      throw new NotFoundException('附件不存在');
    }

    return this.toEntity(attachment);
  }

  override async saveAttachment(entity: MediaAttachmentEntity): Promise<void> {
    await this.prismaService.mediaAttachment.update({
      where: {
        id: entity.id,
      },
      data: {
        status: entity.status,
        previewObjectKey: entity.previewObjectKey,
        failureReason: entity.failureReason,
        uploadedAt: entity.uploadedAt,
        confirmedAt: entity.confirmedAt,
      },
    });
  }

  private toEntity(attachment: MediaAttachment): MediaAttachmentEntity {
    return {
      id: attachment.id,
      ownerId: attachment.ownerId,
      conversationId: attachment.conversationId,
      purpose: attachment.purpose as MediaAttachmentEntity['purpose'],
      attachmentKind:
        attachment.attachmentKind as MediaAttachmentEntity['attachmentKind'],
      status: attachment.status as MediaAttachmentEntity['status'],
      objectKey: attachment.objectKey,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
      sizeBytes: attachment.sizeBytes,
      previewObjectKey: attachment.previewObjectKey,
      failureReason: attachment.failureReason,
      uploadedAt: attachment.uploadedAt,
      confirmedAt: attachment.confirmedAt,
      createdAt: attachment.createdAt,
      updatedAt: attachment.updatedAt,
    };
  }
}
