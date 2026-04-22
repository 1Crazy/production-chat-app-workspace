import {
  ForbiddenException,
  Injectable,
} from '@nestjs/common';

import { CreateModerationReportDto } from '../dto/create-report.dto';
import {
  toModerationReportView,
  type ModerationReportView,
} from '../dto/moderation-report.dto';
import { ModerationReportRepository } from '../repositories/moderation-report.repository';

import { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';

@Injectable()
export class ModerationService {
  constructor(
    private readonly moderationReportRepository: ModerationReportRepository,
    private readonly chatModelRepository: ChatModelRepository,
    private readonly authIdentityService: AuthIdentityService,
    private readonly rateLimitService: RateLimitService,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'moderation',
      status: 'ready',
    };
  }

  async createReport(
    reporterUserId: string,
    dto: CreateModerationReportDto,
  ): Promise<ModerationReportView> {
    await this.rateLimitService.consumeOrThrow({
      scope: 'moderation.create-report',
      actorKey: reporterUserId,
      limit: 10,
      windowMs: 60 * 60 * 1000,
      message: '举报过于频繁，请稍后再试',
      metadata: {
        targetType: dto.targetType,
        targetId: dto.targetId,
      },
    });

    const target = await this.resolveReportTarget(reporterUserId, dto);
    const report = await this.moderationReportRepository.createReport({
      reporterId: reporterUserId,
      targetType: dto.targetType,
      targetId: dto.targetId,
      conversationId: target.conversationId,
      messageId: target.messageId,
      reportedUserId: target.reportedUserId,
      reasonCode: dto.reasonCode.trim(),
      description: dto.description?.trim() || null,
    });

    return toModerationReportView(report);
  }

  async listMyReports(reporterUserId: string): Promise<ModerationReportView[]> {
    await this.authIdentityService.getActiveUserById(reporterUserId);
    const reports =
      await this.moderationReportRepository.listReportsByReporter(
        reporterUserId,
      );

    return reports.map((report) => toModerationReportView(report));
  }

  private async resolveReportTarget(
    reporterUserId: string,
    dto: CreateModerationReportDto,
  ): Promise<{
    conversationId: string | null;
    messageId: string | null;
    reportedUserId: string | null;
  }> {
    switch (dto.targetType) {
      case 'message': {
        const message = await this.chatModelRepository.getMessageOrThrow(
          dto.targetId,
        );

        if (
          !(await this.chatModelRepository.isConversationMember(
            message.conversationId,
            reporterUserId,
          ))
        ) {
          throw new ForbiddenException('你不能举报不可访问的消息');
        }

        return {
          conversationId: message.conversationId,
          messageId: message.id,
          reportedUserId: message.senderId,
        };
      }
      case 'conversation': {
        await this.chatModelRepository.getConversationOrThrow(dto.targetId);

        if (
          !(await this.chatModelRepository.isConversationMember(
            dto.targetId,
            reporterUserId,
          ))
        ) {
          throw new ForbiddenException('你不能举报不可访问的会话');
        }

        return {
          conversationId: dto.targetId,
          messageId: null,
          reportedUserId: null,
        };
      }
      case 'user': {
        const reportedUser = await this.authIdentityService.getActiveUserById(
          dto.targetId,
        );

        if (reportedUser.id === reporterUserId) {
          throw new ForbiddenException('不能举报自己');
        }

        return {
          conversationId: null,
          messageId: null,
          reportedUserId: reportedUser.id,
        };
      }
    }
  }
}
