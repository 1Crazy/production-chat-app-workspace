import { Module } from '@nestjs/common';

import { AdminController } from './controllers/admin.controller';
import { AdminAccessGuard } from './guards/admin-access.guard';
import { AdminAuditLogRepository } from './repositories/admin-audit-log.repository';
import { PrismaAdminAuditLogRepository } from './repositories/prisma-admin-audit-log.repository';
import { AdminService } from './services/admin.service';

import { DatabaseModule } from '@app/infra/database/database.module';
import { AuthModule } from '@app/modules/auth/auth.module';
import { ModerationModule } from '@app/modules/moderation/moderation.module';
import { RealtimeModule } from '@app/modules/realtime/realtime.module';

@Module({
  imports: [AuthModule, DatabaseModule, ModerationModule, RealtimeModule],
  controllers: [AdminController],
  providers: [
    AdminService,
    AdminAccessGuard,
    PrismaAdminAuditLogRepository,
    {
      provide: AdminAuditLogRepository,
      useExisting: PrismaAdminAuditLogRepository,
    },
  ],
  exports: [AdminService],
})
export class AdminModule {}
