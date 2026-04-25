import { IsOptional, IsString, Length, Matches } from 'class-validator';

export class LoginDto {
  @IsString()
  @Length(3, 64)
  @Matches(/^[a-zA-Z0-9_.@+-]+$/)
  identifier!: string;

  @IsString()
  @Length(8, 72)
  @Matches(/^(?=.*[A-Za-z])(?=.*\d).+$/)
  password!: string;

  @IsOptional()
  @IsString()
  @Length(2, 48)
  deviceName?: string;
}
