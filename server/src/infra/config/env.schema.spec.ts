import { validateEnv } from './env.schema';

describe('validateEnv', () => {
  const strongJwtSecret = '1234567890abcdef1234567890abcdef';
  const strongStorageSecret = 'storage-secret-123456';

  function buildEnv(overrides: Record<string, unknown> = {}) {
    return {
      APP_NAME: 'production-chat-api',
      NODE_ENV: 'development',
      PORT: '3000',
      CORS_ALLOWED_ORIGINS: '*',
      DATABASE_URL:
        'postgres://chat:chat-password-123@localhost:5432/chat',
      REDIS_URL: 'redis://localhost:6379/0',
      JWT_ACCESS_SECRET: strongJwtSecret,
      JWT_REFRESH_SECRET: strongJwtSecret,
      S3_ENDPOINT: 'http://localhost:9000',
      S3_BUCKET: 'chat-dev',
      S3_ACCESS_KEY: 'chatstorageadmin',
      S3_SECRET_KEY: strongStorageSecret,
      AUTH_CODE_DELIVERY_MODE: 'debug',
      AUTH_DEBUG_CODE_ENABLED: 'true',
      ...overrides,
    };
  }

  it('should reject wildcard CORS in production-like environments', () => {
    expect(() =>
      validateEnv(
        buildEnv({
          NODE_ENV: 'production',
          CORS_ALLOWED_ORIGINS: '*',
          AUTH_CODE_DELIVERY_MODE: 'webhook',
          AUTH_DEBUG_CODE_ENABLED: 'false',
          AUTH_CODE_WEBHOOK_URL: 'https://code-provider.example/send',
          AUTH_CODE_WEBHOOK_SECRET: 'delivery-secret',
          AUTH_CODE_EMAIL_FROM: 'no-reply@example.com',
          AUTH_CODE_EMAIL_NICKNAME: 'Production Chat',
          AUTH_CODE_EMAIL_HANDLE: 'production_chat',
        }),
      ),
    ).toThrow('CORS_ALLOWED_ORIGINS must not contain "*" in production or staging');

    expect(() =>
      validateEnv(
        buildEnv({
          NODE_ENV: 'staging',
          CORS_ALLOWED_ORIGINS: '*',
          AUTH_CODE_DELIVERY_MODE: 'webhook',
          AUTH_DEBUG_CODE_ENABLED: 'false',
          AUTH_CODE_WEBHOOK_URL: 'https://code-provider.example/send',
          AUTH_CODE_WEBHOOK_SECRET: 'delivery-secret',
        }),
      ),
    ).toThrow('CORS_ALLOWED_ORIGINS must not contain "*" in production or staging');
  });

  it('should accept explicit CORS origins in production', () => {
    expect(
      validateEnv(
        buildEnv({
          NODE_ENV: 'production',
          CORS_ALLOWED_ORIGINS: 'https://chat.example.com,https://admin.example.com',
          AUTH_CODE_DELIVERY_MODE: 'webhook',
          AUTH_DEBUG_CODE_ENABLED: 'false',
          AUTH_CODE_WEBHOOK_URL: 'https://code-provider.example/send',
          AUTH_CODE_WEBHOOK_SECRET: 'delivery-secret',
          AUTH_CODE_EMAIL_FROM: 'no-reply@example.com',
          AUTH_CODE_EMAIL_NICKNAME: 'Production Chat',
          AUTH_CODE_EMAIL_HANDLE: 'production_chat',
        }),
      ).corsAllowedOrigins,
    ).toBe('https://chat.example.com,https://admin.example.com');
  });

  it('should require a webhook secret in production webhook mode', () => {
    expect(() =>
      validateEnv(
        buildEnv({
          NODE_ENV: 'production',
          CORS_ALLOWED_ORIGINS: 'https://chat.example.com',
          AUTH_CODE_DELIVERY_MODE: 'webhook',
          AUTH_DEBUG_CODE_ENABLED: 'false',
          AUTH_CODE_WEBHOOK_URL: 'https://code-provider.example/send',
          AUTH_CODE_EMAIL_FROM: 'no-reply@example.com',
          AUTH_CODE_EMAIL_NICKNAME: 'Production Chat',
          AUTH_CODE_EMAIL_HANDLE: 'production_chat',
        }),
      ),
    ).toThrow('AUTH_CODE_WEBHOOK_SECRET is required in production');
  });

  it('should reject non-https webhook urls in production', () => {
    expect(() =>
      validateEnv(
        buildEnv({
          NODE_ENV: 'production',
          CORS_ALLOWED_ORIGINS: 'https://chat.example.com',
          AUTH_CODE_DELIVERY_MODE: 'webhook',
          AUTH_DEBUG_CODE_ENABLED: 'false',
          AUTH_CODE_WEBHOOK_URL: 'http://code-provider.example/send',
          AUTH_CODE_WEBHOOK_SECRET: 'delivery-secret',
          AUTH_CODE_EMAIL_FROM: 'no-reply@example.com',
          AUTH_CODE_EMAIL_NICKNAME: 'Production Chat',
          AUTH_CODE_EMAIL_HANDLE: 'production_chat',
        }),
      ),
    ).toThrow(
      'AUTH_CODE_WEBHOOK_URL must use https in production webhook mode',
    );
  });

  it('should reject TRUST_PROXY=true in production', () => {
    expect(() =>
      validateEnv(
        buildEnv({
          NODE_ENV: 'production',
          CORS_ALLOWED_ORIGINS: 'https://chat.example.com',
          TRUST_PROXY: 'true',
          AUTH_CODE_DELIVERY_MODE: 'webhook',
          AUTH_DEBUG_CODE_ENABLED: 'false',
          AUTH_CODE_WEBHOOK_URL: 'https://code-provider.example/send',
          AUTH_CODE_WEBHOOK_SECRET: 'delivery-secret',
          AUTH_CODE_EMAIL_FROM: 'no-reply@example.com',
          AUTH_CODE_EMAIL_NICKNAME: 'Production Chat',
          AUTH_CODE_EMAIL_HANDLE: 'production_chat',
        }),
      ),
    ).toThrow(
      'TRUST_PROXY must use a specific hop count or trusted proxy list in production',
    );
  });

  it('should reject weak JWT placeholder values in production', () => {
    expect(() =>
      validateEnv(
        buildEnv({
          NODE_ENV: 'production',
          CORS_ALLOWED_ORIGINS: 'https://chat.example.com',
          JWT_ACCESS_SECRET: 'replace-with-production-access-secret',
          AUTH_CODE_DELIVERY_MODE: 'webhook',
          AUTH_DEBUG_CODE_ENABLED: 'false',
          AUTH_CODE_WEBHOOK_URL: 'https://code-provider.example/send',
          AUTH_CODE_WEBHOOK_SECRET: 'delivery-secret',
          AUTH_CODE_EMAIL_FROM: 'no-reply@example.com',
          AUTH_CODE_EMAIL_NICKNAME: 'Production Chat',
          AUTH_CODE_EMAIL_HANDLE: 'production_chat',
        }),
      ),
    ).toThrow(
      'JWT_ACCESS_SECRET must not use a known default or placeholder value in production',
    );
  });

  it('should reject weak storage defaults in production', () => {
    expect(() =>
      validateEnv(
        buildEnv({
          NODE_ENV: 'production',
          CORS_ALLOWED_ORIGINS: 'https://chat.example.com',
          S3_ACCESS_KEY: 'minioadmin',
          S3_SECRET_KEY: 'minioadmin',
          AUTH_CODE_DELIVERY_MODE: 'webhook',
          AUTH_DEBUG_CODE_ENABLED: 'false',
          AUTH_CODE_WEBHOOK_URL: 'https://code-provider.example/send',
          AUTH_CODE_WEBHOOK_SECRET: 'delivery-secret',
          AUTH_CODE_EMAIL_FROM: 'no-reply@example.com',
          AUTH_CODE_EMAIL_NICKNAME: 'Production Chat',
          AUTH_CODE_EMAIL_HANDLE: 'production_chat',
        }),
      ),
    ).toThrow(
      'S3_ACCESS_KEY must not use a known default or placeholder value in production',
    );
  });

  it('should reject weak database passwords in production', () => {
    expect(() =>
      validateEnv(
        buildEnv({
          NODE_ENV: 'production',
          CORS_ALLOWED_ORIGINS: 'https://chat.example.com',
          DATABASE_URL:
            'postgres://chat_prod:chat_prod@localhost:5432/chat_prod',
          AUTH_CODE_DELIVERY_MODE: 'webhook',
          AUTH_DEBUG_CODE_ENABLED: 'false',
          AUTH_CODE_WEBHOOK_URL: 'https://code-provider.example/send',
          AUTH_CODE_WEBHOOK_SECRET: 'delivery-secret',
          AUTH_CODE_EMAIL_FROM: 'no-reply@example.com',
          AUTH_CODE_EMAIL_NICKNAME: 'Production Chat',
          AUTH_CODE_EMAIL_HANDLE: 'production_chat',
        }),
      ),
    ).toThrow(
      'DATABASE_URL must not use a weak database password in production',
    );
  });
});
