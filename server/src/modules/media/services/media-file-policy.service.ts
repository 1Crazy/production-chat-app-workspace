import { BadRequestException, Injectable } from '@nestjs/common';

import type { MediaAttachmentKind } from '../entities/media-attachment.entity';

type MediaFilePolicy = {
  attachmentKind: MediaAttachmentKind;
  maxSizeBytes: number;
  mimeToExtensions: Record<string, string[]>;
};

@Injectable()
export class MediaFilePolicyService {
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

  resolveFilePolicy(mimeType: string): MediaFilePolicy | null {
    for (const policy of this.filePolicies) {
      if (policy.mimeToExtensions[mimeType] != null) {
        return policy;
      }
    }

    return null;
  }

  extractFileExtension(fileName: string): string {
    const dotIndex = fileName.lastIndexOf('.');

    if (dotIndex <= 0 || dotIndex === fileName.length - 1) {
      throw new BadRequestException('文件名必须包含合法扩展名');
    }

    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  buildObjectKey(params: {
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
}
