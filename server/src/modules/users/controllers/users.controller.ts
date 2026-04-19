import {
  Controller,
  Get,
  Patch,
  Query,
  Req,
  UseGuards,
  Body,
} from '@nestjs/common';

import { FindUserByHandleDto } from '../dto/find-user-by-handle.dto';
import { UpdateMyProfileDto } from '../dto/update-my-profile.dto';
import { UsersService } from '../services/users.service';

import { AccessTokenGuard } from '@app/modules/auth/guards/access-token.guard';
import type { AuthenticatedRequest } from '@app/modules/auth/types/authenticated-request.type';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.usersService.getHealth();
  }

  @UseGuards(AccessTokenGuard)
  @Get('me')
  getMyProfile(@Req() request: AuthenticatedRequest) {
    return this.usersService.getMyProfile(request.auth.user.id);
  }

  @UseGuards(AccessTokenGuard)
  @Patch('me')
  updateMyProfile(
    @Req() request: AuthenticatedRequest,
    @Body() dto: UpdateMyProfileDto,
  ) {
    return this.usersService.updateMyProfile(request.auth.user.id, dto);
  }

  @UseGuards(AccessTokenGuard)
  @Get('discovery')
  discoverByHandle(
    @Req() request: AuthenticatedRequest,
    @Query() dto: FindUserByHandleDto,
  ) {
    return this.usersService.discoverByHandle(request.auth.user.id, dto.handle);
  }
}
