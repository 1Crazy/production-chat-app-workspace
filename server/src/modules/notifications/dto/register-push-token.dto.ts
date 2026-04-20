import { IsIn, IsString, Length, Matches } from 'class-validator';

export class RegisterPushTokenDto {
  @IsIn(['apns', 'fcm'])
  provider!: 'apns' | 'fcm';

  @IsString()
  @Length(16, 4096)
  @Matches(/^[A-Za-z0-9:_\-.]+$/)
  token!: string;

  @IsIn(['sandbox', 'production'])
  pushEnvironment!: 'sandbox' | 'production';
}
