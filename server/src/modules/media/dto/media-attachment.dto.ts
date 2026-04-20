import type { MediaAttachmentEntity } from '../entities/media-attachment.entity';

export interface MediaAttachmentView {
  id: string;
  conversationId: string;
  purpose: MediaAttachmentEntity['purpose'];
  attachmentKind: MediaAttachmentEntity['attachmentKind'];
  status: MediaAttachmentEntity['status'];
  fileName: string;
  mimeType: string;
  sizeBytes: number;
  previewObjectKey: string | null;
  failureReason: string | null;
  uploadedAt: string | null;
  confirmedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface MediaAttachmentAccessView {
  attachment: MediaAttachmentView;
  downloadUrl: string;
  expiresAt: string;
}

export function toMediaAttachmentView(
  attachment: MediaAttachmentEntity,
): MediaAttachmentView {
  return {
    id: attachment.id,
    conversationId: attachment.conversationId,
    purpose: attachment.purpose,
    attachmentKind: attachment.attachmentKind,
    status: attachment.status,
    fileName: attachment.fileName,
    mimeType: attachment.mimeType,
    sizeBytes: attachment.sizeBytes,
    previewObjectKey: attachment.previewObjectKey,
    failureReason: attachment.failureReason,
    uploadedAt: attachment.uploadedAt?.toISOString() ?? null,
    confirmedAt: attachment.confirmedAt?.toISOString() ?? null,
    createdAt: attachment.createdAt.toISOString(),
    updatedAt: attachment.updatedAt.toISOString(),
  };
}
