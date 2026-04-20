import { Type } from 'class-transformer';
import { IsInt, Min } from 'class-validator';

export class UpdateReadCursorDto {
  @Type(() => Number)
  @IsInt()
  @Min(0)
  lastReadSequence!: number;
}
