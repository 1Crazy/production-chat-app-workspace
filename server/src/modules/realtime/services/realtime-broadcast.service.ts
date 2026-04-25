import { Injectable } from '@nestjs/common';

import {
  buildConversationRoom,
  buildUserRoom,
  REALTIME_EVENTS,
} from '../constants/realtime.constants';
import type { GatewayServer } from '../types/authenticated-socket.type';

import { RealtimePresenceService } from './realtime-presence.service';

import { MetricsRegistryService } from '@app/infra/observability/metrics-registry.service';

@Injectable()
export class RealtimeBroadcastService {
  constructor(
    private readonly realtimePresenceService: RealtimePresenceService,
    private readonly metricsRegistryService: MetricsRegistryService,
  ) {}

  async broadcastPresenceUpdate(params: {
    server: GatewayServer;
    userId: string;
    conversationIds: string[];
  }): Promise<void> {
    const presence = await this.realtimePresenceService.getUserPresence(
      params.userId,
    );

    params.server
      .to(buildUserRoom(params.userId))
      .emit(REALTIME_EVENTS.presenceUpdated, presence);

    for (const conversationId of new Set(params.conversationIds)) {
      params.server
        .to(buildConversationRoom(conversationId))
        .emit(REALTIME_EVENTS.presenceUpdated, presence);
    }
  }

  async recordRealtimeConnectionGauge(): Promise<void> {
    this.metricsRegistryService.setGauge('chat_realtime_active_connections', {
      help: 'Current number of active realtime socket connections.',
      value: await this.realtimePresenceService.countActiveConnections(),
    });
  }
}
