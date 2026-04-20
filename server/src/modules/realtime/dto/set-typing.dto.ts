import { IsBoolean, IsUUID } from 'class-validator';

export class SetTypingDto {
  @IsUUID()
  conversationId!: string;

  @IsBoolean()
  isTyping!: boolean;
}
