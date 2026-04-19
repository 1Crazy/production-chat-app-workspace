export interface VerificationCodeEntity {
  identifier: string;
  code: string;
  createdAt: Date;
  expiresAt: Date;
  consumedAt: Date | null;
}
