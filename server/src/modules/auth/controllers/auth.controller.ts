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

import { LoginDto } from '../dto/login.dto';
import { RefreshTokenDto } from '../dto/refresh-token.dto';
import { RegisterDto } from '../dto/register.dto';
import { RequestAuthCodeDto } from '../dto/request-auth-code.dto';
import { AccessTokenGuard } from '../guards/access-token.guard';
import { AuthService } from '../services/auth.service';
import type { AuthenticatedRequest } from '../types/authenticated-request.type';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.authService.getHealth();
  }

  // 首期先提供开发验证码接口，后续可以替换成短信或邮件服务。
  @Post('request-code')
  requestCode(@Body() dto: RequestAuthCodeDto): Promise<{
    identifier: string;
    debugCode: string;
    expiresInSeconds: number;
  }> {
    return this.authService.requestCode(dto);
  }

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
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
