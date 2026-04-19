import { Injectable } from '@nestjs/common';

@Injectable()
export class ModerationService {
  getHealth(): { module: string; status: string } {
    return {
      module: 'moderation',
      status: 'ready',
    };
  }
}
