import { IsOptional, IsString, Length } from 'class-validator';

export class RejectFriendRequestDto {
  @IsOptional()
  @IsString()
  @Length(0, 120)
  rejectReason?: string;
}
