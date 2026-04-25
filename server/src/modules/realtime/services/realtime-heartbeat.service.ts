import { Injectable, OnModuleDestroy } from '@nestjs/common';

import { RealtimePresenceService } from './realtime-presence.service';

@Injectable()
export class RealtimeHeartbeatService implements OnModuleDestroy {
  private readonly presenceHeartbeatTimers = new Map<string, NodeJS.Timeout>();
  private readonly presenceHeartbeatIntervalMs = 15 * 1000;

  constructor(private readonly realtimePresenceService: RealtimePresenceService) {}

  onModuleDestroy(): void {
    this.stopAll();
  }

  start(socketId: string, ttlMs: number): void {
    this.stop(socketId);
    const timer = setInterval(() => {
      void this.refresh(socketId, ttlMs);
    }, this.presenceHeartbeatIntervalMs);

    timer.unref?.();
    this.presenceHeartbeatTimers.set(socketId, timer);
  }

  stop(socketId: string): void {
    const timer = this.presenceHeartbeatTimers.get(socketId);

    if (!timer) {
      return;
    }

    clearInterval(timer);
    this.presenceHeartbeatTimers.delete(socketId);
  }

  stopAll(): void {
    for (const socketId of this.presenceHeartbeatTimers.keys()) {
      this.stop(socketId);
    }
  }

  async refresh(socketId: string, ttlMs: number): Promise<void> {
    const touched = await this.realtimePresenceService.touchConnection({
      socketId,
      ttlMs,
    });

    if (!touched) {
      this.stop(socketId);
    }
  }
}
