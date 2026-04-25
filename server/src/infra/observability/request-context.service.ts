import { AsyncLocalStorage } from 'node:async_hooks';

import { Injectable } from '@nestjs/common';

export interface RequestContextValue {
  readonly requestId: string;
  readonly traceId: string;
  readonly routeKey?: string;
  readonly actorId?: string;
}

@Injectable()
export class RequestContextService {
  private readonly asyncLocalStorage =
    new AsyncLocalStorage<RequestContextValue>();

  run<T>(context: RequestContextValue, callback: () => T): T {
    return this.asyncLocalStorage.run(context, callback);
  }

  getContext(): RequestContextValue | undefined {
    return this.asyncLocalStorage.getStore();
  }
}
