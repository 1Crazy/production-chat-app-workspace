import { IsOptional, IsString, Length, Matches } from 'class-validator';

export class CreateFriendRequestDto {
  @IsString()
  @Length(2, 24)
  @Matches(/^[a-zA-Z0-9_]+$/)
  targetHandle!: string;

  @IsOptional()
  @IsString()
  @Length(0, 120)
  message?: string;
}
