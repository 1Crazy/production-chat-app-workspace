import { Controller, Get } from '@nestjs/common';

import { ModerationService } from '../services/moderation.service';

@Controller('moderation')
export class ModerationController {
  constructor(private readonly moderationService: ModerationService) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.moderationService.getHealth();
  }
}
