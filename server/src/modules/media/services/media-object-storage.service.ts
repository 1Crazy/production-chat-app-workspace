export abstract class MediaObjectStorageService {
  abstract createSignedUpload(params: {
    objectKey: string;
    mimeType: string;
    expiresInSeconds: number;
  }): Promise<{
    uploadUrl: string;
    expiresAt: Date;
    requiredHeaders: Record<string, string>;
  }>;

  abstract createSignedDownload(params: {
    objectKey: string;
    fileName: string;
    mimeType: string;
    expiresInSeconds: number;
  }): Promise<{
    downloadUrl: string;
    expiresAt: Date;
  }>;

  abstract inspectObject(params: {
    objectKey: string;
  }): Promise<{
    exists: boolean;
    contentType: string | null;
    sizeBytes: number | null;
  }>;

  abstract readObjectBytes(params: {
    objectKey: string;
    maxBytes: number;
  }): Promise<Buffer | null>;
}
