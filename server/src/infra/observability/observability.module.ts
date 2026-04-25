import { Global, Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';

import { AppLoggerService } from '../logger/app-logger.service';

import { HttpObservabilityInterceptor } from './http-observability.interceptor';
import { MetricsRegistryService } from './metrics-registry.service';
import { ObservabilityController } from './observability.controller';
import { RequestContextService } from './request-context.service';

@Global()
@Module({
  controllers: [ObservabilityController],
  providers: [
    RequestContextService,
    MetricsRegistryService,
    AppLoggerService,
    {
      provide: APP_INTERCEPTOR,
      useClass: HttpObservabilityInterceptor,
    },
  ],
  exports: [AppLoggerService, MetricsRegistryService, RequestContextService],
})
export class ObservabilityModule {}
