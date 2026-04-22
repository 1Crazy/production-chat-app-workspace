import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class ProcessReportDto {
  @IsIn(['reviewed', 'resolved', 'rejected'])
  status!: 'reviewed' | 'resolved' | 'rejected';

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  resolutionNote?: string;
}
