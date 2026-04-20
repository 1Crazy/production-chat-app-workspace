import { Body, Controller, Get, Req, UseGuards, Post } from '@nestjs/common';

import { RegisterPushTokenDto } from '../dto/register-push-token.dto';
import { NotificationsService } from '../services/notifications.service';

import { AccessTokenGuard } from '@app/modules/auth/guards/access-token.guard';
import type { AuthenticatedRequest } from '@app/modules/auth/types/authenticated-request.type';

@Controller('notifications')
export class NotificationsController {
  constructor(
    private readonly notificationsService: NotificationsService,
  ) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.notificationsService.getHealth();
  }

  @UseGuards(AccessTokenGuard)
  @Post('push-registrations')
  registerPushToken(
    @Req() request: AuthenticatedRequest,
    @Body() dto: RegisterPushTokenDto,
  ) {
    return this.notificationsService.registerPushToken({
      userId: request.auth.user.id,
      session: request.auth.session,
      dto,
    });
  }

  @UseGuards(AccessTokenGuard)
  @Get('push-registrations')
  listActiveRegistrations(@Req() request: AuthenticatedRequest) {
    return this.notificationsService.listActiveRegistrations(
      request.auth.user.id,
      request.auth.session.id,
    );
  }
}
