import type { PushRegistrationEntity } from '../entities/push-registration.entity';

export interface PushRegistrationView {
  id: string;
  provider: PushRegistrationEntity['provider'];
  pushEnvironment: PushRegistrationEntity['pushEnvironment'];
  createdAt: string;
  updatedAt: string;
  lastRegisteredAt: string;
  isCurrentSession: boolean;
}

export function toPushRegistrationView(
  registration: PushRegistrationEntity,
  currentSessionId: string,
): PushRegistrationView {
  return {
    id: registration.id,
    provider: registration.provider,
    pushEnvironment: registration.pushEnvironment,
    createdAt: registration.createdAt.toISOString(),
    updatedAt: registration.updatedAt.toISOString(),
    lastRegisteredAt: registration.lastRegisteredAt.toISOString(),
    isCurrentSession: registration.sessionId === currentSessionId,
  };
}
