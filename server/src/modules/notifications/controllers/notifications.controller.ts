import { Controller, Get } from '@nestjs/common';

import { NotificationsService } from '../services/notifications.service';

@Controller('notifications')
export class NotificationsController {
  constructor(
    private readonly notificationsService: NotificationsService,
  ) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.notificationsService.getHealth();
  }
}
