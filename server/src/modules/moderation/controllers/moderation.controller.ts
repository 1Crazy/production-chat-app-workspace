import {
  Body,
  Controller,
  Get,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { CreateModerationReportDto } from '../dto/create-report.dto';
import { ModerationService } from '../services/moderation.service';

import { AccessTokenGuard } from '@app/modules/auth/guards/access-token.guard';
import type { AuthenticatedRequest } from '@app/modules/auth/types/authenticated-request.type';

@Controller('moderation')
export class ModerationController {
  constructor(private readonly moderationService: ModerationService) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.moderationService.getHealth();
  }

  @UseGuards(AccessTokenGuard)
  @Post('reports')
  createReport(
    @Req() request: AuthenticatedRequest,
    @Body() dto: CreateModerationReportDto,
  ) {
    return this.moderationService.createReport(request.auth.user.id, dto);
  }

  @UseGuards(AccessTokenGuard)
  @Get('reports/mine')
  listMyReports(@Req() request: AuthenticatedRequest) {
    return this.moderationService.listMyReports(request.auth.user.id);
  }
}
