import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';

import { AppModule } from './app.module';
import { AppConfigService } from './infra/config/app-config.service';
import { resolveCorsOriginOption } from './infra/config/cors.util';
import { AppLoggerService } from './infra/logger/app-logger.service';
import { ConfigurableSocketIoAdapter } from './infra/realtime/configurable-socket-io.adapter';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
  });
  const config = app.get(AppConfigService);
  const logger = app.get(AppLoggerService);
  const expressApp = app.getHttpAdapter().getInstance();

  app.useLogger(logger);
  expressApp.set('trust proxy', config.trustProxy);

  // 安全响应头：添加 CSP、HSTS、X-Content-Type-Options 等 HTTP 安全头。
  app.use(helmet());
  app.useWebSocketAdapter(new ConfigurableSocketIoAdapter(app, config));

  app.enableCors({
    origin: resolveCorsOriginOption(config.corsAllowedOrigins),
    credentials: true,
  });

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
