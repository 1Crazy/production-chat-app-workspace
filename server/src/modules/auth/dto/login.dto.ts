import { IsOptional, IsString, Length, Matches } from 'class-validator';

export class LoginDto {
  @IsString()
  @Length(3, 64)
  @Matches(/^[a-zA-Z0-9_.@+-]+$/)
  identifier!: string;

  @IsString()
  @Length(4, 8)
  code!: string;

  @IsOptional()
  @IsString()
  @Length(2, 48)
  deviceName?: string;
}
