export type ModerationReportTargetType = 'message' | 'conversation' | 'user';
export type ModerationReportStatus =
  | 'pending_review'
  | 'reviewed'
  | 'resolved'
  | 'rejected';

export interface ModerationReportEntity {
  id: string;
  reporterId: string;
  targetType: ModerationReportTargetType;
  targetId: string;
  conversationId: string | null;
  messageId: string | null;
  reportedUserId: string | null;
  reasonCode: string;
  description: string | null;
  status: ModerationReportStatus;
  resolutionNote: string | null;
  handledByUserId: string | null;
  handledAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}
