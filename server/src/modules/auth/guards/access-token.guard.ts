import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';

import { InMemoryAuthRepository } from '../repositories/in-memory-auth.repository';
import { AuthTokenService } from '../services/auth-token.service';
import type { AuthenticatedRequest } from '../types/authenticated-request.type';

@Injectable()
export class AccessTokenGuard implements CanActivate {
  constructor(
    private readonly authTokenService: AuthTokenService,
    private readonly authRepository: InMemoryAuthRepository,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    const token = this.extractBearerToken(request);
    const payload = this.authTokenService.verifyAccessToken(token);
    const session = this.authRepository.findActiveSessionById(payload.sid);
    const user = this.authRepository.findActiveUserById(payload.sub);

    if (!session || !user || session.userId !== user.id) {
      throw new UnauthorizedException('登录状态已失效');
    }

    session.lastSeenAt = new Date();
    this.authRepository.saveSession(session);
    (request as AuthenticatedRequest).auth = {
      user,
      session,
    };
    return true;
  }

  private extractBearerToken(request: Request): string {
    const authorization = request.headers.authorization;

    if (!authorization?.startsWith('Bearer ')) {
      throw new UnauthorizedException('缺少访问令牌');
    }

    return authorization.replace('Bearer ', '').trim();
  }
}
