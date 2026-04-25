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

  get fcmProjectId(): string | undefined {
    return this.getOptional('fcmProjectId');
  }

  get fcmClientEmail(): string | undefined {
    return this.getOptional('fcmClientEmail');
  }

  get fcmPrivateKey(): string | undefined {
    return this.getOptional('fcmPrivateKey');
  }

  get apnsTeamId(): string | undefined {
    return this.getOptional('apnsTeamId');
  }

  get apnsKeyId(): string | undefined {
    return this.getOptional('apnsKeyId');
  }

  get apnsBundleId(): string | undefined {
    return this.getOptional('apnsBundleId');
  }

  get apnsPrivateKey(): string | undefined {
    return this.getOptional('apnsPrivateKey');
  }

  get adminHandles(): string[] {
    const rawValue = this.getOptional('adminHandles');

    if (!rawValue) {
      return [];
    }

    return rawValue
      .split(',')
      .map((handle) => handle.trim())
      .filter((handle) => handle.length > 0);
  }

  get authDebugCodeEnabled(): boolean {
    return this.getOrThrow('authDebugCodeEnabled');
  }

  get authCodeDeliveryMode(): 'debug' | 'webhook' {
    return this.getOrThrow('authCodeDeliveryMode');
  }

  get authCodeWebhookUrl(): string | undefined {
    return this.getOptional('authCodeWebhookUrl');
  }

  get authCodeWebhookSecret(): string | undefined {
    return this.getOptional('authCodeWebhookSecret');
  }

  get authCodeEmailFrom(): string | undefined {
    return this.getOptional('authCodeEmailFrom');
  }

  get authCodeEmailNickname(): string | undefined {
    return this.getOptional('authCodeEmailNickname');
  }

  get authCodeEmailHandle(): string | undefined {
    return this.getOptional('authCodeEmailHandle');
  }

  get authRateLimitEnabled(): boolean {
    return this.getOrThrow('authRateLimitEnabled');
  }

  get authRateLimitWindowMinutes(): number {
    return this.getOrThrow('authRateLimitWindowMinutes');
  }

  get authRequestCodeSourceLimit(): number {
    return this.getOrThrow('authRequestCodeSourceLimit');
  }

  get authRequestCodeIdentifierLimit(): number {
    return this.getOrThrow('authRequestCodeIdentifierLimit');
  }

  get authRegisterSourceLimit(): number {
    return this.getOrThrow('authRegisterSourceLimit');
  }

  get authRegisterIdentifierLimit(): number {
    return this.getOrThrow('authRegisterIdentifierLimit');
  }

  get authLoginSourceLimit(): number {
    return this.getOrThrow('authLoginSourceLimit');
  }

  get authLoginIdentifierLimit(): number {
    return this.getOrThrow('authLoginIdentifierLimit');
  }

  get authResetPasswordSourceLimit(): number {
    return this.getOrThrow('authResetPasswordSourceLimit');
  }

  get authResetPasswordIdentifierLimit(): number {
    return this.getOrThrow('authResetPasswordIdentifierLimit');
  }

  private getOrThrow<Key extends keyof AppEnvironment>(
    key: Key,
  ): AppEnvironment[Key] {
    return this.configService.getOrThrow(key, {
      infer: true,
    });
  }

  private getOptional<Key extends keyof AppEnvironment>(
    key: Key,
  ): AppEnvironment[Key] | undefined {
    return this.configService.get(key, {
      infer: true,
    });
  }
}
