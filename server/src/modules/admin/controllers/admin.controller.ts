import { Controller, Get } from '@nestjs/common';

import { AdminService } from '../services/admin.service';

@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.adminService.getHealth();
  }
}
