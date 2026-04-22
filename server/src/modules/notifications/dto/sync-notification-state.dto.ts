import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

export class NotificationConversationStateDto {
  @IsUUID()
  conversationId!: string;

  @IsInt()
  @Min(0)
  afterSequence!: number;
}

export class SyncNotificationStateDto {
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => NotificationConversationStateDto)
  conversationStates?: NotificationConversationStateDto[];

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(200)
  gapLimit?: number;

  @IsOptional()
  @IsString()
  pushMessageId?: string;
}
