export type MediaAttachmentKind = 'image' | 'audio' | 'file';
export type MediaAttachmentPurpose = 'chat-message';
export type MediaAttachmentStatus =
  | 'pending_upload'
  | 'processing'
  | 'ready'
  | 'failed';

export interface MediaAttachmentEntity {
  id: string;
  ownerId: string;
  conversationId: string;
  purpose: MediaAttachmentPurpose;
  attachmentKind: MediaAttachmentKind;
  status: MediaAttachmentStatus;
  objectKey: string;
  fileName: string;
  mimeType: string;
  sizeBytes: number;
  previewObjectKey: string | null;
  failureReason: string | null;
  uploadedAt: Date | null;
  confirmedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}
