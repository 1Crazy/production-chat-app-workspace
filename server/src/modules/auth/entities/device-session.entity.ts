export interface DeviceSessionEntity {
  id: string;
  userId: string;
  deviceName: string;
  refreshNonce: string;
  createdAt: Date;
  lastSeenAt: Date;
  revokedAt: Date | null;
}
