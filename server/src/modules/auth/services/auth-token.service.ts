import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

import { Injectable, UnauthorizedException } from '@nestjs/common';

import { AppConfigService } from '@app/infra/config/app-config.service';

interface BaseTokenPayload {
  sub: string;
  sid: string;
  type: 'access' | 'refresh';
  exp: number;
  iat: number;
}

interface RefreshTokenPayload extends BaseTokenPayload {
  type: 'refresh';
  nonce: string;
}

interface AccessTokenPayload extends BaseTokenPayload {
  type: 'access';
}

@Injectable()
export class AuthTokenService {
  private readonly accessTokenTtlSeconds = 60 * 15;
  private readonly refreshTokenTtlSeconds = 60 * 60 * 24 * 30;

  constructor(private readonly appConfigService: AppConfigService) {}

  issueRefreshNonce(): string {
    return randomBytes(16).toString('hex');
  }

  createAccessToken(params: { userId: string; sessionId: string }): string {
    return this.sign(
      {
        sub: params.userId,
        sid: params.sessionId,
        type: 'access',
        iat: this.nowInSeconds(),
        exp: this.nowInSeconds() + this.accessTokenTtlSeconds,
      },
      this.appConfigService.jwtAccessSecret,
    );
  }

  createRefreshToken(params: {
    userId: string;
    sessionId: string;
    nonce: string;
  }): string {
    return this.sign(
      {
        sub: params.userId,
        sid: params.sessionId,
        nonce: params.nonce,
        type: 'refresh',
        iat: this.nowInSeconds(),
        exp: this.nowInSeconds() + this.refreshTokenTtlSeconds,
      },
      this.appConfigService.jwtRefreshSecret,
    );
  }

  verifyAccessToken(token: string): AccessTokenPayload {
    const payload = this.verify(token, this.appConfigService.jwtAccessSecret);

    if (payload.type !== 'access') {
      throw new UnauthorizedException('访问令牌类型错误');
    }

    return payload as AccessTokenPayload;
  }

  verifyRefreshToken(token: string): RefreshTokenPayload {
    const payload = this.verify(token, this.appConfigService.jwtRefreshSecret);

    if (payload.type !== 'refresh') {
      throw new UnauthorizedException('刷新令牌类型错误');
    }

    return payload as RefreshTokenPayload;
  }

  private sign(
    payload: AccessTokenPayload | RefreshTokenPayload,
    secret: string,
  ): string {
    const header = this.base64UrlEncode({
      alg: 'HS256',
      typ: 'JWT',
    });
    const body = this.base64UrlEncode(payload);
    const signature = this.createSignature(`${header}.${body}`, secret);
    return `${header}.${body}.${signature}`;
  }

  private verify(token: string, secret: string): BaseTokenPayload {
    const parts = token.split('.');

    if (parts.length !== 3) {
      throw new UnauthorizedException('令牌格式无效');
    }

    const header = parts[0];
    const body = parts[1];
    const signature = parts[2];

    if (!header || !body || !signature) {
      throw new UnauthorizedException('令牌格式无效');
    }

    const expectedSignature = this.createSignature(`${header}.${body}`, secret);
    const signatureBuffer = Buffer.from(signature);
    const expectedSignatureBuffer = Buffer.from(expectedSignature);

    if (signatureBuffer.length !== expectedSignatureBuffer.length) {
      throw new UnauthorizedException('令牌签名校验失败');
    }

    if (!timingSafeEqual(signatureBuffer, expectedSignatureBuffer)) {
      throw new UnauthorizedException('令牌签名校验失败');
    }

    const payload = JSON.parse(
      Buffer.from(body, 'base64url').toString('utf8'),
    ) as BaseTokenPayload;

    if (payload.exp <= this.nowInSeconds()) {
      throw new UnauthorizedException('令牌已过期');
    }

    return payload;
  }

  private createSignature(value: string, secret: string): string {
    return createHmac('sha256', secret).update(value).digest('base64url');
  }

  private base64UrlEncode(value: unknown): string {
    return Buffer.from(JSON.stringify(value)).toString('base64url');
  }

  private nowInSeconds(): number {
    return Math.floor(Date.now() / 1000);
  }
}
