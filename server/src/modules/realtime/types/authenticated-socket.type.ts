import type { AuthUserEntity } from '@app/modules/auth/entities/auth-user.entity';
import type { DeviceSessionEntity } from '@app/modules/auth/entities/device-session.entity';

export interface SocketAuthContext {
  user: AuthUserEntity;
  session: DeviceSessionEntity;
}

export interface GatewaySocket {
  id: string;
  recovered: boolean;
  data: {
    auth?: SocketAuthContext;
  };
  handshake: {
    auth: Record<string, unknown>;
    query: Record<string, unknown>;
    headers: Record<string, string | string[] | undefined>;
  };
  join(room: string): Promise<void> | void;
  emit(event: string, payload: unknown): void;
  disconnect(close?: boolean): void;
}

export interface GatewayServer {
  adapter?(adapter: unknown): void;
  in?(room: string): {
    disconnectSockets(close?: boolean): void;
  };
  to(room: string): {
    emit(event: string, payload: unknown): void;
  };
  sockets: {
    sockets: Map<
      string,
      {
        disconnect(close?: boolean): void;
      }
    >;
  };
}

export type AuthenticatedSocket = GatewaySocket & {
  data: GatewaySocket['data'] & {
    auth?: SocketAuthContext;
  };
};
