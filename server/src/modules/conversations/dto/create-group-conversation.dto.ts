import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsString,
  Length,
  Matches,
} from 'class-validator';

export class CreateGroupConversationDto {
  @IsString()
  @Length(1, 64)
  title!: string;

  @IsArray()
  @ArrayMinSize(2)
  @ArrayMaxSize(199)
  @IsString({ each: true })
  @Length(2, 24, { each: true })
  @Matches(/^[a-zA-Z0-9_]+$/, { each: true })
  memberHandles!: string[];
}
