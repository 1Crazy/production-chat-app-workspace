import { Controller, Get } from '@nestjs/common';

import { GroupsService } from '../services/groups.service';

@Controller('groups')
export class GroupsController {
  constructor(private readonly groupsService: GroupsService) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.groupsService.getHealth();
  }
}
