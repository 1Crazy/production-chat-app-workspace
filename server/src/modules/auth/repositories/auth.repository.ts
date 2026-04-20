import type { AuthUserEntity } from '../entities/auth-user.entity';
import type { DeviceSessionEntity } from '../entities/device-session.entity';
import type { VerificationCodeEntity } from '../entities/verification-code.entity';

export abstract class AuthRepository {
  abstract createVerificationCode(
    identifier: string,
    code: string,
    expiresAt: Date,
  ): Promise<VerificationCodeEntity>;

  abstract findVerificationCode(
    identifier: string,
  ): Promise<VerificationCodeEntity | null>;

  abstract saveVerificationCode(entity: VerificationCodeEntity): Promise<void>;

  abstract createUser(params: {
    identifier: string;
    nickname: string;
    handle: string;
  }): Promise<AuthUserEntity>;

  abstract findUserByIdentifier(
    identifier: string,
  ): Promise<AuthUserEntity | null>;

  abstract findActiveUserById(userId: string): Promise<AuthUserEntity | null>;

  abstract findUserByHandle(handle: string): Promise<AuthUserEntity | null>;

  abstract findActiveUserByHandle(
    handle: string,
  ): Promise<AuthUserEntity | null>;

  abstract saveUser(user: AuthUserEntity): Promise<void>;

  abstract createSession(params: {
    userId: string;
    deviceName: string;
    refreshNonce: string;
  }): Promise<DeviceSessionEntity>;

  abstract saveSession(session: DeviceSessionEntity): Promise<void>;

  abstract findActiveSessionById(
    sessionId: string,
  ): Promise<DeviceSessionEntity | null>;

  abstract listActiveSessionsByUserId(
    userId: string,
  ): Promise<DeviceSessionEntity[]>;

  abstract revokeSession(sessionId: string): Promise<DeviceSessionEntity | null>;
}
