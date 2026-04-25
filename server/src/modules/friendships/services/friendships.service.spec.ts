import { FriendshipsService } from './friendships.service';

import type { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { InMemoryAuthRepository } from '@app/modules/auth/repositories/in-memory-auth.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { InMemoryFriendshipRepository } from '@app/modules/friendships/repositories/in-memory-friendship.repository';

describe('FriendshipsService', () => {
  function createFixture() {
    const authRepository = new InMemoryAuthRepository();
    const friendshipRepository = new InMemoryFriendshipRepository();
    const authIdentityService = new AuthIdentityService(authRepository);
    const rateLimitService = {
      consumeOrThrow: jest.fn().mockResolvedValue(undefined),
    } as unknown as RateLimitService;
    const service = new FriendshipsService(
      friendshipRepository,
      authIdentityService,
      rateLimitService,
    );

    return {
      authRepository,
      friendshipRepository,
      rateLimitService,
      service,
    };
  }

  it('should create a pending friend request and expose outgoing status', async () => {
    const fixture = createFixture();
    const alice = await fixture.authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    const bob = await fixture.authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });

    const request = await fixture.service.createFriendRequest(alice.id, {
      targetHandle: 'bob_user',
      message: 'hi',
    });
    const relationship = await fixture.service.getRelationshipByUserIds(
      alice.id,
      bob.id,
    );

    expect(request.direction).toBe('outgoing');
    expect(relationship).toMatchObject({
      status: 'outgoing_pending',
      pendingRequestId: request.id,
    });
  });

  it('should accept a pending request and allow direct conversation', async () => {
    const fixture = createFixture();
    const alice = await fixture.authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    const bob = await fixture.authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });
    const request = await fixture.service.createFriendRequest(alice.id, {
      targetHandle: 'bob_user',
    });

    await fixture.service.acceptFriendRequest(bob.id, request.id);
    const relationship = await fixture.service.getRelationshipByUserIds(
      alice.id,
      bob.id,
    );

    expect(relationship.status).toBe('friends');
    await expect(
      fixture.service.assertDirectConversationAllowed(alice.id, bob.id),
    ).resolves.toBeUndefined();
  });

  it('should keep receiver history on ignore without changing sender visible status', async () => {
    const fixture = createFixture();
    const alice = await fixture.authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    const bob = await fixture.authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });
    const request = await fixture.service.createFriendRequest(alice.id, {
      targetHandle: 'bob_user',
    });

    await fixture.service.ignoreFriendRequest(bob.id, request.id);

    const outgoing = await fixture.service.listOutgoingRequests(alice.id);
    const incoming = await fixture.service.listIncomingRequests(bob.id);

    expect(outgoing).toHaveLength(1);
    expect(outgoing[0]?.status).toBe('pending');
    expect(incoming).toHaveLength(1);
    expect(incoming[0]?.status).toBe('ignored');
  });
});
