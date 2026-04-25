import {
  ConsoleLogger,
  Injectable,
  type LogLevel,
  LoggerService,
} from '@nestjs/common';

import { RequestContextService } from '../observability/request-context.service';

import { AppConfigService } from '@app/infra/config/app-config.service';

type StructuredLogLevel = 'log' | 'error' | 'warn' | 'debug' | 'verbose' | 'fatal';

@Injectable()
export class AppLoggerService implements LoggerService {
  private readonly consoleLogger = new ConsoleLogger();
  private context?: string;
  private logLevels?: LogLevel[];

  constructor(
    private readonly appConfigService: AppConfigService,
    private readonly requestContextService: RequestContextService,
  ) {}

  setContext(context: string): void {
    this.context = context;
  }

  setLogLevels(levels: LogLevel[]): void {
    this.logLevels = levels;
    this.consoleLogger.setLogLevels(levels);
  }

  log(message: unknown, context?: string): void {
    this.write('log', message, undefined, context);
  }

  error(message: unknown, trace?: string, context?: string): void {
    this.write('error', message, trace, context);
  }

  warn(message: unknown, context?: string): void {
    this.write('warn', message, undefined, context);
  }

  debug(message: unknown, context?: string): void {
    this.write('debug', message, undefined, context);
  }

  verbose(message: unknown, context?: string): void {
    this.write('verbose', message, undefined, context);
  }

  fatal?(message: unknown, trace?: string, context?: string): void {
    this.write('fatal', message, trace, context);
  }

  logWithMetadata(
    level: StructuredLogLevel,
    message: string,
    metadata: Record<string, unknown>,
    context?: string,
  ): void {
    this.write(level, {
      message,
      metadata,
    }, undefined, context);
  }

  private write(
    level: StructuredLogLevel,
    message: unknown,
    trace?: string,
    context?: string,
  ): void {
    if (!this.isLevelEnabled(level)) {
      return;
    }

    const normalized = this.normalizeMessage(message);
    const requestContext = this.requestContextService.getContext();
    const payload = {
      timestamp: new Date().toISOString(),
      level,
      app: this.appConfigService.appName,
      env: this.appConfigService.nodeEnv,
      context: context ?? normalized.context ?? this.context,
      message: normalized.message,
      traceId: requestContext?.traceId,
      requestId: requestContext?.requestId,
      metadata: normalized.metadata,
      trace,
    };

    const serialized = JSON.stringify(payload);
    if (level === 'error' || level === 'fatal') {
      process.stderr.write(`${serialized}\n`);
      return;
    }

    process.stdout.write(`${serialized}\n`);
  }

  private normalizeMessage(message: unknown): {
    message: string;
    context?: string;
    metadata?: Record<string, unknown>;
  } {
    if (typeof message === 'string') {
      return {
        message,
      };
    }

    if (
      typeof message === 'object' &&
      message != null &&
      'message' in message &&
      typeof (message as { message?: unknown }).message === 'string'
    ) {
      const candidate = message as {
        message: string;
        context?: unknown;
        metadata?: unknown;
      };

      return {
        message: candidate.message,
        context:
          typeof candidate.context === 'string' ? candidate.context : undefined,
        metadata:
          candidate.metadata != null && typeof candidate.metadata === 'object'
            ? (candidate.metadata as Record<string, unknown>)
            : undefined,
      };
    }

    return {
      message: 'structured-log',
      metadata:
        message != null && typeof message === 'object'
          ? (message as Record<string, unknown>)
          : {
              value: message,
            },
    };
  }

  private isLevelEnabled(level: StructuredLogLevel): boolean {
    if (this.logLevels == null || this.logLevels.length === 0) {
      return true;
    }

    const enabledLevels = new Set(this.logLevels);

    if (level === 'fatal') {
      return enabledLevels.has('error');
    }

    return enabledLevels.has(level);
  }
}
