import { IsString, Length, Matches } from 'class-validator';

export class CreateDirectConversationDto {
  @IsString()
  @Length(2, 24)
  @Matches(/^[a-zA-Z0-9_]+$/)
  targetHandle!: string;
}
