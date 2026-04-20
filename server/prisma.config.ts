import { config as loadDotenv } from 'dotenv';
import { defineConfig, env } from 'prisma/config';

const currentEnv = process.env.NODE_ENV ?? 'development';

loadDotenv({
  path: `env/.env.${currentEnv}.example`,
});
loadDotenv({
  path: 'env/.env.development.example',
  override: false,
});

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: env('DATABASE_URL'),
  },
});
