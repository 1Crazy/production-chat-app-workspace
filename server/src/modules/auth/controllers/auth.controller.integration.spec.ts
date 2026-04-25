import { ValidationPipe } from '@nestjs/common';
import type { ExecutionContext } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { Request } from 'express';

import { AuthController } from './auth.controller';

import { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { AppConfigService } from '@app/infra/config/app-config.service';
import { LoginDto } from '@app/modules/auth/dto/login.dto';
import { RefreshTokenDto } from '@app/modules/auth/dto/refresh-token.dto';
import { RegisterDto } from '@app/modules/auth/dto/register.dto';
import { RequestAuthCodeDto } from '@app/modules/auth/dto/request-auth-code.dto';
import { ResetPasswordDto } from '@app/modules/auth/dto/reset-password.dto';
import { AccessTokenGuard } from '@app/modules/auth/guards/access-token.guard';
import { AuthRepository } from '@app/modules/auth/repositories/auth.repository';
import { InMemoryAuthRepository } from '@app/modules/auth/repositories/in-memory-auth.repository';
import { AuthCodeDeliveryService } from '@app/modules/auth/services/auth-code-delivery.service';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { AuthPasswordService } from '@app/modules/auth/services/auth-password.service';
import { AuthRateLimitService } from '@app/modules/auth/services/auth-rate-limit.service';
import { AuthSessionService } from '@app/modules/auth/services/auth-session.service';
import { AuthTokenService } from '@app/modules/auth/services/auth-token.service';
import { AuthVerificationCodeService } from '@app/modules/auth/services/auth-verification-code.service';
import { AuthService } from '@app/modules/auth/services/auth.service';
import type { AuthenticatedRequest } from '@app/modules/auth/types/authenticated-request.type';
import { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';

describe('AuthController integration', () => {
  const validationPipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });

  function createHttpExecutionContext(request: Request): ExecutionContext {
    return {
      switchToHttp: () => ({
        getRequest: () => request,
      }),
      getType: () => 'http',
    } as ExecutionContext;
  }

  it('should complete request-code, register, session listing, login, and refresh flow', async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        AuthService,
        AuthTokenService,
        AuthPasswordService,
        AuthIdentityService,
        AuthCodeDeliveryService,
        AuthSessionService,
        AuthVerificationCodeService,
        AuthRateLimitService,
        AccessTokenGuard,
        {
          provide: AuthRepository,
          useValue: new InMemoryAuthRepository(),
        },
        {
          provide: RateLimitService,
          useValue: {
            consumeOrThrow: jest.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: ChatGateway,
          useValue: {
            disconnectSession: jest.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: AppConfigService,
          useValue: {
            jwtAccessSecret: 'access-secret',
            jwtRefreshSecret: 'refresh-secret',
            nodeEnv: 'test',
            authDebugCodeEnabled: true,
            authCodeDeliveryMode: 'debug',
            authCodeWebhookUrl: undefined,
            authCodeWebhookSecret: undefined,
            authRateLimitEnabled: false,
            authRateLimitWindowMinutes: 10,
            authRequestCodeSourceLimit: 6,
            authRequestCodeIdentifierLimit: 3,
            authRegisterSourceLimit: 5,
            authRegisterIdentifierLimit: 3,
            authLoginSourceLimit: 10,
            authLoginIdentifierLimit: 5,
            authResetPasswordSourceLimit: 5,
            authResetPasswordIdentifierLimit: 3,
          },
        },
      ],
    }).compile();

    const controller = moduleRef.get(AuthController);
    const accessTokenGuard = moduleRef.get(AccessTokenGuard);

    const requestCodeDto = (await validationPipe.transform(
      {
        identifier: 'alice_user',
        purpose: 'register',
      },
      {
        type: 'body',
        metatype: RequestAuthCodeDto,
      },
    )) as RequestAuthCodeDto;
    const requestCodeResponse = await controller.requestCode(
      {
        headers: {
          'x-forwarded-for': '127.0.0.1',
        },
      } as unknown as Request,
      requestCodeDto,
    );

    expect(requestCodeResponse).toMatchObject({
      identifier: 'alice_user',
      expiresInSeconds: 600,
    });

    if (!requestCodeResponse.debugCode) {
      throw new Error('expected integration test to expose debugCode');
    }

    const registerDto = (await validationPipe.transform(
      {
        identifier: 'alice_user',
        code: requestCodeResponse.debugCode,
        password: 'Alice1234',
        nickname: 'Alice',
        deviceName: 'alice-phone',
      },
      {
        type: 'body',
        metatype: RegisterDto,
      },
    )) as RegisterDto;
    const registerResponse = await controller.register(
      {
        headers: {
          'x-forwarded-for': '127.0.0.1',
        },
      } as unknown as Request,
      registerDto,
    );

    expect(registerResponse).toMatchObject({
      user: {
        identifier: 'alice_user',
        nickname: 'Alice',
        handle: 'alice_user',
        discoveryMode: 'public',
      },
      currentSession: {
        deviceName: 'alice-phone',
        isCurrent: true,
      },
    });

    const authenticatedRequest = {
      headers: {
        authorization: `Bearer ${registerResponse.accessToken}`,
      },
    } as AuthenticatedRequest;
    const guardResult = await accessTokenGuard.canActivate(
      createHttpExecutionContext(authenticatedRequest as unknown as Request),
    );

    expect(guardResult).toBe(true);

    const sessions = await controller.listSessions(authenticatedRequest);

    expect(sessions).toHaveLength(1);
    expect(sessions[0]).toMatchObject({
      deviceName: 'alice-phone',
      isCurrent: true,
    });

    const loginDto = (await validationPipe.transform(
      {
        identifier: 'alice_user',
        password: 'Alice1234',
        deviceName: 'alice-ipad',
      },
      {
        type: 'body',
        metatype: LoginDto,
      },
    )) as LoginDto;
    const loginResponse = await controller.login(
      {
        headers: {
          'x-forwarded-for': '127.0.0.1',
        },
      } as unknown as Request,
      loginDto,
    );

    expect(loginResponse.currentSession.deviceName).toBe('alice-ipad');

    const resetCodeResponse = await controller.requestCode(
      {
        headers: {
          'x-forwarded-for': '127.0.0.1',
        },
      } as unknown as Request,
      (await validationPipe.transform(
        {
          identifier: 'alice_user',
          purpose: 'reset-password',
        },
        {
          type: 'body',
          metatype: RequestAuthCodeDto,
        },
      )) as RequestAuthCodeDto,
    );

    if (!resetCodeResponse.debugCode) {
      throw new Error('expected integration test to expose reset debugCode');
    }

    const resetPasswordResponse = await controller.resetPassword(
      {
        headers: {
          'x-forwarded-for': '127.0.0.1',
        },
      } as unknown as Request,
      (await validationPipe.transform(
        {
          identifier: 'alice_user',
          code: resetCodeResponse.debugCode,
          password: 'Alice5678',
        },
        {
          type: 'body',
          metatype: ResetPasswordDto,
        },
      )) as ResetPasswordDto,
    );

    expect(resetPasswordResponse).toEqual({
      success: true,
    });

    const refreshResponse = await controller.refresh(
      (await validationPipe.transform(
        {
          refreshToken: registerResponse.refreshToken,
        },
        {
          type: 'body',
          metatype: RefreshTokenDto,
        },
      )) as RefreshTokenDto,
    );

    expect(refreshResponse.currentSession.id).toBe(
      registerResponse.currentSession.id,
    );
    expect(refreshResponse.refreshToken).not.toBe(
      registerResponse.refreshToken,
    );
  });
});
