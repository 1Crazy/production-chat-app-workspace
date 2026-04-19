import { Module } from '@nestjs/common';

import { AppLoggerService } from '../logger/app-logger.service';

@Module({
  providers: [AppLoggerService],
  exports: [AppLoggerService],
})
export class ObservabilityModule {}
