import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import type { AppEnvironment } from './env.schema';

@Injectable()
export class AppConfigService {
  constructor(private readonly configService: ConfigService<AppEnvironment>) {}

  get appName(): string {
    return this.getOrThrow('appName');
  }

  get nodeEnv(): string {
    return this.getOrThrow('nodeEnv');
  }

  get port(): number {
    return this.getOrThrow('port');
  }

  get databaseUrl(): string {
    return this.getOrThrow('databaseUrl');
  }

  get redisUrl(): string {
    return this.getOrThrow('redisUrl');
  }

  get jwtAccessSecret(): string {
    return this.getOrThrow('jwtAccessSecret');
  }

  get jwtRefreshSecret(): string {
    return this.getOrThrow('jwtRefreshSecret');
  }

  get s3Endpoint(): string {
    return this.getOrThrow('s3Endpoint');
  }

  get s3Bucket(): string {
    return this.getOrThrow('s3Bucket');
  }

  get s3AccessKey(): string {
    return this.getOrThrow('s3AccessKey');
  }

  get s3SecretKey(): string {
    return this.getOrThrow('s3SecretKey');
  }

  private getOrThrow<Key extends keyof AppEnvironment>(
    key: Key,
  ): AppEnvironment[Key] {
    return this.configService.getOrThrow(key, {
      infer: true,
    });
  }
}
