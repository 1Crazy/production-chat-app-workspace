import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { BanUserDto } from '../dto/ban-user.dto';
import { ListAdminReportsQueryDto } from '../dto/list-admin-reports-query.dto';
import { ProcessReportDto } from '../dto/process-report.dto';
import { AdminAccessGuard } from '../guards/admin-access.guard';
import { AdminService } from '../services/admin.service';

import { AccessTokenGuard } from '@app/modules/auth/guards/access-token.guard';
import type { AuthenticatedRequest } from '@app/modules/auth/types/authenticated-request.type';

@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.adminService.getHealth();
  }

  @UseGuards(AccessTokenGuard, AdminAccessGuard)
  @Get('overview')
  getOverview() {
    return this.adminService.getOverview();
  }

  @UseGuards(AccessTokenGuard, AdminAccessGuard)
  @Get('reports')
  listReports(@Query() query: ListAdminReportsQueryDto) {
    return this.adminService.listReports(query);
  }

  @UseGuards(AccessTokenGuard, AdminAccessGuard)
  @Patch('reports/:reportId')
  processReport(
    @Req() request: AuthenticatedRequest,
    @Param('reportId') reportId: string,
    @Body() dto: ProcessReportDto,
  ) {
    return this.adminService.processReport({
      adminUserId: request.auth.user.id,
      reportId,
      dto,
    });
  }

  @UseGuards(AccessTokenGuard, AdminAccessGuard)
  @Get('users/:userId')
  getUserDetail(@Param('userId') userId: string) {
    return this.adminService.getUserDetail(userId);
  }

  @UseGuards(AccessTokenGuard, AdminAccessGuard)
  @Post('users/:userId/ban')
  banUser(
    @Req() request: AuthenticatedRequest,
    @Param('userId') userId: string,
    @Body() dto: BanUserDto,
  ) {
    return this.adminService.banUser({
      adminUserId: request.auth.user.id,
      userId,
      dto,
    });
  }

  @UseGuards(AccessTokenGuard, AdminAccessGuard)
  @Get('conversations/:conversationId')
  getConversationDetail(
    @Param('conversationId') conversationId: string,
  ) {
    return this.adminService.getConversationDetail(conversationId);
  }

  @UseGuards(AccessTokenGuard, AdminAccessGuard)
  @Delete('sessions/:sessionId')
  revokeSession(
    @Req() request: AuthenticatedRequest,
    @Param('sessionId') sessionId: string,
  ) {
    return this.adminService.revokeSession({
      adminUserId: request.auth.user.id,
      sessionId,
    });
  }

  @UseGuards(AccessTokenGuard, AdminAccessGuard)
  @Get('audit-logs')
  listAuditLogs() {
    return this.adminService.listAuditLogs();
  }
}
