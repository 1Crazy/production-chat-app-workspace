import { Injectable } from '@nestjs/common';

@Injectable()
export class AdminService {
  getHealth(): { module: string; status: string } {
    return {
      module: 'admin',
      status: 'ready',
    };
  }
}
