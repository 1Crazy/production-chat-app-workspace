import { randomUUID } from 'node:crypto';

import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { Observable, throwError } from 'rxjs';
import { catchError, tap } from 'rxjs/operators';

import { AppLoggerService } from '../logger/app-logger.service';

import { MetricsRegistryService } from './metrics-registry.service';
import { RequestContextService } from './request-context.service';

@Injectable()
export class HttpObservabilityInterceptor implements NestInterceptor {
  constructor(
    private readonly requestContextService: RequestContextService,
    private readonly metricsRegistryService: MetricsRegistryService,
    private readonly appLoggerService: AppLoggerService,
  ) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType<'http' | 'ws' | 'rpc'>() !== 'http') {
      return next.handle();
    }

    const httpContext = context.switchToHttp();
    const request = httpContext.getRequest<Request>();
    const response = httpContext.getResponse<Response>();
    const startedAt = process.hrtime.bigint();
    const requestId =
      this.readHeader(request, 'x-request-id') ?? randomUUID().replaceAll('-', '');
    const traceId =
      this.readHeader(request, 'x-trace-id') ?? randomUUID().replaceAll('-', '');
    const routeKey = this.buildRouteKey(request);

    response.setHeader('x-request-id', requestId);
    response.setHeader('x-trace-id', traceId);

    return this.requestContextService.run(
      {
        requestId,
        traceId,
        routeKey,
      },
      () => {
        return next.handle().pipe(
          tap(() => {
            this.recordHttpMetric({
              startedAt,
              request,
              response,
              routeKey,
              outcome: 'success',
            });
          }),
          catchError((error: unknown) => {
            this.recordHttpMetric({
              startedAt,
              request,
              response,
              routeKey,
              outcome: 'error',
              error,
            });
            return throwError(() => error);
          }),
        );
      },
    );
  }

  private recordHttpMetric(params: {
    startedAt: bigint;
    request: Request;
    response: Response;
    routeKey: string;
    outcome: 'success' | 'error';
    error?: unknown;
  }): void {
    const durationMs =
      Number(process.hrtime.bigint() - params.startedAt) / 1_000_000;
    const statusCode =
      params.error != null && params.response.statusCode < 400
        ? 500
        : params.response.statusCode;
    const labels = {
      method: params.request.method,
      route: params.routeKey,
      status_code: statusCode,
      outcome: params.outcome,
    };

    this.metricsRegistryService.incrementCounter('http_server_requests_total', {
      help: 'Total number of HTTP requests handled by the application.',
      labels,
    });
    this.metricsRegistryService.observeSummary(
      'http_server_request_duration_ms',
      {
        help: 'Observed HTTP request duration in milliseconds.',
        value: durationMs,
        labels,
      },
    );

    if (params.outcome === 'error') {
      this.metricsRegistryService.incrementCounter('http_server_errors_total', {
        help: 'Total number of failed HTTP requests.',
        labels,
      });
    }

    this.appLoggerService.logWithMetadata(
      params.outcome === 'error' ? 'error' : 'log',
      'http_request_completed',
      {
        method: params.request.method,
        route: params.routeKey,
        originalUrl: params.request.originalUrl,
        statusCode,
        durationMs: Number(durationMs.toFixed(2)),
        outcome: params.outcome,
        error:
          params.error instanceof Error
            ? {
                name: params.error.name,
                message: params.error.message,
              }
            : undefined,
      },
      'HttpObservabilityInterceptor',
    );
  }

  private buildRouteKey(request: Request): string {
    const routePath =
      typeof request.route?.path === 'string' ? request.route.path : undefined;
    const baseUrl = request.baseUrl || '';

    if (routePath != null) {
      return `${request.method} ${baseUrl}${routePath}`;
    }

    return `${request.method} ${request.originalUrl || request.url}`;
  }

  private readHeader(request: Request, headerName: string): string | undefined {
    const value = request.headers[headerName];

    if (typeof value !== 'string') {
      return undefined;
    }

    const normalized = value.trim();
    return normalized.length > 0 ? normalized : undefined;
  }
}
