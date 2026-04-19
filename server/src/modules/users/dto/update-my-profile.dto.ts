import { IsIn, IsOptional, IsString, IsUrl, Length } from 'class-validator';

export class UpdateMyProfileDto {
  @IsOptional()
  @IsString()
  @Length(2, 32)
  nickname?: string;

  @IsOptional()
  @IsString()
  @IsUrl({
    require_tld: false,
  })
  avatarUrl?: string;

  @IsOptional()
  @IsIn(['public', 'private'])
  discoveryMode?: 'public' | 'private';
}
