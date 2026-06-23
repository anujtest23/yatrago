import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiParam,
  ApiQuery,
} from '@nestjs/swagger';
import { TripsService } from './trips.service';
import { CreateTripDto } from './dto/create-trip.dto';
import { UpdateTripDto } from './dto/update-trip.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Trips')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('trips')
export class TripsController {
  constructor(private tripsService: TripsService) {}

  @Post()
  @ApiOperation({ summary: 'Driver posts a new ride' })
  create(@CurrentUser() user: any, @Body() dto: CreateTripDto) {
    return this.tripsService.create(user.id, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Get all my trips as driver' })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['published', 'in_progress', 'completed', 'cancelled'],
  })
  findAll(@CurrentUser() user: any, @Query('status') status?: string) {
    return this.tripsService.findAll(user.id, status);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get single trip with passengers' })
  @ApiParam({ name: 'id', description: 'Trip ID' })
  findOne(@CurrentUser() user: any, @Param('id') id: string) {
    return this.tripsService.findOne(user.id, id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update trip details before departure' })
  @ApiParam({ name: 'id', description: 'Trip ID' })
  update(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() dto: UpdateTripDto,
  ) {
    return this.tripsService.update(user.id, id, dto);
  }
  @Patch(':id/start')
  @ApiOperation({ summary: 'Driver starts the trip — sets status to in_progress' })
  @ApiParam({ name: 'id', description: 'Trip ID' })
  startTrip(@CurrentUser() user: any, @Param('id') id: string) {
    return this.tripsService.startTrip(user.id, id);
  }

  @Patch(':id/complete')
  @ApiOperation({ summary: 'Driver completes the trip — sets all bookings to completed' })
  @ApiParam({ name: 'id', description: 'Trip ID' })
  completeTrip(@CurrentUser() user: any, @Param('id') id: string) {
    return this.tripsService.completeTrip(user.id, id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Cancel a trip' })
  @ApiParam({ name: 'id', description: 'Trip ID' })
  remove(@CurrentUser() user: any, @Param('id') id: string) {
    return this.tripsService.remove(user.id, id);
  }
}