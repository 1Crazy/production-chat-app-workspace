export const verificationCodePurposes = ['register', 'reset-password'] as const;

export type VerificationCodePurpose = (typeof verificationCodePurposes)[number];

export interface VerificationCodeEntity {
  identifier: string;
  purpose: VerificationCodePurpose;
  code: string;
  createdAt: Date;
  expiresAt: Date;
  consumedAt: Date | null;
}
