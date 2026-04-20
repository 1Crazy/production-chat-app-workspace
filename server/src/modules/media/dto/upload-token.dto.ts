import type { MediaAttachmentKind } from '../entities/media-attachment.entity';

export interface UploadTokenDto {
  attachmentId: string;
  objectKey: string;
  uploadUrl: string;
  method: 'PUT';
  expiresAt: string;
  requiredHeaders: Record<string, string>;
  attachmentKind: MediaAttachmentKind;
  confirmPayload: {
    attachmentId: string;
    conversationId: string;
    objectKey: string;
    fileName: string;
    mimeType: string;
    sizeBytes: number;
    purpose: 'chat-message';
    attachmentKind: MediaAttachmentKind;
  };
}
