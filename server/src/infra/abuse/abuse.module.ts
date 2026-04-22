import { Module } from '@nestjs/common';

import { RateLimitService } from './services/rate-limit.service';
import { RiskEventRecorderService } from './services/risk-event-recorder.service';

import { CacheModule } from '@app/infra/cache/cache.module';

@Module({
  imports: [CacheModule],
  providers: [RateLimitService, RiskEventRecorderService],
  exports: [RateLimitService, RiskEventRecorderService],
})
export class AbuseModule {}
