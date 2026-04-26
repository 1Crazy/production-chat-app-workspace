import type { Request } from 'express';

import { extractRequestSourceKey } from './request-source.util';

describe('extractRequestSourceKey', () => {
  it('should ignore spoofed x-forwarded-for headers unless express already resolved request.ip', () => {
    const request = {
      headers: {
        'x-forwarded-for': '203.0.113.10',
      },
      ip: '10.0.0.5',
      socket: {
        remoteAddress: '10.0.0.6',
      },
    } as unknown as Request;

    expect(extractRequestSourceKey(request)).toBe('10.0.0.5');
  });

  it('should use the express-resolved request ip when trust proxy is enabled upstream', () => {
    const request = {
      headers: {
        'x-forwarded-for': '203.0.113.10',
      },
      ip: '203.0.113.10',
      socket: {
        remoteAddress: '10.0.0.6',
      },
    } as unknown as Request;

    expect(extractRequestSourceKey(request)).toBe('203.0.113.10');
  });

  it('should fall back to the socket remote address when request.ip is unavailable', () => {
    const request = {
      headers: {},
      socket: {
        remoteAddress: '10.0.0.6',
      },
    } as unknown as Request;

    expect(extractRequestSourceKey(request)).toBe('10.0.0.6');
  });
});
