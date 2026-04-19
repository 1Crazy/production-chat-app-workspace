import { Injectable } from '@nestjs/common';

@Injectable()
export class NotificationsService {
  getHealth(): { module: string; status: string } {
    return {
      module: 'notifications',
      status: 'ready',
    };
  }
}
