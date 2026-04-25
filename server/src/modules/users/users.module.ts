import { Module } from '@nestjs/common';

import { UsersController } from './controllers/users.controller';
import { UsersService } from './services/users.service';

import { AbuseModule } from '@app/infra/abuse/abuse.module';
import { AuthModule } from '@app/modules/auth/auth.module';
import { FriendshipsModule } from '@app/modules/friendships/friendships.module';

@Module({
  imports: [AbuseModule, AuthModule, FriendshipsModule],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
