import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';

import type { MediaAttachmentKind } from '../entities/media-attachment.entity';

import { MediaProcessingPipelineService } from './media-processing-pipeline.service';

import {
  type RedisQueueJob,
  RedisJobQueueService,
} from '@app/infra/queue/redis-job-queue.service';


interface MediaProcessingJobPayload {
  attachmentId: string;
  attachmentKind: MediaAttachmentKind;
}

@Injectable()
export class MediaProcessingWorkerService
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(MediaProcessingWorkerService.name);
  private readonly queueName = 'media-processing';
  private readonly maxJobsPerTick = 10;
  private readonly defaultMaxAttempts = 3;
  private pollTimer: NodeJS.Timeout | null = null;
  private isPolling = false;

  constructor(
    private readonly redisJobQueueService: RedisJobQueueService,
    private readonly mediaProcessingPipelineService: MediaProcessingPipelineService,
  ) {}

  async onModuleInit(): Promise<void> {
    this.pollTimer = setInterval(() => {
      void this.pollOnce();
    }, 1500);
    this.pollTimer.unref?.();
    await this.pollOnce();
  }

  onModuleDestroy(): void {
    if (this.pollTimer != null) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
  }

  async enqueueAttachment(
    attachmentId: string,
    attachmentKind: MediaAttachmentKind,
  ): Promise<void> {
    await this.redisJobQueueService.enqueue<MediaProcessingJobPayload>({
      id: `${attachmentId}:attempt:0`,
      queueName: this.queueName,
      kind: 'media-attachment-process',
      payload: {
        attachmentId,
        attachmentKind,
      },
      attempts: 0,
      maxAttempts: this.defaultMaxAttempts,
      availableAt: new Date().toISOString(),
    });
  }

  private async pollOnce(): Promise<void> {
    if (this.isPolling) {
      return;
    }

    this.isPolling = true;

    try {
      const jobs =
        await this.redisJobQueueService.dequeueDueJobs<MediaProcessingJobPayload>({
          queueName: this.queueName,
          now: new Date(),
          limit: this.maxJobsPerTick,
        });

      for (const job of jobs) {
        await this.processJob(job);
      }
    } finally {
      this.isPolling = false;
    }
  }

  private async processJob(
    job: RedisQueueJob<MediaProcessingJobPayload>,
  ): Promise<void> {
    try {
      await this.mediaProcessingPipelineService.processAttachment(
        job.payload.attachmentId,
      );
    } catch (error) {
      const nextAttempts = job.attempts + 1;
      const message =
        error instanceof Error ? error.message : '媒体处理任务失败';

      if (nextAttempts >= job.maxAttempts) {
        await this.mediaProcessingPipelineService.markFailed(
          job.payload.attachmentId,
          message,
        );
        this.logger.error(
          `Media attachment ${job.payload.attachmentId} failed permanently: ${message}`,
        );
        return;
      }

      const backoffMs = Math.min(1000 * 2 ** nextAttempts, 30000);

      await this.redisJobQueueService.enqueue<MediaProcessingJobPayload>({
        ...job,
        id: `${job.payload.attachmentId}:attempt:${nextAttempts}`,
        attempts: nextAttempts,
        availableAt: new Date(Date.now() + backoffMs).toISOString(),
      });
      this.logger.warn(
        `Retrying media attachment ${job.payload.attachmentId} in ${backoffMs}ms: ${message}`,
      );
    }
  }
}
