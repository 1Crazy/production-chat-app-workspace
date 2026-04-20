import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { GetConversationHistoryQueryDto } from '../dto/get-conversation-history-query.dto';
import { SendMessageDto } from '../dto/send-message.dto';
import { SyncMessagesQueryDto } from '../dto/sync-messages-query.dto';
import { MessagesService } from '../services/messages.service';

import { AccessTokenGuard } from '@app/modules/auth/guards/access-token.guard';
import type { AuthenticatedRequest } from '@app/modules/auth/types/authenticated-request.type';

@Controller('messages')
export class MessagesController {
  constructor(private readonly messagesService: MessagesService) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.messagesService.getHealth();
  }

  @Get('model-summary')
  getModelSummary() {
    return this.messagesService.getModelSummary();
  }

  @UseGuards(AccessTokenGuard)
  @Post()
  sendMessage(
    @Req() request: AuthenticatedRequest,
    @Body() dto: SendMessageDto,
  ) {
    return this.messagesService.sendMessage(request.auth.user.id, dto);
  }

  @UseGuards(AccessTokenGuard)
  @Get('conversations/:conversationId/history')
  getConversationHistory(
    @Req() request: AuthenticatedRequest,
    @Param('conversationId') conversationId: string,
    @Query() query: GetConversationHistoryQueryDto,
  ) {
    return this.messagesService.getConversationHistory(
      request.auth.user.id,
      conversationId,
      query,
    );
  }

  @UseGuards(AccessTokenGuard)
  @Get('conversations/:conversationId/sync')
  syncConversationMessages(
    @Req() request: AuthenticatedRequest,
    @Param('conversationId') conversationId: string,
    @Query() query: SyncMessagesQueryDto,
  ) {
    return this.messagesService.syncConversationMessages(
      request.auth.user.id,
      conversationId,
      query,
    );
  }
}
