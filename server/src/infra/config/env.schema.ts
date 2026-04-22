export interface AppEnvironment {
  readonly appName: string;
  readonly nodeEnv: string;
  readonly port: number;
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
}

const requiredKeys = [
  'APP_NAME',
  'NODE_ENV',
  'PORT',
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

  return {
    appName: String(rawConfig.APP_NAME),
    nodeEnv: String(rawConfig.NODE_ENV),
    port: Number(rawConfig.PORT),
    databaseUrl: String(rawConfig.DATABASE_URL),
    redisUrl: String(rawConfig.REDIS_URL),
    jwtAccessSecret: String(rawConfig.JWT_ACCESS_SECRET),
    jwtRefreshSecret: String(rawConfig.JWT_REFRESH_SECRET),
    s3Endpoint: String(rawConfig.S3_ENDPOINT),
    s3Bucket: String(rawConfig.S3_BUCKET),
    s3AccessKey: String(rawConfig.S3_ACCESS_KEY),
    s3SecretKey: String(rawConfig.S3_SECRET_KEY),
    fcmProjectId: readOptionalString(rawConfig.FCM_PROJECT_ID),
    fcmClientEmail: readOptionalString(rawConfig.FCM_CLIENT_EMAIL),
    fcmPrivateKey: readOptionalString(rawConfig.FCM_PRIVATE_KEY),
    apnsTeamId: readOptionalString(rawConfig.APNS_TEAM_ID),
    apnsKeyId: readOptionalString(rawConfig.APNS_KEY_ID),
    apnsBundleId: readOptionalString(rawConfig.APNS_BUNDLE_ID),
    apnsPrivateKey: readOptionalString(rawConfig.APNS_PRIVATE_KEY),
    adminHandles: readOptionalString(rawConfig.ADMIN_HANDLES),
  };
}

function readOptionalString(value: unknown): string | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}
