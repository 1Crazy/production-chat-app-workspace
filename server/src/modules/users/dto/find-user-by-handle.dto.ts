import { IsString, Length, Matches } from 'class-validator';

export class FindUserByHandleDto {
  @IsString()
  @Length(2, 24)
  @Matches(/^[a-zA-Z0-9_]+$/)
  handle!: string;
}
