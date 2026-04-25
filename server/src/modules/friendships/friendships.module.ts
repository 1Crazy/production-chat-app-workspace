import { Module } from '@nestjs/common';

import { FriendshipsController } from './controllers/friendships.controller';
import { FriendshipRepository } from './repositories/friendship.repository';
import { PrismaFriendshipRepository } from './repositories/prisma-friendship.repository';
import { FriendshipsService } from './services/friendships.service';

import { AbuseModule } from '@app/infra/abuse/abuse.module';
import { DatabaseModule } from '@app/infra/database/database.module';
import { AuthModule } from '@app/modules/auth/auth.module';

@Module({
  imports: [AbuseModule, DatabaseModule, AuthModule],
  controllers: [FriendshipsController],
  providers: [
    FriendshipsService,
    PrismaFriendshipRepository,
    {
      provide: FriendshipRepository,
      useExisting: PrismaFriendshipRepository,
    },
  ],
  exports: [FriendshipsService, FriendshipRepository],
})
export class FriendshipsModule {}
