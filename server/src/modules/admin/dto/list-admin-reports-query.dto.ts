import { IsIn, IsOptional } from 'class-validator';

export class ListAdminReportsQueryDto {
  @IsOptional()
  @IsIn(['pending_review', 'reviewed', 'resolved', 'rejected'])
  status?: 'pending_review' | 'reviewed' | 'resolved' | 'rejected';
}
