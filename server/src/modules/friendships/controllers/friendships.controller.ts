import {
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Body,
  Req,
  UseGuards,
} from '@nestjs/common';

import { CreateFriendRequestDto } from '../dto/create-friend-request.dto';
import { RejectFriendRequestDto } from '../dto/reject-friend-request.dto';
import { FriendshipsService } from '../services/friendships.service';

import { AccessTokenGuard } from '@app/modules/auth/guards/access-token.guard';
import type { AuthenticatedRequest } from '@app/modules/auth/types/authenticated-request.type';

@Controller('friendships')
export class FriendshipsController {
  constructor(private readonly friendshipsService: FriendshipsService) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.friendshipsService.getHealth();
  }

  @UseGuards(AccessTokenGuard)
  @Get()
  listFriends(@Req() request: AuthenticatedRequest) {
    return this.friendshipsService.listFriends(request.auth.user.id);
  }

  @UseGuards(AccessTokenGuard)
  @Get('requests/incoming')
  listIncomingRequests(@Req() request: AuthenticatedRequest) {
    return this.friendshipsService.listIncomingRequests(request.auth.user.id);
  }

  @UseGuards(AccessTokenGuard)
  @Get('requests/unread-count')
  getUnreadIncomingRequestCount(@Req() request: AuthenticatedRequest) {
    return this.friendshipsService.getUnreadIncomingRequestCount(
      request.auth.user.id,
    );
  }

  @UseGuards(AccessTokenGuard)
  @Get('requests/outgoing')
  listOutgoingRequests(@Req() request: AuthenticatedRequest) {
    return this.friendshipsService.listOutgoingRequests(request.auth.user.id);
  }

  @UseGuards(AccessTokenGuard)
  @Post('requests')
  createFriendRequest(
    @Req() request: AuthenticatedRequest,
    @Body() dto: CreateFriendRequestDto,
  ) {
    return this.friendshipsService.createFriendRequest(request.auth.user.id, dto);
  }

  @UseGuards(AccessTokenGuard)
  @Post('requests/:requestId/accept')
  acceptFriendRequest(
    @Req() request: AuthenticatedRequest,
    @Param('requestId') requestId: string,
  ) {
    return this.friendshipsService.acceptFriendRequest(
      request.auth.user.id,
      requestId,
    );
  }

  @UseGuards(AccessTokenGuard)
  @Post('requests/:requestId/ignore')
  ignoreFriendRequest(
    @Req() request: AuthenticatedRequest,
    @Param('requestId') requestId: string,
  ) {
    return this.friendshipsService.ignoreFriendRequest(
      request.auth.user.id,
      requestId,
    );
  }

  @UseGuards(AccessTokenGuard)
  @Post('requests/mark-viewed')
  markRequestsViewed(@Req() request: AuthenticatedRequest) {
    return this.friendshipsService.markRequestsViewed(request.auth.user.id);
  }

  @UseGuards(AccessTokenGuard)
  @Post('requests/:requestId/reject')
  rejectFriendRequest(
    @Req() request: AuthenticatedRequest,
    @Param('requestId') requestId: string,
    @Body() dto: RejectFriendRequestDto,
  ) {
    return this.friendshipsService.rejectFriendRequestWithReason(
      request.auth.user.id,
      requestId,
      dto,
    );
  }

  @UseGuards(AccessTokenGuard)
  @Delete('requests/:requestId')
  deleteFriendRequestRecord(
    @Req() request: AuthenticatedRequest,
    @Param('requestId') requestId: string,
  ) {
    return this.friendshipsService.deleteFriendRequestRecord(
      request.auth.user.id,
      requestId,
    );
  }

  @UseGuards(AccessTokenGuard)
  @Delete(':friendUserId')
  removeFriend(
    @Req() request: AuthenticatedRequest,
    @Param('friendUserId') friendUserId: string,
  ) {
    return this.friendshipsService.removeFriend(
      request.auth.user.id,
      friendUserId,
    );
  }
}
