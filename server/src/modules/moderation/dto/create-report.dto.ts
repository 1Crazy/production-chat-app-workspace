import {
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  MaxLength,
} from 'class-validator';

export class CreateModerationReportDto {
  @IsIn(['message', 'conversation', 'user'])
  targetType!: 'message' | 'conversation' | 'user';

  @IsUUID()
  targetId!: string;

  @IsString()
  @Length(2, 64)
  reasonCode!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;
}
