import { Injectable } from '@nestjs/common';

import {
  type ActiveRealtimeConnection,
  RealtimePresenceStore,
} from '../stores/realtime-presence.store';

@Injectable()
export class RealtimePresenceService {
  constructor(private readonly realtimePresenceStore: RealtimePresenceStore) {}

  // 在线态按 socket 维度维护，这样才能正确覆盖同账号多设备、多标签页同时在线的场景。
  async registerConnection(params: {
    socketId: string;
    userId: string;
    sessionId: string;
    conversationIds: string[];
    ttlMs: number;
  }): Promise<void> {
    await this.realtimePresenceStore.registerConnection({
      ...params,
      conversationIds: [...params.conversationIds],
    });
  }

  async touchConnection(params: {
    socketId: string;
    ttlMs: number;
  }): Promise<boolean> {
    return this.realtimePresenceStore.touchConnection(params);
  }

  async unregisterConnection(
    socketId: string,
  ): Promise<ActiveRealtimeConnection | null> {
    return this.realtimePresenceStore.unregisterConnection(socketId);
  }

  // presence 既给会话成员看，也给当前用户自己的其他设备看，所以这里统一返回聚合后的用户态。
  async getUserPresence(userId: string) {
    return this.realtimePresenceStore.getUserPresence(userId);
  }

  async listUserPresence(userIds: string[]) {
    return this.realtimePresenceStore.listUserPresence(userIds);
  }

  async listSocketIdsBySessionId(sessionId: string): Promise<string[]> {
    return this.realtimePresenceStore.listSocketIdsBySessionId(sessionId);
  }

  async countActiveConnections(): Promise<number> {
    return this.realtimePresenceStore.countActiveConnections();
  }
}
