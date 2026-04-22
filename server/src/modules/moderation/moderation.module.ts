import { Module } from '@nestjs/common';

import { ModerationController } from './controllers/moderation.controller';
import { ModerationReportRepository } from './repositories/moderation-report.repository';
import { PrismaModerationReportRepository } from './repositories/prisma-moderation-report.repository';
import { ModerationService } from './services/moderation.service';

import { AbuseModule } from '@app/infra/abuse/abuse.module';
import { DatabaseModule } from '@app/infra/database/database.module';
import { AuthModule } from '@app/modules/auth/auth.module';

@Module({
  imports: [AbuseModule, AuthModule, DatabaseModule],
  controllers: [ModerationController],
  providers: [
    ModerationService,
    PrismaModerationReportRepository,
    {
      provide: ModerationReportRepository,
      useExisting: PrismaModerationReportRepository,
    },
  ],
  exports: [ModerationService],
})
export class ModerationModule {}
