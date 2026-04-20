import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { CreateDirectConversationDto } from '../dto/create-direct-conversation.dto';
import { CreateGroupConversationDto } from '../dto/create-group-conversation.dto';
import { UpdateReadCursorDto } from '../dto/update-read-cursor.dto';
import { ConversationsService } from '../services/conversations.service';

import { AccessTokenGuard } from '@app/modules/auth/guards/access-token.guard';
import type { AuthenticatedRequest } from '@app/modules/auth/types/authenticated-request.type';

@Controller('conversations')
export class ConversationsController {
  constructor(private readonly conversationsService: ConversationsService) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.conversationsService.getHealth();
  }

  @Get('model-summary')
  getModelSummary() {
    return this.conversationsService.getModelSummary();
  }

  @UseGuards(AccessTokenGuard)
  @Get()
  listRecentConversations(@Req() request: AuthenticatedRequest) {
    return this.conversationsService.listRecentConversations(
      request.auth.user.id,
    );
  }

  @UseGuards(AccessTokenGuard)
  @Post('direct')
  createDirectConversation(
    @Req() request: AuthenticatedRequest,
    @Body() dto: CreateDirectConversationDto,
  ) {
    return this.conversationsService.createDirectConversation(
      request.auth.user.id,
      dto,
    );
  }

  @UseGuards(AccessTokenGuard)
  @Post('group')
  createGroupConversation(
    @Req() request: AuthenticatedRequest,
    @Body() dto: CreateGroupConversationDto,
  ) {
    return this.conversationsService.createGroupConversation(
      request.auth.user.id,
      dto,
    );
  }

  @UseGuards(AccessTokenGuard)
  @Get(':conversationId')
  getConversation(
    @Req() request: AuthenticatedRequest,
    @Param('conversationId') conversationId: string,
  ) {
    return this.conversationsService.getConversationViewOrThrow(
      conversationId,
      request.auth.user.id,
    );
  }

  @UseGuards(AccessTokenGuard)
  @Post(':conversationId/read-cursor')
  updateReadCursor(
    @Req() request: AuthenticatedRequest,
    @Param('conversationId') conversationId: string,
    @Body() dto: UpdateReadCursorDto,
  ) {
    return this.conversationsService.updateReadCursor(
      request.auth.user.id,
      conversationId,
      dto,
    );
  }
}
