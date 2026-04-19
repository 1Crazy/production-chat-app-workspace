import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';

import { SendMessageDto } from '../dto/send-message.dto';
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
}
