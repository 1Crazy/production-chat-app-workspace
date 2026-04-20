import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { ConfirmUploadDto } from '../dto/confirm-upload.dto';
import { RequestUploadTokenDto } from '../dto/request-upload-token.dto';
import { MediaService } from '../services/media.service';

import { AccessTokenGuard } from '@app/modules/auth/guards/access-token.guard';
import type { AuthenticatedRequest } from '@app/modules/auth/types/authenticated-request.type';

@Controller('media')
export class MediaController {
  constructor(private readonly mediaService: MediaService) {}

  @Get('health')
  getHealth(): { module: string; status: string } {
    return this.mediaService.getHealth();
  }

  @UseGuards(AccessTokenGuard)
  @Post('upload-tokens')
  requestUploadToken(
    @Req() request: AuthenticatedRequest,
    @Body() dto: RequestUploadTokenDto,
  ) {
    return this.mediaService.requestUploadToken(request.auth.user.id, dto);
  }

  @UseGuards(AccessTokenGuard)
  @Post('attachments/confirm')
  confirmUpload(
    @Req() request: AuthenticatedRequest,
    @Body() dto: ConfirmUploadDto,
  ) {
    return this.mediaService.confirmUpload(request.auth.user.id, dto);
  }

  @UseGuards(AccessTokenGuard)
  @Get('attachments/:attachmentId/access')
  getAttachmentAccess(
    @Req() request: AuthenticatedRequest,
    @Param('attachmentId') attachmentId: string,
  ) {
    return this.mediaService.getAttachmentAccess(
      request.auth.user.id,
      attachmentId,
    );
  }
}
