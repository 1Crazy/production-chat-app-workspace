import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';

import type { SendMessageDto } from '../dto/send-message.dto';

import { MediaAttachmentRepository } from '@app/modules/media/repositories/media-attachment.repository';

@Injectable()
export class MessageContentService {
  constructor(
    private readonly mediaAttachmentRepository: MediaAttachmentRepository,
  ) {}

  async buildMessageContent(
    senderUserId: string,
    dto: SendMessageDto,
  ): Promise<Record<string, unknown>> {
    if (dto.type === 'text') {
      const normalizedText = dto.text?.trim();

      if (!normalizedText) {
        throw new BadRequestException('文本消息不能为空');
      }

      return {
        text: normalizedText,
      };
    }

    const attachmentId = dto.payload?.['attachmentId'];

    if (typeof attachmentId !== 'string' || attachmentId.trim().length === 0) {
      throw new BadRequestException('附件消息必须携带 attachmentId');
    }

    const attachment = await this.mediaAttachmentRepository.getAttachmentOrThrow(
      attachmentId.trim(),
    );

    if (attachment.ownerId !== senderUserId) {
      throw new ForbiddenException('不能发送不属于自己的附件');
    }

    if (attachment.conversationId !== dto.conversationId) {
      throw new BadRequestException('附件不属于当前会话');
    }

    if (attachment.attachmentKind !== dto.type) {
      throw new BadRequestException('消息类型与附件类型不匹配');
    }

    if (attachment.status === 'pending_upload') {
      throw new BadRequestException('附件尚未完成上传确认');
    }

    if (attachment.status === 'failed') {
      throw new BadRequestException('附件处理失败，不能发送');
    }

    return {
      attachmentId: attachment.id,
      attachmentKind: attachment.attachmentKind,
      attachmentStatus: attachment.status,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
      sizeBytes: attachment.sizeBytes,
      previewObjectKey: attachment.previewObjectKey,
    };
  }
}
