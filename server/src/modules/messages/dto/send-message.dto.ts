import {
  IsIn,
  IsObject,
  IsString,
  IsUUID,
  Length,
  ValidateIf,
} from 'class-validator';

export class SendMessageDto {
  @IsUUID()
  conversationId!: string;

  @IsString()
  @Length(8, 80)
  clientMessageId!: string;

  @IsIn(['text', 'image', 'audio', 'file'])
  type!: 'text' | 'image' | 'audio' | 'file';

  @ValidateIf((value) => value.type === 'text')
  @IsString()
  @Length(1, 4000)
  text?: string;

  @ValidateIf((value) => value.type !== 'text')
  @IsObject()
  payload?: Record<string, unknown>;
}
