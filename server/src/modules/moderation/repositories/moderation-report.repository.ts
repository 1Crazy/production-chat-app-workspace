import type { ModerationReportEntity } from '../entities/moderation-report.entity';

export abstract class ModerationReportRepository {
  abstract createReport(params: {
    reporterId: string;
    targetType: ModerationReportEntity['targetType'];
    targetId: string;
    conversationId: string | null;
    messageId: string | null;
    reportedUserId: string | null;
    reasonCode: string;
    description: string | null;
  }): Promise<ModerationReportEntity>;

  abstract listReportsByReporter(
    reporterId: string,
  ): Promise<ModerationReportEntity[]>;

  abstract listReports(params?: {
    status?: ModerationReportEntity['status'];
  }): Promise<ModerationReportEntity[]>;

  abstract getReportOrThrow(reportId: string): Promise<ModerationReportEntity>;

  abstract saveReport(report: ModerationReportEntity): Promise<void>;
}
