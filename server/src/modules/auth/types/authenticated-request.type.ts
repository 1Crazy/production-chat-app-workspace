import type { Request } from 'express';

import type { AuthUserEntity } from '../entities/auth-user.entity';
import type { DeviceSessionEntity } from '../entities/device-session.entity';

export interface AuthenticatedRequest extends Request {
  auth: {
    user: AuthUserEntity;
    session: DeviceSessionEntity;
  };
}
