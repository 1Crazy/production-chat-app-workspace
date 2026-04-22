import { Module } from '@nestjs/common';

import { UsersController } from './controllers/users.controller';
import { UsersService } from './services/users.service';

import { AbuseModule } from '@app/infra/abuse/abuse.module';
import { AuthModule } from '@app/modules/auth/auth.module';

@Module({
  imports: [AbuseModule, AuthModule],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
