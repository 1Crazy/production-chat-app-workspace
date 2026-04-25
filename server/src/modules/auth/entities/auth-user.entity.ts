export interface AuthUserEntity {
  id: string;
  identifier: string;
  nickname: string;
  handle: string;
  passwordHash: string | null;
  passwordUpdatedAt: Date | null;
  avatarUrl: string | null;
  discoveryMode: 'public' | 'private';
  createdAt: Date;
  updatedAt: Date;
  disabledAt: Date | null;
}
