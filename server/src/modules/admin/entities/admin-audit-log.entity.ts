export interface AdminAuditLogEntity {
  id: string;
  actorUserId: string | null;
  action: string;
  targetType: string;
  targetId: string;
  result: 'success' | 'failed';
  summary: string;
  metadata: Record<string, unknown> | null;
  createdAt: Date;
}
