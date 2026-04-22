import type { ModerationReportEntity } from '../entities/moderation-report.entity';
import { ModerationReportRepository } from '../repositories/moderation-report.repository';

import { ModerationService } from './moderation.service';

import type { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { InMemoryChatModelRepository } from '@app/infra/database/repositories/in-memory-chat-model.repository';
import { InMemoryAuthRepository } from '@app/modules/auth/repositories/in-memory-auth.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';

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
    const now = new Date();
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
      createdAt: now,
      updatedAt: now,
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

describe('ModerationService', () => {
  async function createFixture() {
    const authRepository = new InMemoryAuthRepository();
    const chatModelRepository = new InMemoryChatModelRepository();
    const authIdentityService = new AuthIdentityService(authRepository);
    const moderationReportRepository = new InMemoryModerationReportRepository();
    const rateLimitService = {
      consumeOrThrow: jest.fn().mockResolvedValue(undefined),
    } as unknown as RateLimitService;
    const service = new ModerationService(
      moderationReportRepository,
      chatModelRepository,
      authIdentityService,
      rateLimitService,
    );

    return {
      authRepository,
      chatModelRepository,
      moderationReportRepository,
      rateLimitService,
      service,
    };
  }

  it('should create a report for an accessible message', async () => {
    const fixture = await createFixture();
    const alice = await fixture.authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    const bob = await fixture.authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });
    const conversation = await fixture.chatModelRepository.createConversation({
      type: 'direct',
      createdBy: alice.id,
      memberIds: [alice.id, bob.id],
    });
    const message = await fixture.chatModelRepository.createMessage({
      conversationId: conversation.id,
      senderId: bob.id,
      clientMessageId: 'client-msg-1',
      type: 'text',
      content: {
        text: '辱骂内容',
      },
    });

    const report = await fixture.service.createReport(alice.id, {
      targetType: 'message',
      targetId: message.id,
      reasonCode: 'abuse',
      description: '存在辱骂内容',
    });

    expect(report).toMatchObject({
      reporterId: alice.id,
      targetType: 'message',
      targetId: message.id,
      conversationId: conversation.id,
      messageId: message.id,
      reportedUserId: bob.id,
      status: 'pending_review',
    });
  });

  it('should reject reports for messages outside the requester conversation scope', async () => {
    const fixture = await createFixture();
    const alice = await fixture.authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    const bob = await fixture.authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });
    const outsider = await fixture.authRepository.createUser({
      identifier: 'outsider@example.com',
      nickname: 'Outsider',
      handle: 'outsider_user',
    });
    const conversation = await fixture.chatModelRepository.createConversation({
      type: 'direct',
      createdBy: bob.id,
      memberIds: [bob.id, outsider.id],
    });
    const message = await fixture.chatModelRepository.createMessage({
      conversationId: conversation.id,
      senderId: outsider.id,
      clientMessageId: 'client-msg-2',
      type: 'text',
      content: {
        text: '外部消息',
      },
    });

    await expect(
      fixture.service.createReport(alice.id, {
        targetType: 'message',
        targetId: message.id,
        reasonCode: 'abuse',
      }),
    ).rejects.toThrow('你不能举报不可访问的消息');
  });

  it('should list reports filed by the current user', async () => {
    const fixture = await createFixture();
    const alice = await fixture.authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    const bob = await fixture.authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });

    await fixture.service.createReport(alice.id, {
      targetType: 'user',
      targetId: bob.id,
      reasonCode: 'spam',
      description: '频繁骚扰',
    });

    const reports = await fixture.service.listMyReports(alice.id);

    expect(reports).toHaveLength(1);
    expect(reports[0]).toMatchObject({
      reporterId: alice.id,
      targetType: 'user',
      targetId: bob.id,
      reasonCode: 'spam',
    });
  });
});
