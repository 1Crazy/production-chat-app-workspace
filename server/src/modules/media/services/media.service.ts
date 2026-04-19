import { Injectable } from '@nestjs/common';

@Injectable()
export class MediaService {
  getHealth(): { module: string; status: string } {
    return {
      module: 'media',
      status: 'ready',
    };
  }
}
