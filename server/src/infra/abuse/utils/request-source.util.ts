import type { Request } from 'express';

export function extractRequestSourceKey(request: Request): string {
  return (
    request.ip ||
    request.socket.remoteAddress ||
    'unknown-source'
  ).trim().toLowerCase();
}
