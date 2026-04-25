import type { INestApplicationContext } from '@nestjs/common';
import { IoAdapter } from '@nestjs/platform-socket.io';

import { ConfigurableSocketIoAdapter } from './configurable-socket-io.adapter';

describe('ConfigurableSocketIoAdapter', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should override gateway CORS with the configured allowlist', () => {
    const createIOServerSpy = jest
      .spyOn(IoAdapter.prototype, 'createIOServer')
      .mockReturnValue({} as never);
    const adapter = new ConfigurableSocketIoAdapter(
      {} as INestApplicationContext,
      {
        corsAllowedOrigins: ['https://chat.example.com'],
      },
    );

    adapter.createIOServer(3000, {
      namespace: '/chat',
      cors: {
        origin: '*',
      },
    });

    expect(createIOServerSpy).toHaveBeenCalledWith(
      3000,
      expect.objectContaining({
        namespace: '/chat',
        cors: {
          origin: ['https://chat.example.com'],
          credentials: true,
        },
      }),
    );
  });

  it('should translate wildcard CORS to reflected origins for credentialed sockets', () => {
    const createIOServerSpy = jest
      .spyOn(IoAdapter.prototype, 'createIOServer')
      .mockReturnValue({} as never);
    const adapter = new ConfigurableSocketIoAdapter(
      {} as INestApplicationContext,
      {
        corsAllowedOrigins: ['*'],
      },
    );

    adapter.createIOServer(3000, {});

    expect(createIOServerSpy).toHaveBeenCalledWith(
      3000,
      expect.objectContaining({
        cors: {
          origin: true,
          credentials: true,
        },
      }),
    );
  });
});
