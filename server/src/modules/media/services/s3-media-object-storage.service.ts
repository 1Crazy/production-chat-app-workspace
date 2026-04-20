import {
  HeadObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { Injectable } from '@nestjs/common';

import { MediaObjectStorageService } from './media-object-storage.service';

import { AppConfigService } from '@app/infra/config/app-config.service';

@Injectable()
export class S3MediaObjectStorageService extends MediaObjectStorageService {
  private readonly s3Client: S3Client;

  constructor(private readonly appConfigService: AppConfigService) {
    super();
    this.s3Client = new S3Client({
      region: 'us-east-1',
      endpoint: appConfigService.s3Endpoint,
      forcePathStyle: true,
      credentials: {
        accessKeyId: appConfigService.s3AccessKey,
        secretAccessKey: appConfigService.s3SecretKey,
      },
    });
  }

  override async createSignedUpload(params: {
    objectKey: string;
    mimeType: string;
    expiresInSeconds: number;
  }): Promise<{
    uploadUrl: string;
    expiresAt: Date;
    requiredHeaders: Record<string, string>;
  }> {
    const uploadUrl = await getSignedUrl(
      this.s3Client,
      new PutObjectCommand({
        Bucket: this.appConfigService.s3Bucket,
        Key: params.objectKey,
        ContentType: params.mimeType,
      }),
      {
        expiresIn: params.expiresInSeconds,
      },
    );

    return {
      uploadUrl,
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
    const downloadUrl = await getSignedUrl(
      this.s3Client,
      new GetObjectCommand({
        Bucket: this.appConfigService.s3Bucket,
        Key: params.objectKey,
        ResponseContentType: params.mimeType,
        ResponseContentDisposition: `inline; filename="${params.fileName.replace(/"/g, '')}"`,
      }),
      {
        expiresIn: params.expiresInSeconds,
      },
    );

    return {
      downloadUrl,
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
    try {
      const response = await this.s3Client.send(
        new HeadObjectCommand({
          Bucket: this.appConfigService.s3Bucket,
          Key: params.objectKey,
        }),
      );

      return {
        exists: true,
        contentType: response.ContentType ?? null,
        sizeBytes: response.ContentLength ?? null,
      };
    } catch {
      return {
        exists: false,
        contentType: null,
        sizeBytes: null,
      };
    }
  }
}
