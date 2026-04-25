import { ValidationPipe } from '@nestjs/common';
import type { ExecutionContext } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { Request } from 'express';

import { FriendshipsController } from './friendships.controller';

import { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { AppConfigService } from '@app/infra/config/app-config.service';
import { AccessTokenGuard } from '@app/modules/auth/guards/access-token.guard';
import { AuthRepository } from '@app/modules/auth/repositories/auth.repository';
import { InMemoryAuthRepository } from '@app/modules/auth/repositories/in-memory-auth.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { AuthTokenService } from '@app/modules/auth/services/auth-token.service';
import type { AuthenticatedRequest } from '@app/modules/auth/types/authenticated-request.type';
import { CreateFriendRequestDto } from '@app/modules/friendships/dto/create-friend-request.dto';
import { FriendshipRepository } from '@app/modules/friendships/repositories/friendship.repository';
import { InMemoryFriendshipRepository } from '@app/modules/friendships/repositories/in-memory-friendship.repository';
import { FriendshipsService } from '@app/modules/friendships/services/friendships.service';

describe('FriendshipsController integration', () => {
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

  it('should create, accept, and list friendships through controller endpoints', async () => {
    const authRepository = new InMemoryAuthRepository();
    const friendshipRepository = new InMemoryFriendshipRepository();

    const moduleRef = await Test.createTestingModule({
      controllers: [FriendshipsController],
      providers: [
        FriendshipsService,
        AuthIdentityService,
        AuthTokenService,
        AccessTokenGuard,
        {
          provide: AuthRepository,
          useValue: authRepository,
        },
        {
          provide: FriendshipRepository,
          useValue: friendshipRepository,
        },
        {
          provide: RateLimitService,
          useValue: {
            consumeOrThrow: jest.fn().mockResolvedValue(undefined),
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

    const controller = moduleRef.get(FriendshipsController);
    const accessTokenGuard = moduleRef.get(AccessTokenGuard);
    const authTokenService = moduleRef.get(AuthTokenService);

    const alice = await authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    const bob = await authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });
    const aliceSession = await authRepository.createSession({
      userId: alice.id,
      deviceName: 'alice-phone',
      refreshNonce: 'nonce-alice',
    });
    const bobSession = await authRepository.createSession({
      userId: bob.id,
      deviceName: 'bob-phone',
      refreshNonce: 'nonce-bob',
    });

    const aliceRequest = {
      headers: {
        authorization: `Bearer ${authTokenService.createAccessToken({
          userId: alice.id,
          sessionId: aliceSession.id,
        })}`,
      },
    } as AuthenticatedRequest;
    const bobRequest = {
      headers: {
        authorization: `Bearer ${authTokenService.createAccessToken({
          userId: bob.id,
          sessionId: bobSession.id,
        })}`,
      },
    } as AuthenticatedRequest;

    await accessTokenGuard.canActivate(
      createHttpExecutionContext(aliceRequest as unknown as Request),
    );
    await accessTokenGuard.canActivate(
      createHttpExecutionContext(bobRequest as unknown as Request),
    );

    const createDto = (await validationPipe.transform(
      {
        targetHandle: 'bob_user',
        message: 'hi',
      },
      {
        type: 'body',
        metatype: CreateFriendRequestDto,
      },
    )) as CreateFriendRequestDto;

    const request = await controller.createFriendRequest(aliceRequest, createDto);
    expect(request.direction).toBe('outgoing');

    const incoming = await controller.listIncomingRequests(bobRequest);
    expect(incoming).toHaveLength(1);
    expect(incoming[0]?.counterparty.handle).toBe('alice_user');

    const acceptResponse = await controller.acceptFriendRequest(
      bobRequest,
      request.id,
    );
    expect(acceptResponse).toEqual({
      success: true,
      requestId: request.id,
    });

    const aliceFriends = await controller.listFriends(aliceRequest);
    expect(aliceFriends).toHaveLength(1);
    expect(aliceFriends[0]?.profile.handle).toBe('bob_user');
  });
});
