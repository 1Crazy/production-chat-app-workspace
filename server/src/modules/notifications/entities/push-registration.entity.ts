export type PushProvider = 'apns' | 'fcm';
export type PushEnvironment = 'sandbox' | 'production';

export interface PushRegistrationEntity {
  id: string;
  userId: string;
  sessionId: string;
  provider: PushProvider;
  token: string;
  pushEnvironment: PushEnvironment;
  createdAt: Date;
  updatedAt: Date;
  lastRegisteredAt: Date;
  revokedAt: Date | null;
}
