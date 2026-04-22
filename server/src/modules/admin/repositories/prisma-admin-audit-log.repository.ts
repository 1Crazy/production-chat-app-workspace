import { Injectable } from '@nestjs/common';

import type { AdminAuditLogEntity } from '../entities/admin-audit-log.entity';

import { AdminAuditLogRepository } from './admin-audit-log.repository';

import { PrismaService } from '@app/infra/database/prisma.service';

@Injectable()
export class PrismaAdminAuditLogRepository extends AdminAuditLogRepository {
  constructor(private readonly prismaService: PrismaService) {
    super();
  }

  override async createLog(params: {
    actorUserId: string | null;
    action: string;
    targetType: string;
    targetId: string;
    result: AdminAuditLogEntity['result'];
    summary: string;
    metadata: Record<string, unknown> | null;
  }): Promise<AdminAuditLogEntity> {
    const log = await this.adminAuditLogModel.create({
      data: {
        actorUserId: params.actorUserId,
        action: params.action,
        targetType: params.targetType,
        targetId: params.targetId,
        result: params.result,
        summary: params.summary,
        metadata: params.metadata,
      },
    });

    return this.toEntity(log);
  }

  override async listLogs(params?: {
    action?: string;
  }): Promise<AdminAuditLogEntity[]> {
    const logs = await this.adminAuditLogModel.findMany({
      where: {
        ...(params?.action ? { action: params.action } : {}),
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return logs.map((log) => this.toEntity(log));
  }

  private get adminAuditLogModel(): {
    create(params: {
      data: {
        actorUserId: string | null;
        action: string;
        targetType: string;
        targetId: string;
        result: string;
        summary: string;
        metadata: Record<string, unknown> | null;
      };
    }): Promise<{
      id: string;
      actorUserId: string | null;
      action: string;
      targetType: string;
      targetId: string;
      result: string;
      summary: string;
      metadata: Record<string, unknown> | null;
      createdAt: Date;
    }>;
    findMany(params: {
      where: {
        action?: string;
      };
      orderBy: {
        createdAt: 'desc';
      };
    }): Promise<Array<{
      id: string;
      actorUserId: string | null;
      action: string;
      targetType: string;
      targetId: string;
      result: string;
      summary: string;
      metadata: Record<string, unknown> | null;
      createdAt: Date;
    }>>;
  } {
    return (
      this.prismaService as PrismaService & {
        adminAuditLog: {
          create: (params: {
            data: {
              actorUserId: string | null;
              action: string;
              targetType: string;
              targetId: string;
              result: string;
              summary: string;
              metadata: Record<string, unknown> | null;
            };
          }) => Promise<{
            id: string;
            actorUserId: string | null;
            action: string;
            targetType: string;
            targetId: string;
            result: string;
            summary: string;
            metadata: Record<string, unknown> | null;
            createdAt: Date;
          }>;
          findMany: (params: {
            where: {
              action?: string;
            };
            orderBy: {
              createdAt: 'desc';
            };
          }) => Promise<Array<{
            id: string;
            actorUserId: string | null;
            action: string;
            targetType: string;
            targetId: string;
            result: string;
            summary: string;
            metadata: Record<string, unknown> | null;
            createdAt: Date;
          }>>;
        };
      }
    ).adminAuditLog;
  }

  private toEntity(log: {
    id: string;
    actorUserId: string | null;
    action: string;
    targetType: string;
    targetId: string;
    result: string;
    summary: string;
    metadata: Record<string, unknown> | null;
    createdAt: Date;
  }): AdminAuditLogEntity {
    return {
      id: log.id,
      actorUserId: log.actorUserId,
      action: log.action,
      targetType: log.targetType,
      targetId: log.targetId,
      result: log.result as AdminAuditLogEntity['result'],
      summary: log.summary,
      metadata: log.metadata,
      createdAt: log.createdAt,
    };
  }
}
