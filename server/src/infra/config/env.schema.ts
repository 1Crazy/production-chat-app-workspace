import { assertCorsAllowedOrigins, parseCorsAllowedOrigins } from './cors.util';

export interface AppEnvironment {
  readonly appName: string;
  readonly nodeEnv: string;
  readonly port: number;
  readonly trustProxy?: string;
  readonly corsAllowedOrigins: string;
  readonly databaseUrl: string;
  readonly redisUrl: string;
  readonly jwtAccessSecret: string;
  readonly jwtRefreshSecret: string;
  readonly s3Endpoint: string;
  readonly s3Bucket: string;
  readonly s3AccessKey: string;
  readonly s3SecretKey: string;
  readonly fcmProjectId?: string;
  readonly fcmClientEmail?: string;
  readonly fcmPrivateKey?: string;
  readonly apnsTeamId?: string;
  readonly apnsKeyId?: string;
  readonly apnsBundleId?: string;
  readonly apnsPrivateKey?: string;
  readonly adminHandles?: string;
  readonly authDebugCodeEnabled: boolean;
  readonly authCodeDeliveryMode: 'debug' | 'webhook';
  readonly authCodeWebhookUrl?: string;
  readonly authCodeWebhookSecret?: string;
  readonly authCodeEmailFrom?: string;
  readonly authCodeEmailNickname?: string;
  readonly authCodeEmailHandle?: string;
  readonly authRateLimitEnabled: boolean;
  readonly authRateLimitWindowMinutes: number;
  readonly authRequestCodeSourceLimit: number;
  readonly authRequestCodeIdentifierLimit: number;
  readonly authRegisterSourceLimit: number;
  readonly authRegisterIdentifierLimit: number;
  readonly authLoginSourceLimit: number;
  readonly authLoginIdentifierLimit: number;
  readonly authResetPasswordSourceLimit: number;
  readonly authResetPasswordIdentifierLimit: number;
}

const requiredKeys = [
  'APP_NAME',
  'NODE_ENV',
  'PORT',
  'CORS_ALLOWED_ORIGINS',
  'DATABASE_URL',
  'REDIS_URL',
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
  'S3_ENDPOINT',
  'S3_BUCKET',
  'S3_ACCESS_KEY',
  'S3_SECRET_KEY',
] as const;

export function validateEnv(
  rawConfig: Record<string, unknown>,
): AppEnvironment {
  for (const key of requiredKeys) {
    if (!rawConfig[key]) {
      throw new Error(`Missing required environment variable: ${key}`);
    }
  }

  const nodeEnv = String(rawConfig.NODE_ENV);
  const trustProxy = readOptionalString(rawConfig.TRUST_PROXY);
  const authDebugCodeEnabled = readBoolean(
    rawConfig.AUTH_DEBUG_CODE_ENABLED,
    nodeEnv !== 'production',
  );
  const authCodeDeliveryMode = readAuthCodeDeliveryMode(
    rawConfig.AUTH_CODE_DELIVERY_MODE,
    nodeEnv === 'production' ? 'webhook' : 'debug',
  );
  const authCodeWebhookUrl = readOptionalString(rawConfig.AUTH_CODE_WEBHOOK_URL);
  const authCodeEmailFrom = readOptionalString(rawConfig.AUTH_CODE_EMAIL_FROM);
  const authCodeEmailNickname = readOptionalString(
    rawConfig.AUTH_CODE_EMAIL_NICKNAME,
  );
  const authCodeEmailHandle = readOptionalString(
    rawConfig.AUTH_CODE_EMAIL_HANDLE,
  );

  if (nodeEnv === 'production' && authDebugCodeEnabled) {
    throw new Error('AUTH_DEBUG_CODE_ENABLED must be false in production');
  }

  if (nodeEnv === 'production' && authCodeDeliveryMode !== 'webhook') {
    throw new Error('AUTH_CODE_DELIVERY_MODE must be webhook in production');
  }

  if (authCodeDeliveryMode === 'webhook' && !authCodeWebhookUrl) {
    throw new Error(
      'AUTH_CODE_WEBHOOK_URL is required when AUTH_CODE_DELIVERY_MODE=webhook',
    );
  }

  if (nodeEnv === 'production' && authCodeDeliveryMode === 'webhook') {
    for (const [key, value] of [
      [
        'AUTH_CODE_WEBHOOK_SECRET',
        readOptionalString(rawConfig.AUTH_CODE_WEBHOOK_SECRET),
      ],
      ['AUTH_CODE_EMAIL_FROM', authCodeEmailFrom],
      ['AUTH_CODE_EMAIL_NICKNAME', authCodeEmailNickname],
      ['AUTH_CODE_EMAIL_HANDLE', authCodeEmailHandle],
    ] as const) {
      if (!value) {
        throw new Error(`${key} is required in production`);
      }
    }

    assertProductionHttpsUrl(
      'AUTH_CODE_WEBHOOK_URL',
      authCodeWebhookUrl!,
      'AUTH_CODE_WEBHOOK_URL must use https in production webhook mode',
    );
  }

  if (nodeEnv === 'production' && trustProxy?.trim().toLowerCase() === 'true') {
    throw new Error(
      'TRUST_PROXY must use a specific hop count or trusted proxy list in production',
    );
  }

  const corsAllowedOrigins =
    typeof rawConfig.CORS_ALLOWED_ORIGINS === 'string'
      ? rawConfig.CORS_ALLOWED_ORIGINS.trim()
      : nodeEnv === 'production'
        ? ''
        : '*';
  const parsedCorsAllowedOrigins = parseCorsAllowedOrigins(corsAllowedOrigins);

  assertCorsAllowedOrigins(nodeEnv, parsedCorsAllowedOrigins);

  const databaseUrl = String(rawConfig.DATABASE_URL);
  const jwtAccessSecret = String(rawConfig.JWT_ACCESS_SECRET);
  const jwtRefreshSecret = String(rawConfig.JWT_REFRESH_SECRET);
  const s3AccessKey = String(rawConfig.S3_ACCESS_KEY);
  const s3SecretKey = String(rawConfig.S3_SECRET_KEY);

  if (nodeEnv === 'production') {
    assertStrongProductionSecret('JWT_ACCESS_SECRET', jwtAccessSecret, {
      minLength: 32,
      disallowedValues: [
        'replace-with-production-access-secret',
        'access-secret',
        'secret',
        'changeme',
      ],
    });
    assertStrongProductionSecret('JWT_REFRESH_SECRET', jwtRefreshSecret, {
      minLength: 32,
      disallowedValues: [
        'replace-with-production-refresh-secret',
        'refresh-secret',
        'secret',
        'changeme',
      ],
    });
    assertStrongProductionSecret('S3_ACCESS_KEY', s3AccessKey, {
      disallowedValues: ['minioadmin', 'admin', 'changeme'],
    });
    assertStrongProductionSecret('S3_SECRET_KEY', s3SecretKey, {
      minLength: 12,
      disallowedValues: ['minioadmin', 'secret', 'changeme'],
    });
    assertStrongProductionDatabaseUrl(databaseUrl);
  }

  return {
    appName: String(rawConfig.APP_NAME),
    nodeEnv,
    port: Number(rawConfig.PORT),
    trustProxy,
    corsAllowedOrigins,
    databaseUrl,
    redisUrl: String(rawConfig.REDIS_URL),
    jwtAccessSecret,
    jwtRefreshSecret,
    s3Endpoint: String(rawConfig.S3_ENDPOINT),
    s3Bucket: String(rawConfig.S3_BUCKET),
    s3AccessKey,
    s3SecretKey,
    fcmProjectId: readOptionalString(rawConfig.FCM_PROJECT_ID),
    fcmClientEmail: readOptionalString(rawConfig.FCM_CLIENT_EMAIL),
    fcmPrivateKey: readOptionalString(rawConfig.FCM_PRIVATE_KEY),
    apnsTeamId: readOptionalString(rawConfig.APNS_TEAM_ID),
    apnsKeyId: readOptionalString(rawConfig.APNS_KEY_ID),
    apnsBundleId: readOptionalString(rawConfig.APNS_BUNDLE_ID),
    apnsPrivateKey: readOptionalString(rawConfig.APNS_PRIVATE_KEY),
    adminHandles: readOptionalString(rawConfig.ADMIN_HANDLES),
    authDebugCodeEnabled,
    authCodeDeliveryMode,
    authCodeWebhookUrl,
    authCodeWebhookSecret: readOptionalString(
      rawConfig.AUTH_CODE_WEBHOOK_SECRET,
    ),
    authCodeEmailFrom,
    authCodeEmailNickname,
    authCodeEmailHandle,
    authRateLimitEnabled: readBoolean(rawConfig.AUTH_RATE_LIMIT_ENABLED, true),
    authRateLimitWindowMinutes: readNumber(
      rawConfig.AUTH_RATE_LIMIT_WINDOW_MINUTES,
      10,
    ),
    authRequestCodeSourceLimit: readNumber(
      rawConfig.AUTH_REQUEST_CODE_SOURCE_LIMIT,
      6,
    ),
    authRequestCodeIdentifierLimit: readNumber(
      rawConfig.AUTH_REQUEST_CODE_IDENTIFIER_LIMIT,
      3,
    ),
    authRegisterSourceLimit: readNumber(
      rawConfig.AUTH_REGISTER_SOURCE_LIMIT,
      5,
    ),
    authRegisterIdentifierLimit: readNumber(
      rawConfig.AUTH_REGISTER_IDENTIFIER_LIMIT,
      3,
    ),
    authLoginSourceLimit: readNumber(rawConfig.AUTH_LOGIN_SOURCE_LIMIT, 10),
    authLoginIdentifierLimit: readNumber(
      rawConfig.AUTH_LOGIN_IDENTIFIER_LIMIT,
      5,
    ),
    authResetPasswordSourceLimit: readNumber(
      rawConfig.AUTH_RESET_PASSWORD_SOURCE_LIMIT,
      5,
    ),
    authResetPasswordIdentifierLimit: readNumber(
      rawConfig.AUTH_RESET_PASSWORD_IDENTIFIER_LIMIT,
      3,
    ),
  };
}

function readAuthCodeDeliveryMode(
  value: unknown,
  fallback: 'debug' | 'webhook',
): 'debug' | 'webhook' {
  if (typeof value !== 'string') {
    return fallback;
  }

  const normalized = value.trim().toLowerCase();
  return normalized === 'webhook' || normalized === 'debug'
    ? normalized
    : fallback;
}

function readOptionalString(value: unknown): string | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}

function readBoolean(value: unknown, fallback: boolean): boolean {
  if (typeof value !== 'string') {
    return fallback;
  }

  const normalized = value.trim().toLowerCase();

  if (normalized == 'true') {
    return true;
  }

  if (normalized == 'false') {
    return false;
  }

  return fallback;
}

function readNumber(value: unknown, fallback: number): number {
  if (typeof value !== 'string') {
    return fallback;
  }

  const parsed = Number(value.trim());

  return Number.isFinite(parsed) ? parsed : fallback;
}

function assertStrongProductionSecret(
  key: string,
  value: string,
  options: {
    minLength?: number;
    disallowedValues: string[];
  },
): void {
  const normalized = value.trim();
  const lowerCased = normalized.toLowerCase();

  if (
    options.minLength !== undefined &&
    normalized.length < options.minLength
  ) {
    throw new Error(
      `${key} must be at least ${options.minLength} characters in production`,
    );
  }

  if (options.disallowedValues.includes(lowerCased)) {
    throw new Error(
      `${key} must not use a known default or placeholder value in production`,
    );
  }
}

function assertStrongProductionDatabaseUrl(databaseUrl: string): void {
  let parsedDatabaseUrl: URL;

  try {
    parsedDatabaseUrl = new URL(databaseUrl);
  } catch {
    throw new Error('DATABASE_URL must be a valid URL in production');
  }

  const password = decodeURIComponent(parsedDatabaseUrl.password).trim();
  const lowerCasedPassword = password.toLowerCase();

  if (
    ['chat_prod', 'postgres', 'password', 'admin', 'changeme'].includes(
      lowerCasedPassword,
    )
  ) {
    throw new Error(
      'DATABASE_URL must not use a weak database password in production',
    );
  }

  if (password.length < 12) {
    throw new Error(
      'DATABASE_URL must use a database password with at least 12 characters in production',
    );
  }
}

function assertProductionHttpsUrl(
  key: string,
  value: string,
  message: string,
): void {
  let parsedUrl: URL;

  try {
    parsedUrl = new URL(value);
  } catch {
    throw new Error(`${key} must be a valid URL`);
  }

  if (parsedUrl.protocol !== 'https:') {
    throw new Error(message);
  }
}
