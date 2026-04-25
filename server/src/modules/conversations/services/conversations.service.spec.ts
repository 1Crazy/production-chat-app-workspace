import { ConversationViewService } from './conversation-view.service';
import { ConversationsService } from './conversations.service';

import type { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { InMemoryChatModelRepository } from '@app/infra/database/repositories/in-memory-chat-model.repository';
import { InMemoryAuthRepository } from '@app/modules/auth/repositories/in-memory-auth.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { InMemoryFriendshipRepository } from '@app/modules/friendships/repositories/in-memory-friendship.repository';
import { FriendshipsService } from '@app/modules/friendships/services/friendships.service';
import type { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';

describe('ConversationsService', () => {
  function createFixture() {
    const authRepository = new InMemoryAuthRepository();
    const friendshipRepository = new InMemoryFriendshipRepository();
    const chatModelRepository = new InMemoryChatModelRepository();
    const authIdentityService = new AuthIdentityService(authRepository);
    const rateLimitService = {
      consumeOrThrow: jest.fn().mockResolvedValue(undefined),
    } as unknown as RateLimitService;
    const friendshipsService = new FriendshipsService(
      friendshipRepository,
      authIdentityService,
      rateLimitService,
    );
    const chatGateway = {
      emitConversationCreated: jest.fn(),
      emitReadCursorUpdated: jest.fn().mockResolvedValue(undefined),
    } as unknown as ChatGateway;
    const conversationViewService = new ConversationViewService(
      chatModelRepository,
      authIdentityService,
    );
    const service = new ConversationsService(
      chatModelRepository,
      authIdentityService,
      friendshipsService,
      rateLimitService,
      chatGateway,
      conversationViewService,
    );

    return {
      authRepository,
      friendshipRepository,
      chatGateway,
      chatModelRepository,
      rateLimitService,
      service,
    };
  }

  it('should build recent conversation summaries with unread count', async () => {
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
    const conversation = await fixture.chatModelRepository.createConversation({
      type: 'direct',
      createdBy: alice.id,
      memberIds: [alice.id, bob.id],
    });

    await fixture.chatModelRepository.createMessage({
      conversationId: conversation.id,
      senderId: alice.id,
      clientMessageId: 'client-msg-2001',
      type: 'text',
      content: { text: '你好 Bob' },
    });
    await fixture.chatModelRepository.createMessage({
      conversationId: conversation.id,
      senderId: bob.id,
      clientMessageId: 'client-msg-2002',
      type: 'text',
      content: { text: '你好 Alice' },
    });
    await fixture.chatModelRepository.updateReadCursor({
      conversationId: conversation.id,
      userId: alice.id,
      lastReadSequence: 1,
    });

    const summaries = await fixture.service.listRecentConversations(alice.id);

    expect(summaries).toHaveLength(1);
    expect(summaries[0]).toMatchObject({
      id: conversation.id,
      title: 'Bob',
      unreadCount: 1,
      lastMessagePreview: '你好 Alice',
    });
  });

  it('should clamp read cursor to latest sequence and broadcast the update', async () => {
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
    const conversation = await fixture.chatModelRepository.createConversation({
      type: 'direct',
      createdBy: alice.id,
      memberIds: [alice.id, bob.id],
    });

    await fixture.chatModelRepository.createMessage({
      conversationId: conversation.id,
      senderId: bob.id,
      clientMessageId: 'client-msg-3001',
      type: 'text',
      content: { text: '第一条未读' },
    });
    await fixture.chatModelRepository.createMessage({
      conversationId: conversation.id,
      senderId: bob.id,
      clientMessageId: 'client-msg-3002',
      type: 'text',
      content: { text: '第二条未读' },
    });

    const readCursor = await fixture.service.updateReadCursor(
      alice.id,
      conversation.id,
      {
        lastReadSequence: 999,
      },
    );

    expect(readCursor).toMatchObject({
      conversationId: conversation.id,
      userId: alice.id,
      lastReadSequence: 2,
      unreadCount: 0,
    });
    expect(
      (fixture.chatGateway as unknown as { emitReadCursorUpdated: jest.Mock })
        .emitReadCursorUpdated,
    ).toHaveBeenCalledWith(
      expect.objectContaining({
        conversationId: conversation.id,
        userId: alice.id,
        lastReadSequence: 2,
      }),
    );
  });

  it('should reject high-frequency group creation attempts', async () => {
    const fixture = createFixture();
    const alice = await fixture.authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    await fixture.authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });
    await fixture.authRepository.createUser({
      identifier: 'carol@example.com',
      nickname: 'Carol',
      handle: 'carol_user',
    });
    (
      fixture.rateLimitService as unknown as {
        consumeOrThrow: jest.Mock;
      }
    ).consumeOrThrow.mockRejectedValueOnce(
      new Error('建群操作过于频繁，请稍后再试'),
    );

    await expect(
      fixture.service.createGroupConversation(alice.id, {
        title: '新群',
        memberHandles: ['bob_user', 'carol_user'],
      }),
    ).rejects.toThrow('建群操作过于频繁，请稍后再试');
  });

  it('should reject direct conversations for users who are not friends', async () => {
    const fixture = createFixture();
    const alice = await fixture.authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    await fixture.authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });

    await expect(
      fixture.service.createDirectConversation(alice.id, {
        targetHandle: 'bob_user',
      }),
    ).rejects.toThrow('仅支持与好友发起单聊');
  });

  it('should allow direct conversations after friendship is created', async () => {
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
    await fixture.friendshipRepository.createFriendship({
      userId: alice.id,
      friendUserId: bob.id,
    });

    const result = await fixture.service.createDirectConversation(alice.id, {
      targetHandle: 'bob_user',
    });

    expect(result.reused).toBe(false);
    expect(result.conversation.type).toBe('direct');
  });
});
