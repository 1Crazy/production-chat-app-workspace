import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';

import { AppConfigService } from '@app/infra/config/app-config.service';
import type { AuthenticatedRequest } from '@app/modules/auth/types/authenticated-request.type';

@Injectable()
export class AdminAccessGuard implements CanActivate {
  constructor(private readonly appConfigService: AppConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const adminHandles = new Set(this.appConfigService.adminHandles);

    if (adminHandles.size === 0) {
      throw new ForbiddenException('管理员白名单未配置');
    }

    if (!adminHandles.has(request.auth.user.handle)) {
      throw new ForbiddenException('当前账号没有管理员权限');
    }

    return true;
  }
}
