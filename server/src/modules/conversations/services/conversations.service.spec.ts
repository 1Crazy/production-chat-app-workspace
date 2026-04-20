import { ConversationsService } from './conversations.service';

import { InMemoryChatModelRepository } from '@app/infra/database/repositories/in-memory-chat-model.repository';
import { InMemoryAuthRepository } from '@app/modules/auth/repositories/in-memory-auth.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import type { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';

describe('ConversationsService', () => {
  function createFixture() {
    const authRepository = new InMemoryAuthRepository();
    const chatModelRepository = new InMemoryChatModelRepository();
    const authIdentityService = new AuthIdentityService(authRepository);
    const chatGateway = {
      emitConversationCreated: jest.fn(),
      emitReadCursorUpdated: jest.fn().mockResolvedValue(undefined),
    } as unknown as ChatGateway;
    const service = new ConversationsService(
      chatModelRepository,
      authIdentityService,
      chatGateway,
    );

    return {
      authRepository,
      chatGateway,
      chatModelRepository,
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
});
