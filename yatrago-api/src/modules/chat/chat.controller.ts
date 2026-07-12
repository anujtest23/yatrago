import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { ChatService } from './chat.service';
import { SendMessageDto } from './dto/send-message.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

// REST is the durable path (history load, send fallback when the socket is
// down). Real-time delivery rides the ChatGateway; every write here also
// fans out over the gateway so both transports stay in sync.
@ApiTags('Chat')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(private chat: ChatService) {}

  @Get('conversations')
  @ApiOperation({ summary: 'List my active/archived conversations' })
  listConversations(@CurrentUser() user: any) {
    return this.chat.listConversations(user.id);
  }

  @Get('unread-count')
  @ApiOperation({ summary: 'Total unread messages across conversations' })
  unreadCount(@CurrentUser() user: any) {
    return this.chat.unreadCount(user.id);
  }

  @Get(':bookingId/messages')
  @ApiOperation({ summary: 'Message history for a booking (marks read)' })
  @ApiParam({ name: 'bookingId' })
  getMessages(@CurrentUser() user: any, @Param('bookingId') bookingId: string) {
    return this.chat.getMessages(user.id, bookingId);
  }

  @Post(':bookingId/messages')
  @ApiOperation({ summary: 'Send a message in a booking conversation' })
  @ApiParam({ name: 'bookingId' })
  async sendMessage(
    @CurrentUser() user: any,
    @Param('bookingId') bookingId: string,
    @Body() dto: SendMessageDto,
  ) {
    const message = await this.chat.sendMessage(user.id, bookingId, dto.content);
    return { message: 'Message sent', data: message };
  }

  @Post(':bookingId/read')
  @ApiOperation({ summary: 'Mark received messages in a booking as read' })
  @ApiParam({ name: 'bookingId' })
  markRead(@CurrentUser() user: any, @Param('bookingId') bookingId: string) {
    return this.chat.markRead(user.id, bookingId);
  }
}
