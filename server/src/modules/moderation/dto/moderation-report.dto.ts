import type { ModerationReportEntity } from '../entities/moderation-report.entity';

export interface ModerationReportView {
  id: string;
  reporterId: string;
  targetType: ModerationReportEntity['targetType'];
  targetId: string;
  conversationId: string | null;
  messageId: string | null;
  reportedUserId: string | null;
  reasonCode: string;
  description: string | null;
  status: ModerationReportEntity['status'];
  resolutionNote: string | null;
  handledByUserId: string | null;
  handledAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export function toModerationReportView(
  report: ModerationReportEntity,
): ModerationReportView {
  return {
    id: report.id,
    reporterId: report.reporterId,
    targetType: report.targetType,
    targetId: report.targetId,
    conversationId: report.conversationId,
    messageId: report.messageId,
    reportedUserId: report.reportedUserId,
    reasonCode: report.reasonCode,
    description: report.description,
    status: report.status,
    resolutionNote: report.resolutionNote,
    handledByUserId: report.handledByUserId,
    handledAt: report.handledAt?.toISOString() ?? null,
    createdAt: report.createdAt.toISOString(),
    updatedAt: report.updatedAt.toISOString(),
  };
}
