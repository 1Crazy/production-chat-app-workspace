import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';

import { LoginDto } from '../dto/login.dto';
import { RefreshTokenDto } from '../dto/refresh-token.dto';
import { RegisterDto } from '../dto/register.dto';
import { RequestAuthCodeDto } from '../dto/request-auth-code.dto';
import { ResetPasswordDto } from '../dto/reset-password.dto';
import { AccessTokenGuard } from '../guards/access-token.guard';
import { AuthService } from '../services/auth.service';
import type { AuthenticatedRequest } from '../types/authenticated-request.type';

import { extractRequestSourceKey } from '@app/infra/abuse/utils/request-source.util';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.authService.getHealth();
  }

  @Post('request-code')
  requestCode(
    @Req() request: Request,
    @Body() dto: RequestAuthCodeDto,
  ): Promise<{
    identifier: string;
    purpose: 'register' | 'reset-password';
    debugCode?: string;
    expiresInSeconds: number;
  }> {
    return this.authService.requestCode(dto, extractRequestSourceKey(request));
  }

  @Post('register')
  register(@Req() request: Request, @Body() dto: RegisterDto) {
    return this.authService.register(dto, extractRequestSourceKey(request));
  }

  @Post('login')
  login(@Req() request: Request, @Body() dto: LoginDto) {
    return this.authService.login(dto, extractRequestSourceKey(request));
  }

  @Post('reset-password')
  resetPassword(@Req() request: Request, @Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(
      dto,
      extractRequestSourceKey(request),
    );
  }

  @Post('refresh')
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refresh(dto);
  }

  @UseGuards(AccessTokenGuard)
  @Get('me')
  me(@Req() request: AuthenticatedRequest) {
    return this.authService.getCurrentProfile(request);
  }

  @UseGuards(AccessTokenGuard)
  @Get('sessions')
  listSessions(@Req() request: AuthenticatedRequest) {
    return this.authService.listSessions(request);
  }

  @UseGuards(AccessTokenGuard)
  @Delete('sessions/:sessionId')
  revokeSession(
    @Req() request: AuthenticatedRequest,
    @Param('sessionId') sessionId: string,
  ) {
    return this.authService.revokeSession(request, sessionId);
  }

  @UseGuards(AccessTokenGuard)
  @Post('logout')
  logout(@Req() request: AuthenticatedRequest) {
    return this.authService.logout(request);
  }
}
