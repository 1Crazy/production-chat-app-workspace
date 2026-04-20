import {
  IsIn,
  IsInt,
  IsString,
  IsUUID,
  Length,
  Matches,
  Min,
} from 'class-validator';

export class RequestUploadTokenDto {
  @IsIn(['chat-message'])
  purpose!: 'chat-message';

  @IsUUID()
  conversationId!: string;

  @IsString()
  @Length(1, 128)
  fileName!: string;

  @IsString()
  @Length(3, 128)
  @Matches(/^[a-z0-9]+[a-z0-9!#$&^_.+-]*\/[a-z0-9]+[a-z0-9!#$&^_.+-]*$/i)
  mimeType!: string;

  @IsInt()
  @Min(1)
  sizeBytes!: number;
}
