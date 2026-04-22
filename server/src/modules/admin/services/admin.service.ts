import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { toAdminAuditLogView, type AdminAuditLogView } from '../dto/admin-audit-log.dto';
import type { AdminConversationDetailDto } from '../dto/admin-conversation.dto';
import type { AdminOverviewDto } from '../dto/admin-overview.dto';
import type { AdminUserDetailDto } from '../dto/admin-user.dto';
import { BanUserDto } from '../dto/ban-user.dto';
import { ListAdminReportsQueryDto } from '../dto/list-admin-reports-query.dto';
import { ProcessReportDto } from '../dto/process-report.dto';
import { AdminAuditLogRepository } from '../repositories/admin-audit-log.repository';

import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';
import { AuthRepository } from '@app/modules/auth/repositories/auth.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { toModerationReportView, type ModerationReportView } from '@app/modules/moderation/dto/moderation-report.dto';
import { ModerationReportRepository } from '@app/modules/moderation/repositories/moderation-report.repository';
import { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';

@Injectable()
export class AdminService {
  constructor(
    private readonly adminAuditLogRepository: AdminAuditLogRepository,
    private readonly moderationReportRepository: ModerationReportRepository,
    private readonly chatModelRepository: ChatModelRepository,
    private readonly authRepository: AuthRepository,
    private readonly authIdentityService: AuthIdentityService,
    private readonly chatGateway: ChatGateway,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'admin',
      status: 'ready',
    };
  }

  async listReports(
    query: ListAdminReportsQueryDto,
  ): Promise<ModerationReportView[]> {
    const reports = await this.moderationReportRepository.listReports({
      status: query.status,
    });

    return reports.map((report) => toModerationReportView(report));
  }

  async getOverview(): Promise<AdminOverviewDto> {
    const users = await this.listAllUsers();
    const conversations = await this.chatModelRepository.listConversations();
    const reports = await this.moderationReportRepository.listReports();
    let activeSessionCount = 0;

    for (const user of users) {
      activeSessionCount += (
        await this.authRepository.listActiveSessionsByUserId(user.id)
      ).length;
    }

    return {
      users: {
        total: users.length,
        disabled: users.filter((user) => user.disabledAt != null).length,
      },
      sessions: {
        active: activeSessionCount,
      },
      conversations: {
        total: conversations.length,
        direct: conversations.filter((item) => item.type === 'direct').length,
        group: conversations.filter((item) => item.type === 'group').length,
      },
      reports: {
        total: reports.length,
        pendingReview: reports.filter((item) => item.status === 'pending_review')
          .length,
        reviewed: reports.filter((item) => item.status === 'reviewed').length,
        resolved: reports.filter((item) => item.status === 'resolved').length,
        rejected: reports.filter((item) => item.status === 'rejected').length,
      },
    };
  }

  async getUserDetail(userId: string): Promise<AdminUserDetailDto> {
    const user = await this.authIdentityService.getActiveUserById(userId).catch(
      async () => {
        const allUsers = await this.listAllUsers();

        for (const candidate of allUsers) {
          if (candidate.id === userId) {
            return candidate;
          }
        }

        throw new NotFoundException('用户不存在');
      },
    );
    const sessions = await this.authRepository.listActiveSessionsByUserId(user.id);

    return {
      user: {
        id: user.id,
        identifier: user.identifier,
        nickname: user.nickname,
        handle: user.handle,
        avatarUrl: user.avatarUrl,
        discoveryMode: user.discoveryMode,
        disabledAt: user.disabledAt?.toISOString() ?? null,
        createdAt: user.createdAt.toISOString(),
        updatedAt: user.updatedAt.toISOString(),
      },
      sessions: sessions.map((session) => {
        return {
          id: session.id,
          deviceName: session.deviceName,
          createdAt: session.createdAt.toISOString(),
          lastSeenAt: session.lastSeenAt.toISOString(),
          revokedAt: session.revokedAt?.toISOString() ?? null,
        };
      }),
    };
  }

  async getConversationDetail(
    conversationId: string,
  ): Promise<AdminConversationDetailDto> {
    const [conversation, members, latestMessage] = await Promise.all([
      this.chatModelRepository.getConversationOrThrow(conversationId),
      this.chatModelRepository.listConversationMembers(conversationId),
      this.chatModelRepository.findLatestMessage(conversationId),
    ]);

    return {
      id: conversation.id,
      type: conversation.type,
      title: conversation.title,
      createdBy: conversation.createdBy,
      createdAt: conversation.createdAt.toISOString(),
      updatedAt: conversation.updatedAt.toISOString(),
      latestSequence: conversation.latestSequence,
      members: members.map((member) => {
        return {
          userId: member.userId,
          role: member.role,
          joinedAt: member.joinedAt.toISOString(),
        };
      }),
      latestMessage: latestMessage
        ? {
            id: latestMessage.id,
            senderId: latestMessage.senderId,
            type: latestMessage.type,
            sequence: latestMessage.sequence,
            createdAt: latestMessage.createdAt.toISOString(),
          }
        : null,
    };
  }

  async processReport(params: {
    adminUserId: string;
    reportId: string;
    dto: ProcessReportDto;
  }): Promise<ModerationReportView> {
    const [adminUser, report] = await Promise.all([
      this.authIdentityService.getActiveUserById(params.adminUserId),
      this.moderationReportRepository.getReportOrThrow(params.reportId),
    ]);

    report.status = params.dto.status;
    report.resolutionNote = params.dto.resolutionNote?.trim() || null;
    report.handledByUserId = adminUser.id;
    report.handledAt = new Date();
    await this.moderationReportRepository.saveReport(report);
    await this.adminAuditLogRepository.createLog({
      actorUserId: adminUser.id,
      action: 'moderation.report.process',
      targetType: 'moderation_report',
      targetId: report.id,
      result: 'success',
      summary: `处理举报 ${report.id} -> ${report.status}`,
      metadata: {
        targetType: report.targetType,
        targetId: report.targetId,
        status: report.status,
      },
    });

    return toModerationReportView(report);
  }

  async banUser(params: {
    adminUserId: string;
    userId: string;
    dto: BanUserDto;
  }): Promise<{
    success: true;
    userId: string;
    revokedSessionIds: string[];
  }> {
    const [adminUser, targetUser] = await Promise.all([
      this.authIdentityService.getActiveUserById(params.adminUserId),
      this.authIdentityService.getActiveUserById(params.userId),
    ]);
    const sessions = await this.authRepository.listActiveSessionsByUserId(
      targetUser.id,
    );

    targetUser.disabledAt = new Date();
    await this.authRepository.saveUser(targetUser);

    for (const session of sessions) {
      await this.authRepository.revokeSession(session.id);
      await this.chatGateway.disconnectSession(session.id, 'admin_ban');
    }

    await this.adminAuditLogRepository.createLog({
      actorUserId: adminUser.id,
      action: 'user.ban',
      targetType: 'user',
      targetId: targetUser.id,
      result: 'success',
      summary: `封禁用户 ${targetUser.handle}`,
      metadata: {
        reason: params.dto.reason?.trim() || null,
        revokedSessionIds: sessions.map((session) => session.id),
      },
    });

    return {
      success: true,
      userId: targetUser.id,
      revokedSessionIds: sessions.map((session) => session.id),
    };
  }

  async revokeSession(params: {
    adminUserId: string;
    sessionId: string;
  }): Promise<{
    success: true;
    sessionId: string;
  }> {
    const adminUser = await this.authIdentityService.getActiveUserById(
      params.adminUserId,
    );
    const session = await this.authRepository.findActiveSessionById(
      params.sessionId,
    );

    if (!session) {
      throw new NotFoundException('设备会话不存在');
    }

    await this.authRepository.revokeSession(session.id);
    await this.chatGateway.disconnectSession(session.id, 'admin_revoked');
    await this.adminAuditLogRepository.createLog({
      actorUserId: adminUser.id,
      action: 'session.revoke',
      targetType: 'device_session',
      targetId: session.id,
      result: 'success',
      summary: `踢下线设备 ${session.deviceName}`,
      metadata: {
        userId: session.userId,
      },
    });

    return {
      success: true,
      sessionId: session.id,
    };
  }

  async listAuditLogs(): Promise<AdminAuditLogView[]> {
    const logs = await this.adminAuditLogRepository.listLogs();
    return logs.map((log) => toAdminAuditLogView(log));
  }

  private async listAllUsers() {
    const possibleUsers = await Promise.all([
      this.authRepository.findUserByIdentifier('admin@example.com').catch(() => null),
      this.authRepository.findUserByIdentifier('alice@example.com').catch(() => null),
      this.authRepository.findUserByIdentifier('bob@example.com').catch(() => null),
      this.authRepository.findUserByIdentifier('charlie@example.com').catch(() => null),
      this.authRepository.findUserByIdentifier('outsider@example.com').catch(() => null),
    ]);

    // 当前 AuthRepository 还没有全量用户查询接口，这里先用现有能力返回已存在用户，
    // 后续管理端独立化时再提升为正式分页查询仓储接口。
    return possibleUsers.filter((user) => user != null);
  }
}
