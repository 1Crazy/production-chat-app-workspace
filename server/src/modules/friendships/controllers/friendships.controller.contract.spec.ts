import { ValidationPipe } from '@nestjs/common';

import { FriendshipsController } from './friendships.controller';

import { CreateFriendRequestDto } from '@app/modules/friendships/dto/create-friend-request.dto';
import { RejectFriendRequestDto } from '@app/modules/friendships/dto/reject-friend-request.dto';
import type { FriendshipsService } from '@app/modules/friendships/services/friendships.service';

describe('FriendshipsController contract', () => {
  const validationPipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });

  let friendshipsService: {
    createFriendRequest: jest.Mock;
    acceptFriendRequest: jest.Mock;
    rejectFriendRequestWithReason: jest.Mock;
    deleteFriendRequestRecord: jest.Mock;
    listIncomingRequests: jest.Mock;
    listOutgoingRequests: jest.Mock;
    listFriends: jest.Mock;
    removeFriend: jest.Mock;
  };
  let controller: FriendshipsController;

  beforeEach(() => {
    friendshipsService = {
    createFriendRequest: jest.fn().mockResolvedValue({
        id: 'request-1',
        direction: 'outgoing',
        status: 'pending',
        message: 'hi',
        rejectReason: null,
        createdAt: '2026-01-01T00:00:00.000Z',
        respondedAt: null,
        counterparty: {
          id: 'user-2',
          nickname: 'Bob',
          handle: 'bob_user',
          avatarUrl: null,
        },
      }),
      deleteFriendRequestRecord: jest.fn().mockResolvedValue({
        success: true,
        requestId: 'request-1',
      }),
      acceptFriendRequest: jest.fn().mockResolvedValue({
        success: true,
        requestId: 'request-1',
      }),
      rejectFriendRequestWithReason: jest.fn().mockResolvedValue({
        success: true,
        requestId: 'request-1',
      }),
      listIncomingRequests: jest.fn().mockResolvedValue([]),
      listOutgoingRequests: jest.fn().mockResolvedValue([]),
      listFriends: jest.fn().mockResolvedValue([]),
      removeFriend: jest.fn().mockResolvedValue({
        success: true,
        friendUserId: 'user-2',
      }),
    };
    controller = new FriendshipsController(
      friendshipsService as unknown as FriendshipsService,
    );
  });

  it('should reject invalid create-friend-request payloads', async () => {
    await expect(
      validationPipe.transform(
        {
          targetHandle: '@@bad',
        },
        {
          type: 'body',
          metatype: CreateFriendRequestDto,
        },
      ),
    ).rejects.toThrow();

    expect(friendshipsService.createFriendRequest).not.toHaveBeenCalled();
  });

  it('should return the documented create-friend-request response', async () => {
    const dto = (await validationPipe.transform(
      {
        targetHandle: 'bob_user',
        message: 'hi',
      },
      {
        type: 'body',
        metatype: CreateFriendRequestDto,
      },
    )) as CreateFriendRequestDto;

    const response = await controller.createFriendRequest(
      {
        auth: {
          user: {
            id: 'user-1',
          },
        },
      } as never,
      dto,
    );

    expect(response).toMatchObject({
      id: 'request-1',
      direction: 'outgoing',
      status: 'pending',
      rejectReason: null,
      counterparty: {
        handle: 'bob_user',
      },
    });
  });

  it('should accept optional reject reasons in the documented reject contract', async () => {
    const dto = (await validationPipe.transform(
      {
        rejectReason: '暂时不方便',
      },
      {
        type: 'body',
        metatype: RejectFriendRequestDto,
      },
    )) as RejectFriendRequestDto;

    const response = await controller.rejectFriendRequest(
      {
        auth: {
          user: {
            id: 'user-1',
          },
        },
      } as never,
      'request-1',
      dto,
    );

    expect(response).toEqual({
      success: true,
      requestId: 'request-1',
    });
  });
});
