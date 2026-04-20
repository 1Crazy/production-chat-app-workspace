import { Module } from '@nestjs/common';

import { MediaController } from './controllers/media.controller';
import { MediaAttachmentRepository } from './repositories/media-attachment.repository';
import { PrismaMediaAttachmentRepository } from './repositories/prisma-media-attachment.repository';
import { MediaObjectStorageService } from './services/media-object-storage.service';
import { MediaProcessingPipelineService } from './services/media-processing-pipeline.service';
import { MediaProcessingWorkerService } from './services/media-processing-worker.service';
import { MediaService } from './services/media.service';
import { S3MediaObjectStorageService } from './services/s3-media-object-storage.service';

import { AppConfigModule } from '@app/infra/config/app-config.module';
import { DatabaseModule } from '@app/infra/database/database.module';
import { QueueModule } from '@app/infra/queue/queue.module';
import { AuthModule } from '@app/modules/auth/auth.module';

@Module({
  imports: [AppConfigModule, AuthModule, DatabaseModule, QueueModule],
  controllers: [MediaController],
  providers: [
    MediaService,
    MediaProcessingPipelineService,
    MediaProcessingWorkerService,
    PrismaMediaAttachmentRepository,
    S3MediaObjectStorageService,
    {
      provide: MediaAttachmentRepository,
      useExisting: PrismaMediaAttachmentRepository,
    },
    {
      provide: MediaObjectStorageService,
      useExisting: S3MediaObjectStorageService,
    },
  ],
  exports: [MediaService, MediaAttachmentRepository],
})
export class MediaModule {}
