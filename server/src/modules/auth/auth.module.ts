import { Module } from '@nestjs/common';

import { AuthController } from './controllers/auth.controller';
import { AccessTokenGuard } from './guards/access-token.guard';
import { InMemoryAuthRepository } from './repositories/in-memory-auth.repository';
import { AuthIdentityService } from './services/auth-identity.service';
import { AuthTokenService } from './services/auth-token.service';
import { AuthService } from './services/auth.service';

@Module({
  controllers: [AuthController],
  providers: [
    AuthService,
    AuthTokenService,
    AuthIdentityService,
    InMemoryAuthRepository,
    AccessTokenGuard,
  ],
  exports: [
    AuthService,
    AuthIdentityService,
    AuthTokenService,
    InMemoryAuthRepository,
    AccessTokenGuard,
  ],
})
export class AuthModule {}
