import { validateEnv } from './env.schema';

describe('validateEnv', () => {
  function buildEnv(overrides: Record<string, unknown> = {}) {
    return {
      APP_NAME: 'production-chat-api',
      NODE_ENV: 'development',
      PORT: '3000',
      CORS_ALLOWED_ORIGINS: '*',
      DATABASE_URL: 'postgres://chat:chat@localhost:5432/chat',
      REDIS_URL: 'redis://localhost:6379/0',
      JWT_ACCESS_SECRET: 'access-secret',
      JWT_REFRESH_SECRET: 'refresh-secret',
      S3_ENDPOINT: 'http://localhost:9000',
      S3_BUCKET: 'chat-dev',
      S3_ACCESS_KEY: 'minioadmin',
      S3_SECRET_KEY: 'minioadmin',
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
          AUTH_CODE_EMAIL_FROM: 'no-reply@example.com',
          AUTH_CODE_EMAIL_NICKNAME: 'Production Chat',
          AUTH_CODE_EMAIL_HANDLE: 'production_chat',
        }),
      ).corsAllowedOrigins,
    ).toBe('https://chat.example.com,https://admin.example.com');
  });
});
