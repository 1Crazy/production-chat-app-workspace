import type { AdminAuditLogEntity } from '../entities/admin-audit-log.entity';

export interface AdminAuditLogView {
  id: string;
  actorUserId: string | null;
  action: string;
  targetType: string;
  targetId: string;
  result: AdminAuditLogEntity['result'];
  summary: string;
  metadata: Record<string, unknown> | null;
  createdAt: string;
}

export function toAdminAuditLogView(
  entity: AdminAuditLogEntity,
): AdminAuditLogView {
  return {
    id: entity.id,
    actorUserId: entity.actorUserId,
    action: entity.action,
    targetType: entity.targetType,
    targetId: entity.targetId,
    result: entity.result,
    summary: entity.summary,
    metadata: entity.metadata,
    createdAt: entity.createdAt.toISOString(),
  };
}
