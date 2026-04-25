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
import { AccessTokenGuard } from '@app/modules/auth/guards/access-token.guard';
import { AuthRepository } from '@app/modules/auth/repositories/auth.repository';
import { InMemoryAuthRepository } from '@app/modules/auth/repositories/in-memory-auth.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { AuthTokenService } from '@app/modules/auth/services/auth-token.service';
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
        AuthIdentityService,
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
          },
        },
      ],
    }).compile();

    const controller = moduleRef.get(AuthController);
    const accessTokenGuard = moduleRef.get(AccessTokenGuard);

    const requestCodeDto = (await validationPipe.transform(
      {
        identifier: 'alice_user',
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

    const registerDto = (await validationPipe.transform(
      {
        identifier: 'alice_user',
        code: requestCodeResponse.debugCode,
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

    const loginCodeResponse = await controller.requestCode(
      {
        headers: {
          'x-forwarded-for': '127.0.0.1',
        },
      } as unknown as Request,
      (await validationPipe.transform(
        {
          identifier: 'alice_user',
        },
        {
          type: 'body',
          metatype: RequestAuthCodeDto,
        },
      )) as RequestAuthCodeDto,
    );
    const loginDto = (await validationPipe.transform(
      {
        identifier: 'alice_user',
        code: loginCodeResponse.debugCode,
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
