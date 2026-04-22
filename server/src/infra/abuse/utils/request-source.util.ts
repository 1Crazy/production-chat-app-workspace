import type { Request } from 'express';

export function extractRequestSourceKey(request: Request): string {
  const forwardedFor = request.headers['x-forwarded-for'];

  if (typeof forwardedFor === 'string' && forwardedFor.trim().length > 0) {
    return forwardedFor.split(',')[0]!.trim().toLowerCase();
  }

  if (Array.isArray(forwardedFor) && forwardedFor[0]?.trim().length) {
    return forwardedFor[0].trim().toLowerCase();
  }

  return (
    request.ip ||
    request.socket.remoteAddress ||
    'unknown-source'
  ).trim().toLowerCase();
}
