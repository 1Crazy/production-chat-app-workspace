import { Injectable, Logger } from '@nestjs/common';

export interface RiskEventRecord {
  type: 'rate_limit_exceeded';
  scope: string;
  actorKey: string;
  limit: number;
  windowMs: number;
  attempts: number;
  metadata?: Record<string, string | number | boolean | null>;
}

@Injectable()
export class RiskEventRecorderService {
  private readonly logger = new Logger(RiskEventRecorderService.name);

  async record(event: RiskEventRecord): Promise<void> {
    this.logger.warn(JSON.stringify(event));
  }
}
