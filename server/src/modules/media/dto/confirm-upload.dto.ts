import { IsString, IsUUID, Length } from 'class-validator';

export class ConfirmUploadDto {
  @IsUUID()
  attachmentId!: string;

  @IsString()
  @Length(12, 512)
  objectKey!: string;
}
