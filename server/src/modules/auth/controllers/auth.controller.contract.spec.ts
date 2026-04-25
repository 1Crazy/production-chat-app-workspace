import { ValidationPipe } from '@nestjs/common';

import { AuthController } from './auth.controller';

import { LoginDto } from '@app/modules/auth/dto/login.dto';
import { RegisterDto } from '@app/modules/auth/dto/register.dto';
import { RequestAuthCodeDto } from '@app/modules/auth/dto/request-auth-code.dto';
import { ResetPasswordDto } from '@app/modules/auth/dto/reset-password.dto';
import type { AuthService } from '@app/modules/auth/services/auth.service';

describe('AuthController contract', () => {
  const validationPipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });

  let authService: {
    requestCode: jest.Mock;
    register: jest.Mock;
    login: jest.Mock;
    resetPassword: jest.Mock;
  };
  let controller: AuthController;

  beforeEach(() => {
    authService = {
      requestCode: jest.fn().mockResolvedValue({
        identifier: 'alice_user',
        purpose: 'register',
        debugCode: '123456',
        expiresInSeconds: 600,
      }),
      register: jest.fn().mockResolvedValue({
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        user: {
          id: 'user-1',
          identifier: 'alice_user',
          nickname: 'Alice',
          handle: 'alice_user',
          avatarUrl: null,
          discoveryMode: 'public',
        },
        currentSession: {
          id: 'session-1',
          deviceName: 'alice-phone',
          createdAt: '2026-01-01T00:00:00.000Z',
          lastSeenAt: '2026-01-01T00:00:00.000Z',
          isCurrent: true,
        },
      }),
      login: jest.fn().mockResolvedValue({
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        user: {
          id: 'user-1',
          identifier: 'alice_user',
          nickname: 'Alice',
          handle: 'alice_user',
          avatarUrl: null,
          discoveryMode: 'public',
        },
        currentSession: {
          id: 'session-1',
          deviceName: 'alice-phone',
          createdAt: '2026-01-01T00:00:00.000Z',
          lastSeenAt: '2026-01-01T00:00:00.000Z',
          isCurrent: true,
        },
      }),
      resetPassword: jest.fn().mockResolvedValue({
        success: true,
      }),
    };
    controller = new AuthController(authService as unknown as AuthService);
  });

  it('should reject request-code payloads that violate the public contract', async () => {
    await expect(
      validationPipe.transform(
        {
          identifier: 'x',
          purpose: 'register',
        },
        {
          type: 'body',
          metatype: RequestAuthCodeDto,
        },
      ),
    ).rejects.toThrow();

    expect(authService.requestCode).not.toHaveBeenCalled();
  });

  it('should return the documented register response contract', async () => {
    const dto = (await validationPipe.transform(
      {
        identifier: 'alice_user',
        code: '123456',
        password: 'alice1234',
        nickname: 'Alice',
        deviceName: 'alice-phone',
      },
      {
        type: 'body',
        metatype: RegisterDto,
      },
    )) as RegisterDto;

    const response = await controller.register(
      {
        headers: {
          'x-forwarded-for': '127.0.0.1',
        },
      } as never,
      dto,
    );

    expect(response).toEqual({
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      user: {
        id: 'user-1',
        identifier: 'alice_user',
        nickname: 'Alice',
        handle: 'alice_user',
        avatarUrl: null,
        discoveryMode: 'public',
      },
      currentSession: {
        id: 'session-1',
        deviceName: 'alice-phone',
        createdAt: '2026-01-01T00:00:00.000Z',
        lastSeenAt: '2026-01-01T00:00:00.000Z',
        isCurrent: true,
      },
    });
  });

  it('should accept the password login response contract', async () => {
    const dto = (await validationPipe.transform(
      {
        identifier: 'alice_user',
        password: 'alice1234',
        deviceName: 'alice-phone',
      },
      {
        type: 'body',
        metatype: LoginDto,
      },
    )) as LoginDto;

    const response = await controller.login(
      {
        headers: {
          'x-forwarded-for': '127.0.0.1',
        },
      } as never,
      dto,
    );

    expect(response.currentSession.deviceName).toBe('alice-phone');
  });

  it('should accept the reset password response contract', async () => {
    const dto = (await validationPipe.transform(
      {
        identifier: 'alice_user',
        code: '123456',
        password: 'alice1234',
      },
      {
        type: 'body',
        metatype: ResetPasswordDto,
      },
    )) as ResetPasswordDto;

    const response = await controller.resetPassword(
      {
        headers: {
          'x-forwarded-for': '127.0.0.1',
        },
      } as never,
      dto,
    );

    expect(response).toEqual({
      success: true,
    });
  });
});
