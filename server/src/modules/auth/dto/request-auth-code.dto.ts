import { IsString, Length, Matches } from 'class-validator';

export class RequestAuthCodeDto {
  @IsString()
  @Length(3, 64)
  @Matches(/^[a-zA-Z0-9_.@+-]+$/)
  identifier!: string;
}
