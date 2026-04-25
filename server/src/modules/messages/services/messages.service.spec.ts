import { MessageIdempotencyStore } from '../stores/message-idempotency.store';

import { MessagesService } from './messages.service';

import type { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { InMemoryChatModelRepository } from '@app/infra/database/repositories/in-memory-chat-model.repository';
import type { MetricsRegistryService } from '@app/infra/observability/metrics-registry.service';
import { InMemoryAuthRepository } from '@app/modules/auth/repositories/in-memory-auth.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import type { MediaAttachmentEntity } from '@app/modules/media/entities/media-attachment.entity';
import { MediaAttachmentRepository } from '@app/modules/media/repositories/media-attachment.repository';
import type { NotificationsService } from '@app/modules/notifications/services/notifications.service';
import type { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';

class InMemoryMessageIdempotencyStore extends MessageIdempotencyStore {
  private readonly values = new Map<string, string>();

  override async getBoundMessageId(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): Promise<string | null> {
    const value = this.values.get(this.buildKey(params));

    return value && value !== 'PENDING' ? value : null;
  }

  override async reserve(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): Promise<boolean> {
    const key = this.buildKey(params);

    if (this.values.has(key)) {
      return false;
    }

    this.values.set(key, 'PENDING');
    return true;
  }

  override async bind(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
    messageId: string;
  }): Promise<void> {
    this.values.set(this.buildKey(params), params.messageId);
  }

  override async release(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): Promise<void> {
    this.values.delete(this.buildKey(params));
  }

  private buildKey(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): string {
    return `${params.conversationId}:${params.senderId}:${params.clientMessageId}`;
  }
}

class InMemoryMediaAttachmentRepository extends MediaAttachmentRepository {
  private readonly attachmentsById = new Map<string, MediaAttachmentEntity>();

  override async createPendingAttachment(params: {
    id: string;
    ownerId: string;
    conversationId: string;
    purpose: MediaAttachmentEntity['purpose'];
    attachmentKind: MediaAttachmentEntity['attachmentKind'];
    objectKey: string;
    fileName: string;
    mimeType: string;
    sizeBytes: number;
  }): Promise<MediaAttachmentEntity> {
    const now = new Date();
    const attachment: MediaAttachmentEntity = {
      id: params.id,
      ownerId: params.ownerId,
      conversationId: params.conversationId,
      purpose: params.purpose,
      attachmentKind: params.attachmentKind,
      status: 'ready',
      objectKey: params.objectKey,
      fileName: params.fileName,
      mimeType: params.mimeType,
      sizeBytes: params.sizeBytes,
      previewObjectKey: null,
      failureReason: null,
      uploadedAt: now,
      confirmedAt: now,
      createdAt: now,
      updatedAt: now,
    };

    this.attachmentsById.set(attachment.id, attachment);
    return attachment;
  }

  override async getAttachmentOrThrow(
    attachmentId: string,
  ): Promise<MediaAttachmentEntity> {
    const attachment = this.attachmentsById.get(attachmentId);

    if (!attachment) {
      throw new Error('附件不存在');
    }

    return attachment;
  }

  override async saveAttachment(entity: MediaAttachmentEntity): Promise<void> {
    this.attachmentsById.set(entity.id, entity);
  }
}

describe('MessagesService', () => {
  function createFixture() {
    const authRepository = new InMemoryAuthRepository();
    const chatModelRepository = new InMemoryChatModelRepository();
    const authIdentityService = new AuthIdentityService(authRepository);
    const messageIdempotencyStore = new InMemoryMessageIdempotencyStore();
    const mediaAttachmentRepository = new InMemoryMediaAttachmentRepository();
    const rateLimitService = {
      consumeOrThrow: jest.fn().mockResolvedValue(undefined),
    } as unknown as RateLimitService;
    const metricsRegistryService = {
      incrementCounter: jest.fn(),
    } as unknown as MetricsRegistryService;
    const notificationsService = {
      dispatchOfflineMessagePush: jest.fn().mockResolvedValue(undefined),
    } as unknown as NotificationsService;
    const chatGateway = {
      emitMessageCreated: jest.fn(),
    } as unknown as ChatGateway;
    const service = new MessagesService(
      chatModelRepository,
      messageIdempotencyStore,
      authIdentityService,
      mediaAttachmentRepository,
      rateLimitService,
      metricsRegistryService,
      notificationsService,
      chatGateway,
    );

    return {
      authRepository,
      chatModelRepository,
      chatGateway,
      mediaAttachmentRepository,
      rateLimitService,
      notificationsService,
      service,
    };
  }

  it('should return paged history and next cursor for older messages', async () => {
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
      clientMessageId: 'client-msg-0001',
      type: 'text',
      content: { text: '第一条' },
    });
    await fixture.chatModelRepository.createMessage({
      conversationId: conversation.id,
      senderId: bob.id,
      clientMessageId: 'client-msg-0002',
      type: 'text',
      content: { text: '第二条' },
    });
    await fixture.chatModelRepository.createMessage({
      conversationId: conversation.id,
      senderId: alice.id,
      clientMessageId: 'client-msg-0003',
      type: 'text',
      content: { text: '第三条' },
    });

    const historyPage = await fixture.service.getConversationHistory(
      alice.id,
      conversation.id,
      {
        limit: 2,
      },
    );

    expect(historyPage.latestSequence).toBe(3);
    expect(historyPage.items.map((item) => item.sequence)).toEqual([2, 3]);
    expect(historyPage.nextCursor).toEqual({
      beforeSequence: 2,
    });
  });

  it('should sync missing messages after a known sequence', async () => {
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

    for (let index = 1; index <= 4; index += 1) {
      await fixture.chatModelRepository.createMessage({
        conversationId: conversation.id,
        senderId: index % 2 === 0 ? bob.id : alice.id,
        clientMessageId: `client-msg-100${index}`,
        type: 'text',
        content: { text: `消息 ${index}` },
      });
    }

    const syncResult = await fixture.service.syncConversationMessages(
      bob.id,
      conversation.id,
      {
        afterSequence: 1,
        limit: 2,
      },
    );

    expect(syncResult.items.map((item) => item.sequence)).toEqual([2, 3]);
    expect(syncResult.latestSequence).toBe(4);
    expect(syncResult.nextAfterSequence).toBe(3);
    expect(syncResult.hasMore).toBe(true);
  });

  it('should reuse the existing ack for repeated clientMessageId', async () => {
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

    const firstAck = await fixture.service.sendMessage(alice.id, {
      conversationId: conversation.id,
      clientMessageId: 'client-msg-9001',
      type: 'text',
      text: 'hello',
    });
    const secondAck = await fixture.service.sendMessage(alice.id, {
      conversationId: conversation.id,
      clientMessageId: 'client-msg-9001',
      type: 'text',
      text: 'hello',
    });

    expect(firstAck.message.serverMessageId).toBe(secondAck.message.serverMessageId);
    expect(fixture.chatGateway.emitMessageCreated).toHaveBeenCalledTimes(1);
    expect(
      (
        fixture.notificationsService as unknown as {
          dispatchOfflineMessagePush: jest.Mock;
        }
      ).dispatchOfflineMessagePush,
    ).toHaveBeenCalledTimes(1);
  });

  it('should normalize attachment messages from confirmed media metadata', async () => {
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
    const attachment = await fixture.mediaAttachmentRepository.createPendingAttachment({
      id: 'attachment-1',
      ownerId: alice.id,
      conversationId: conversation.id,
      purpose: 'chat-message',
      attachmentKind: 'image',
      objectKey: 'chat-media/object-1',
      fileName: 'photo.png',
      mimeType: 'image/png',
      sizeBytes: 1024,
    });

    const ack = await fixture.service.sendMessage(alice.id, {
      conversationId: conversation.id,
      clientMessageId: 'client-msg-attach-1',
      type: 'image',
      payload: {
        attachmentId: attachment.id,
      },
    });

    expect(ack.message.type).toBe('image');
    expect(ack.message.content).toMatchObject({
      attachmentId: attachment.id,
      attachmentKind: 'image',
      attachmentStatus: 'ready',
      fileName: 'photo.png',
      mimeType: 'image/png',
      sizeBytes: 1024,
    });
  });

  it('should reject sendMessage when the user hits the limiter', async () => {
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
    (
      fixture.rateLimitService as unknown as {
        consumeOrThrow: jest.Mock;
      }
    ).consumeOrThrow.mockRejectedValueOnce(
      new Error('消息发送过于频繁，请稍后再试'),
    );

    await expect(
      fixture.service.sendMessage(alice.id, {
        conversationId: conversation.id,
        clientMessageId: 'client-msg-limit-1',
        type: 'text',
        text: 'hello',
      }),
    ).rejects.toThrow('消息发送过于频繁，请稍后再试');
  });
});
