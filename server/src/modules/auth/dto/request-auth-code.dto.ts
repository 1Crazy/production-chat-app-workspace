import { IsIn, IsString, Length, Matches } from 'class-validator';

import { verificationCodePurposes } from '../entities/verification-code.entity';

export class RequestAuthCodeDto {
  @IsString()
  @Length(3, 64)
  @Matches(/^[a-zA-Z0-9_.@+-]+$/)
  identifier!: string;

  @IsString()
  @IsIn(verificationCodePurposes)
  purpose!: 'register' | 'reset-password';
}
