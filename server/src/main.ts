import helmet from 'helmet';
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

  // 安全响应头：添加 CSP、HSTS、X-Content-Type-Options 等 HTTP 安全头。
  app.use(helmet());

  // 只允许配置的白名单域名跨域访问，生产环境不应使用通配符。
  const allowedOrigins = config.corsAllowedOrigins;
  const corsOrigin =
    allowedOrigins.length === 1 && allowedOrigins[0] === '*'
      ? true
      : allowedOrigins.length > 0
        ? allowedOrigins
        : false;

  app.enableCors({
    origin: corsOrigin,
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
