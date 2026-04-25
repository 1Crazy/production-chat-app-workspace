import { Controller, Get, Header } from '@nestjs/common';

import { MetricsRegistryService } from './metrics-registry.service';

import { AppConfigService } from '@app/infra/config/app-config.service';

@Controller('ops')
export class ObservabilityController {
  constructor(
    private readonly appConfigService: AppConfigService,
    private readonly metricsRegistryService: MetricsRegistryService,
  ) {}

  @Get('health')
  getHealth(): {
    app: string;
    env: string;
    status: 'ready';
    serverTime: string;
    uptimeSeconds: number;
  } {
    return {
      app: this.appConfigService.appName,
      env: this.appConfigService.nodeEnv,
      status: 'ready',
      serverTime: new Date().toISOString(),
      uptimeSeconds: Math.round(process.uptime()),
    };
  }

  @Get('metrics')
  @Header('Content-Type', 'text/plain; version=0.0.4; charset=utf-8')
  getMetrics(): string {
    return this.metricsRegistryService.renderPrometheus();
  }

  @Get('metrics/summary')
  getMetricsSummary(): Record<string, unknown> {
    return this.metricsRegistryService.getSnapshot();
  }
}
