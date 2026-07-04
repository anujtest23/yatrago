import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  Headers,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiHeader,
  ApiParam,
  ApiQuery,
} from '@nestjs/swagger';
import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { CancelBookingDto } from './dto/cancel-booking.dto';
import { RejectBookingDto } from './dto/reject-booking.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SendMessageDto } from './dto/send-message.dto';
@ApiTags('Bookings')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('bookings')
export class BookingsController {
  constructor(private bookingsService: BookingsService) {}

  @Post()
  @ApiOperation({ summary: 'Passenger books a seat on a ride' })
  @ApiHeader({
    name: 'Idempotency-Key',
    required: false,
    description: 'Unique key to safely retry booking creation',
  })
  create(
    @CurrentUser() user: any,
    @Body() dto: CreateBookingDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    return this.bookingsService.create(user.id, dto, idempotencyKey);
  }

  @Get()
  @ApiOperation({ summary: 'Get my bookings — pass role=passenger or role=driver' })
  @ApiQuery({
    name: 'role',
    required: false,
    enum: ['passenger', 'driver'],
  })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['pending', 'confirmed', 'rejected', 'cancelled', 'completed'],
  })
  findAll(
    @CurrentUser() user: any,
    @Query('role') role: 'passenger' | 'driver' = 'passenger',
    @Query('status') status?: string,
  ) {
    return this.bookingsService.findAll(user.id, role, status);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get single booking detail' })
  @ApiParam({ name: 'id', description: 'Booking ID' })
  findOne(@CurrentUser() user: any, @Param('id') id: string) {
    return this.bookingsService.findOne(user.id, id);
  }

  @Patch(':id/cancel')
  @ApiOperation({ summary: 'Passenger cancels their booking' })
  @ApiParam({ name: 'id', description: 'Booking ID' })
  cancel(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() dto: CancelBookingDto,
  ) {
    return this.bookingsService.cancel(user.id, id, dto);
  }

  @Patch(':id/accept')
  @ApiOperation({ summary: 'Driver accepts a booking request' })
  @ApiParam({ name: 'id', description: 'Booking ID' })
  accept(@CurrentUser() user: any, @Param('id') id: string) {
    return this.bookingsService.accept(user.id, id);
  }

  @Patch(':id/reject')
  @ApiOperation({ summary: 'Driver rejects a booking request' })
  @ApiParam({ name: 'id', description: 'Booking ID' })
  reject(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() dto: RejectBookingDto,
  ) {
    return this.bookingsService.reject(user.id, id, dto);
  }
  @Post('messages')
  @ApiOperation({ summary: 'Send a message to driver or passenger in a booking' })
  sendMessage(@CurrentUser() user: any, @Body() dto: SendMessageDto) {
    return this.bookingsService.sendMessage(user.id, dto);
  }

  @Get('messages/:bookingId')
  @ApiOperation({ summary: 'Get all messages for a booking' })
  @ApiParam({ name: 'bookingId', description: 'Booking ID' })
  getMessages(
    @CurrentUser() user: any,
    @Param('bookingId') bookingId: string,
  ) {
    return this.bookingsService.getMessages(user.id, bookingId);
  }
}