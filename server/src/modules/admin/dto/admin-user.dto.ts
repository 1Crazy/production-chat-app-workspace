export interface AdminUserView {
  id: string;
  identifier: string;
  nickname: string;
  handle: string;
  avatarUrl: string | null;
  discoveryMode: 'public' | 'private';
  disabledAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface AdminUserDetailDto {
  user: AdminUserView;
  sessions: Array<{
    id: string;
    deviceName: string;
    createdAt: string;
    lastSeenAt: string;
    revokedAt: string | null;
  }>;
}
