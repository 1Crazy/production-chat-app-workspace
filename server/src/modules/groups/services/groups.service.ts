import { Injectable } from '@nestjs/common';

@Injectable()
export class GroupsService {
  getHealth(): { module: string; status: string } {
    return {
      module: 'groups',
      status: 'ready',
    };
  }
}
