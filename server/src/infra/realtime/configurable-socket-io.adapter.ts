import type { INestApplicationContext } from '@nestjs/common';
import { IoAdapter } from '@nestjs/platform-socket.io';

import type { AppConfigService } from '@app/infra/config/app-config.service';
import { resolveCorsOriginOption } from '@app/infra/config/cors.util';

export class ConfigurableSocketIoAdapter extends IoAdapter {
  constructor(
    app: INestApplicationContext,
    private readonly appConfigService: Pick<AppConfigService, 'corsAllowedOrigins'>,
  ) {
    super(app);
  }

  override createIOServer(
    port: number,
    options?: Parameters<IoAdapter['createIOServer']>[1],
  ): unknown {
    const resolvedCors = resolveCorsOriginOption(
      this.appConfigService.corsAllowedOrigins,
    );

    return super.createIOServer(port, {
      ...options,
      cors: {
        ...(typeof options?.cors === 'object' ? options.cors : {}),
        origin: resolvedCors,
        credentials: true,
      },
    });
  }
}
