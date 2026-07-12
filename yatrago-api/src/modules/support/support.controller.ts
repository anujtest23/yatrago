import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { SupportService } from './support.service';
import { CreateSupportTicketDto } from './dto/create-support-ticket.dto';
import { CreateIssueReportDto } from './dto/create-issue-report.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { publicImageMulterConfig } from '../../common/utils/multer.config';
import { FileSignatureInterceptor } from '../../common/interceptors/file-signature.interceptor';

@ApiTags('Support')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('support')
export class SupportController {
  constructor(private support: SupportService) {}

  // ── Attachment upload ──
  // Reuses the hardened public-image pipeline (UUID filename, MIME whitelist,
  // 5 MB cap, post-write magic-byte verification). Clients upload each
  // screenshot here, then submit the returned /uploads paths in `attachments`.
  @Post('attachments')
  @ApiOperation({ summary: 'Upload a screenshot; returns its storage path' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @UseInterceptors(
    FileInterceptor('file', publicImageMulterConfig),
    FileSignatureInterceptor,
  )
  uploadAttachment(@UploadedFile() file: Express.Multer.File) {
    if (!file) throw new BadRequestException('No file provided');
    return { url: `/uploads/${file.filename}` };
  }

  // ── Contact Us ──
  @Post('tickets')
  @ApiOperation({ summary: 'Submit a Contact Us support ticket' })
  createTicket(@CurrentUser() user: any, @Body() dto: CreateSupportTicketDto) {
    return this.support.createTicket(user.id, dto);
  }

  @Get('tickets')
  @ApiOperation({ summary: 'List my support tickets' })
  myTickets(@CurrentUser() user: any) {
    return this.support.listMyTickets(user.id);
  }

  @Get('tickets/:id')
  @ApiOperation({ summary: 'Get one of my support tickets' })
  ticket(@CurrentUser() user: any, @Param('id') id: string) {
    return this.support.getMyTicket(user.id, id);
  }

  // ── Report an Issue ──
  @Post('issues')
  @ApiOperation({ summary: 'Report a ride-specific issue' })
  createIssue(@CurrentUser() user: any, @Body() dto: CreateIssueReportDto) {
    return this.support.createIssue(user.id, dto);
  }

  @Get('issues')
  @ApiOperation({ summary: 'List my reported issues' })
  myIssues(@CurrentUser() user: any) {
    return this.support.listMyIssues(user.id);
  }
}
