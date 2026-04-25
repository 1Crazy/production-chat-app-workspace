import { forwardRef, Module } from '@nestjs/common';

import { AuthController } from './controllers/auth.controller';
import { AccessTokenGuard } from './guards/access-token.guard';
import { AuthRepository } from './repositories/auth.repository';
import { PrismaAuthRepository } from './repositories/prisma-auth.repository';
import { AuthCodeDeliveryService } from './services/auth-code-delivery.service';
import { AuthIdentityService } from './services/auth-identity.service';
import { AuthPasswordService } from './services/auth-password.service';
import { AuthRateLimitService } from './services/auth-rate-limit.service';
import { AuthSessionService } from './services/auth-session.service';
import { AuthTokenService } from './services/auth-token.service';
import { AuthVerificationCodeService } from './services/auth-verification-code.service';
import { AuthService } from './services/auth.service';

import { AbuseModule } from '@app/infra/abuse/abuse.module';
import { DatabaseModule } from '@app/infra/database/database.module';
import { RealtimeModule } from '@app/modules/realtime/realtime.module';

@Module({
  imports: [AbuseModule, DatabaseModule, forwardRef(() => RealtimeModule)],
  controllers: [AuthController],
  providers: [
    AuthService,
    AuthTokenService,
    AuthPasswordService,
    AuthIdentityService,
    AuthCodeDeliveryService,
    AuthRateLimitService,
    AuthSessionService,
    AuthVerificationCodeService,
    PrismaAuthRepository,
    {
      provide: AuthRepository,
      useExisting: PrismaAuthRepository,
    },
    AccessTokenGuard,
  ],
  exports: [
    AuthService,
    AuthIdentityService,
    AuthTokenService,
    AuthRepository,
    AccessTokenGuard,
  ],
})
export class AuthModule {}
