import { Injectable, NotFoundException } from '@nestjs/common';

import type { ModerationReportEntity } from '../entities/moderation-report.entity';

import { ModerationReportRepository } from './moderation-report.repository';

import { PrismaService } from '@app/infra/database/prisma.service';

@Injectable()
export class PrismaModerationReportRepository
  extends ModerationReportRepository
{
  constructor(private readonly prismaService: PrismaService) {
    super();
  }

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
    const report = await this.moderationReportModel.create({
      data: {
        reporterId: params.reporterId,
        targetType: params.targetType,
        targetId: params.targetId,
        conversationId: params.conversationId,
        messageId: params.messageId,
        reportedUserId: params.reportedUserId,
        reasonCode: params.reasonCode,
        description: params.description,
      },
    });

    return this.toEntity(report);
  }

  override async listReportsByReporter(
    reporterId: string,
  ): Promise<ModerationReportEntity[]> {
    const reports = await this.moderationReportModel.findMany({
      where: {
        reporterId,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return reports.map((report) => this.toEntity(report));
  }

  override async listReports(params?: {
    status?: ModerationReportEntity['status'];
  }): Promise<ModerationReportEntity[]> {
    const reports = await this.moderationReportModel.findMany({
      where: {
        ...(params?.status ? { status: params.status } : {}),
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return reports.map((report) => this.toEntity(report));
  }

  override async getReportOrThrow(
    reportId: string,
  ): Promise<ModerationReportEntity> {
    const report = await this.moderationReportModel.findUnique({
      where: {
        id: reportId,
      },
    });

    if (!report) {
      throw new NotFoundException('举报记录不存在');
    }

    return this.toEntity(report);
  }

  override async saveReport(report: ModerationReportEntity): Promise<void> {
    await this.moderationReportModel.update({
      where: {
        id: report.id,
      },
      data: {
        status: report.status,
        resolutionNote: report.resolutionNote,
        handledByUserId: report.handledByUserId,
        handledAt: report.handledAt,
      },
    });
  }

  private get moderationReportModel(): {
    create(params: {
      data: {
        reporterId: string;
        targetType: string;
        targetId: string;
        conversationId: string | null;
        messageId: string | null;
        reportedUserId: string | null;
        reasonCode: string;
        description: string | null;
      };
    }): Promise<{
      id: string;
      reporterId: string;
      targetType: string;
      targetId: string;
      conversationId: string | null;
      messageId: string | null;
      reportedUserId: string | null;
      reasonCode: string;
      description: string | null;
      status: string;
      resolutionNote: string | null;
      handledByUserId: string | null;
      handledAt: Date | null;
      createdAt: Date;
      updatedAt: Date;
    }>;
    findMany(params: {
      where: {
        reporterId?: string;
        status?: string;
      };
      orderBy: {
        createdAt: 'desc';
      };
    }): Promise<Array<{
      id: string;
      reporterId: string;
      targetType: string;
      targetId: string;
      conversationId: string | null;
      messageId: string | null;
      reportedUserId: string | null;
      reasonCode: string;
      description: string | null;
      status: string;
      resolutionNote: string | null;
      handledByUserId: string | null;
      handledAt: Date | null;
      createdAt: Date;
      updatedAt: Date;
    }>>;
    findUnique(params: {
      where: {
        id: string;
      };
    }): Promise<{
      id: string;
      reporterId: string;
      targetType: string;
      targetId: string;
      conversationId: string | null;
      messageId: string | null;
      reportedUserId: string | null;
      reasonCode: string;
      description: string | null;
      status: string;
      resolutionNote: string | null;
      handledByUserId: string | null;
      handledAt: Date | null;
      createdAt: Date;
      updatedAt: Date;
    } | null>;
    update(params: {
      where: {
        id: string;
      };
      data: {
        status: string;
        resolutionNote: string | null;
        handledByUserId: string | null;
        handledAt: Date | null;
      };
    }): Promise<unknown>;
  } {
    return (
      this.prismaService as PrismaService & {
      moderationReport: {
        create: (params: {
          data: {
            reporterId: string;
            targetType: string;
            targetId: string;
            conversationId: string | null;
            messageId: string | null;
            reportedUserId: string | null;
            reasonCode: string;
            description: string | null;
          };
        }) => Promise<{
          id: string;
          reporterId: string;
          targetType: string;
          targetId: string;
          conversationId: string | null;
          messageId: string | null;
          reportedUserId: string | null;
          reasonCode: string;
          description: string | null;
          status: string;
          resolutionNote: string | null;
          handledByUserId: string | null;
          handledAt: Date | null;
          createdAt: Date;
          updatedAt: Date;
        }>;
          findMany: (params: {
            where: {
              reporterId?: string;
              status?: string;
            };
            orderBy: {
              createdAt: 'desc';
          };
        }) => Promise<Array<{
          id: string;
          reporterId: string;
          targetType: string;
          targetId: string;
          conversationId: string | null;
          messageId: string | null;
          reportedUserId: string | null;
          reasonCode: string;
          description: string | null;
          status: string;
          resolutionNote: string | null;
          handledByUserId: string | null;
          handledAt: Date | null;
            createdAt: Date;
            updatedAt: Date;
          }>>;
          findUnique: (params: {
            where: {
              id: string;
            };
          }) => Promise<{
            id: string;
            reporterId: string;
            targetType: string;
            targetId: string;
            conversationId: string | null;
            messageId: string | null;
            reportedUserId: string | null;
            reasonCode: string;
            description: string | null;
            status: string;
            resolutionNote: string | null;
            handledByUserId: string | null;
            handledAt: Date | null;
            createdAt: Date;
            updatedAt: Date;
          } | null>;
          update: (params: {
            where: {
              id: string;
            };
            data: {
              status: string;
              resolutionNote: string | null;
              handledByUserId: string | null;
              handledAt: Date | null;
            };
          }) => Promise<unknown>;
        };
      }
    ).moderationReport;
  }

  private toEntity(report: {
    id: string;
    reporterId: string;
    targetType: string;
    targetId: string;
    conversationId: string | null;
    messageId: string | null;
    reportedUserId: string | null;
    reasonCode: string;
    description: string | null;
    status: string;
    resolutionNote: string | null;
    handledByUserId: string | null;
    handledAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
  }): ModerationReportEntity {
    return {
      id: report.id,
      reporterId: report.reporterId,
      targetType: report.targetType as ModerationReportEntity['targetType'],
      targetId: report.targetId,
      conversationId: report.conversationId,
      messageId: report.messageId,
      reportedUserId: report.reportedUserId,
      reasonCode: report.reasonCode,
      description: report.description,
      status: report.status as ModerationReportEntity['status'],
      resolutionNote: report.resolutionNote,
      handledByUserId: report.handledByUserId,
      handledAt: report.handledAt,
      createdAt: report.createdAt,
      updatedAt: report.updatedAt,
    };
  }
}
