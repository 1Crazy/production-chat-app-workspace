import type { AdminAuditLogEntity } from '../entities/admin-audit-log.entity';

export abstract class AdminAuditLogRepository {
  abstract createLog(params: {
    actorUserId: string | null;
    action: string;
    targetType: string;
    targetId: string;
    result: AdminAuditLogEntity['result'];
    summary: string;
    metadata: Record<string, unknown> | null;
  }): Promise<AdminAuditLogEntity>;

  abstract listLogs(params?: {
    action?: string;
  }): Promise<AdminAuditLogEntity[]>;
}
