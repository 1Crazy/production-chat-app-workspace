import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';

import { AppModule } from './app.module';
import { AppConfigService } from './infra/config/app-config.service';
import { AppLoggerService } from './infra/logger/app-logger.service';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
  });
  const config = app.get(AppConfigService);
  const logger = app.get(AppLoggerService);

  app.useLogger(logger);

  // 全局校验放在入口层统一启用，避免每个 controller 重复配置。
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  await app.listen(config.port, '0.0.0.0');
  logger.logWithMetadata(
    'log',
    'application_bootstrap_complete',
    {
      host: '0.0.0.0',
      port: config.port,
      healthEndpoint: '/ops/health',
      metricsEndpoint: '/ops/metrics',
    },
    'Bootstrap',
  );
}

void bootstrap();
