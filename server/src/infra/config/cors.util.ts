export function parseCorsAllowedOrigins(rawValue: string): string[] {
  return rawValue
    .split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
}

export function resolveCorsOriginOption(
  allowedOrigins: string[],
): boolean | string[] {
  if (allowedOrigins.length === 1 && allowedOrigins[0] === '*') {
    return true;
  }

  return allowedOrigins.length > 0 ? allowedOrigins : false;
}

export function assertCorsAllowedOrigins(
  nodeEnv: string,
  allowedOrigins: string[],
): void {
  if (allowedOrigins.length === 0) {
    throw new Error('CORS_ALLOWED_ORIGINS must contain at least one origin');
  }

  if (allowedOrigins.includes('*') && allowedOrigins.length > 1) {
    throw new Error('CORS_ALLOWED_ORIGINS cannot mix "*" with explicit origins');
  }

  if (
    (nodeEnv === 'production' || nodeEnv === 'staging') &&
    allowedOrigins.includes('*')
  ) {
    throw new Error(
      'CORS_ALLOWED_ORIGINS must not contain "*" in production or staging',
    );
  }
}
