import { IsString, Length, Matches } from 'class-validator';

export class ResetPasswordDto {
  @IsString()
  @Length(3, 64)
  @Matches(/^[a-zA-Z0-9_.@+-]+$/)
  identifier!: string;

  @IsString()
  @Length(4, 8)
  code!: string;

  @IsString()
  @Length(8, 72)
  @Matches(/^(?=.*[A-Za-z])(?=.*\d).+$/)
  password!: string;
}
