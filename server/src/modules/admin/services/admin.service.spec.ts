import type { AdminAuditLogEntity } from '../entities/admin-audit-log.entity';
import { AdminAuditLogRepository } from '../repositories/admin-audit-log.repository';

import { AdminService } from './admin.service';

import { InMemoryChatModelRepository } from '@app/infra/database/repositories/in-memory-chat-model.repository';
import type { AppLoggerService } from '@app/infra/logger/app-logger.service';
import type { MetricsRegistryService } from '@app/infra/observability/metrics-registry.service';
import { InMemoryAuthRepository } from '@app/modules/auth/repositories/in-memory-auth.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import type { ModerationReportEntity } from '@app/modules/moderation/entities/moderation-report.entity';
import { ModerationReportRepository } from '@app/modules/moderation/repositories/moderation-report.repository';
import type { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';

class InMemoryAdminAuditLogRepository extends AdminAuditLogRepository {
  private readonly logsById = new Map<string, AdminAuditLogEntity>();

  override async createLog(params: {
    actorUserId: string | null;
    action: string;
    targetType: string;
    targetId: string;
    result: AdminAuditLogEntity['result'];
    summary: string;
    metadata: Record<string, unknown> | null;
  }): Promise<AdminAuditLogEntity> {
    const log: AdminAuditLogEntity = {
      id: `audit-${this.logsById.size + 1}`,
      actorUserId: params.actorUserId,
      action: params.action,
      targetType: params.targetType,
      targetId: params.targetId,
      result: params.result,
      summary: params.summary,
      metadata: params.metadata,
      createdAt: new Date(),
    };

    this.logsById.set(log.id, log);
    return log;
  }

  override async listLogs(params?: {
    action?: string;
  }): Promise<AdminAuditLogEntity[]> {
    return Array.from(this.logsById.values()).filter((log) => {
      return params?.action == null || log.action === params.action;
    });
  }
}

class InMemoryModerationReportRepository extends ModerationReportRepository {
  private readonly reportsById = new Map<string, ModerationReportEntity>();

  override async createReport(params: {
    reporterId: string;
    targetType: ModerationReportEntity['targetType'];
    targetId: string;
    conversationId: string | null;
    messageId: string | null;
    reportedUserId: string | null;
    reasonCode: string;
    description: string | null;
  }): Promise<ModerationReportEntity> {
    const report: ModerationReportEntity = {
      id: `report-${this.reportsById.size + 1}`,
      reporterId: params.reporterId,
      targetType: params.targetType,
      targetId: params.targetId,
      conversationId: params.conversationId,
      messageId: params.messageId,
      reportedUserId: params.reportedUserId,
      reasonCode: params.reasonCode,
      description: params.description,
      status: 'pending_review',
      resolutionNote: null,
      handledByUserId: null,
      handledAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    this.reportsById.set(report.id, report);
    return report;
  }

  override async listReportsByReporter(
    reporterId: string,
  ): Promise<ModerationReportEntity[]> {
    return Array.from(this.reportsById.values()).filter((report) => {
      return report.reporterId === reporterId;
    });
  }

  override async listReports(params?: {
    status?: ModerationReportEntity['status'];
  }): Promise<ModerationReportEntity[]> {
    return Array.from(this.reportsById.values()).filter((report) => {
      return params?.status == null || report.status === params.status;
    });
  }

  override async getReportOrThrow(reportId: string): Promise<ModerationReportEntity> {
    const report = this.reportsById.get(reportId);

    if (!report) {
      throw new Error('举报记录不存在');
    }

    return report;
  }

  override async saveReport(report: ModerationReportEntity): Promise<void> {
    report.updatedAt = new Date();
    this.reportsById.set(report.id, report);
  }
}

describe('AdminService', () => {
  async function createFixture() {
    const authRepository = new InMemoryAuthRepository();
    const authIdentityService = new AuthIdentityService(authRepository);
    const moderationReportRepository = new InMemoryModerationReportRepository();
    const adminAuditLogRepository = new InMemoryAdminAuditLogRepository();
    const chatModelRepository = new InMemoryChatModelRepository();
    const chatGateway = {
      disconnectSession: jest.fn().mockResolvedValue(undefined),
    } as unknown as ChatGateway;
    const metricsRegistryService = {
      incrementCounter: jest.fn(),
    } as unknown as MetricsRegistryService;
    const appLoggerService = {
      logWithMetadata: jest.fn(),
    } as unknown as AppLoggerService;
    const service = new AdminService(
      adminAuditLogRepository,
      moderationReportRepository,
      chatModelRepository,
      authRepository,
      authIdentityService,
      metricsRegistryService,
      appLoggerService,
      chatGateway,
    );

    return {
      adminAuditLogRepository,
      authRepository,
      chatGateway,
      metricsRegistryService,
      moderationReportRepository,
      service,
    };
  }

  it('should process a pending report and write an audit log', async () => {
    const fixture = await createFixture();
    const admin = await fixture.authRepository.createUser({
      identifier: 'admin@example.com',
      nickname: 'Admin',
      handle: 'admin_user',
    });
    const reporter = await fixture.authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    const report = await fixture.moderationReportRepository.createReport({
      reporterId: reporter.id,
      targetType: 'user',
      targetId: 'target-user-id',
      conversationId: null,
      messageId: null,
      reportedUserId: 'target-user-id',
      reasonCode: 'spam',
      description: 'spam',
    });

    const result = await fixture.service.processReport({
      adminUserId: admin.id,
      reportId: report.id,
      dto: {
        status: 'resolved',
        resolutionNote: '已处理',
      },
    });

    expect(result).toMatchObject({
      id: report.id,
      status: 'resolved',
      handledByUserId: admin.id,
      resolutionNote: '已处理',
    });
    const auditLogs = await fixture.adminAuditLogRepository.listLogs();
    expect(auditLogs).toHaveLength(1);
    expect(auditLogs[0]).toMatchObject({
      actorUserId: admin.id,
      action: 'moderation.report.process',
      targetType: 'moderation_report',
      targetId: report.id,
    });
  });

  it('should ban a user, revoke active sessions, and audit the action', async () => {
    const fixture = await createFixture();
    const admin = await fixture.authRepository.createUser({
      identifier: 'admin@example.com',
      nickname: 'Admin',
      handle: 'admin_user',
    });
    const target = await fixture.authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });
    const sessionA = await fixture.authRepository.createSession({
      userId: target.id,
      deviceName: 'bob-phone',
      refreshNonce: 'nonce-a',
    });
    const sessionB = await fixture.authRepository.createSession({
      userId: target.id,
      deviceName: 'bob-ipad',
      refreshNonce: 'nonce-b',
    });

    const result = await fixture.service.banUser({
      adminUserId: admin.id,
      userId: target.id,
      dto: {
        reason: '恶意骚扰',
      },
    });

    expect(result).toMatchObject({
      success: true,
      userId: target.id,
      revokedSessionIds: [sessionA.id, sessionB.id],
    });
    const disabledUser = await fixture.authRepository.findUserByIdentifier(
      target.identifier,
    );
    expect(disabledUser?.disabledAt).toEqual(expect.any(Date));
    expect(
      (fixture.chatGateway as unknown as { disconnectSession: jest.Mock })
        .disconnectSession,
    ).toHaveBeenCalledTimes(2);
  });

  it('should revoke a specific device session and audit the action', async () => {
    const fixture = await createFixture();
    const admin = await fixture.authRepository.createUser({
      identifier: 'admin@example.com',
      nickname: 'Admin',
      handle: 'admin_user',
    });
    const target = await fixture.authRepository.createUser({
      identifier: 'charlie@example.com',
      nickname: 'Charlie',
      handle: 'charlie_user',
    });
    const session = await fixture.authRepository.createSession({
      userId: target.id,
      deviceName: 'charlie-phone',
      refreshNonce: 'nonce-c',
    });

    const result = await fixture.service.revokeSession({
      adminUserId: admin.id,
      sessionId: session.id,
    });

    expect(result).toMatchObject({
      success: true,
      sessionId: session.id,
    });
    const activeSession = await fixture.authRepository.findActiveSessionById(
      session.id,
    );
    expect(activeSession).toBeNull();
    const auditLogs = await fixture.adminAuditLogRepository.listLogs({
      action: 'session.revoke',
    });
    expect(auditLogs).toHaveLength(1);
  });
});
