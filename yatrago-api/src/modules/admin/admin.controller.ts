import {
  Controller,
  Get,
  Patch,
  Param,
  Body,
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
import { AdminService } from './admin.service';
import { RejectDriverDto } from './dto/reject-driver.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from './guards/admin.guard';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin')
export class AdminController {
  constructor(private adminService: AdminService) {}

  @Get('dashboard')
  @ApiOperation({ summary: 'Get KPIs — users, drivers, trips, revenue' })
  getDashboard() {
    return this.adminService.getDashboard();
  }

  @Get('users')
  @ApiOperation({ summary: 'List all users with filters' })
  @ApiQuery({ name: 'page', required: false, example: 1 })
  @ApiQuery({ name: 'limit', required: false, example: 20 })
  @ApiQuery({ name: 'search', required: false })
  getUsers(
    @Query('page') page = '1',
    @Query('limit') limit = '20',
    @Query('search') search?: string,
  ) {
    return this.adminService.getUsers(
      parseInt(page),
      parseInt(limit),
      search,
    );
  }

  @Get('drivers')
  @ApiOperation({ summary: 'List driver applications with status filter' })
  @ApiQuery({ name: 'page', required: false, example: 1 })
  @ApiQuery({ name: 'limit', required: false, example: 20 })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['not_submitted', 'under_review', 'approved', 'rejected'],
  })
  getDrivers(
    @Query('page') page = '1',
    @Query('limit') limit = '20',
    @Query('status') status?: string,
  ) {
    return this.adminService.getDrivers(
      parseInt(page),
      parseInt(limit),
      status,
    );
  }

  @Get('trips')
  @ApiOperation({ summary: 'List all trips' })
  @ApiQuery({ name: 'page', required: false, example: 1 })
  @ApiQuery({ name: 'limit', required: false, example: 20 })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['published', 'in_progress', 'completed', 'cancelled'],
  })
  getTrips(
    @Query('page') page = '1',
    @Query('limit') limit = '20',
    @Query('status') status?: string,
  ) {
    return this.adminService.getTrips(
      parseInt(page),
      parseInt(limit),
      status,
    );
  }

  @Get('bookings')
  @ApiOperation({ summary: 'List all bookings' })
  @ApiQuery({ name: 'page', required: false, example: 1 })
  @ApiQuery({ name: 'limit', required: false, example: 20 })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['pending', 'confirmed', 'rejected', 'cancelled', 'completed'],
  })
  getBookings(
    @Query('page') page = '1',
    @Query('limit') limit = '20',
    @Query('status') status?: string,
  ) {
    return this.adminService.getBookings(
      parseInt(page),
      parseInt(limit),
      status,
    );
  }

  @Patch('drivers/:id/approve')
  @ApiOperation({ summary: 'Approve a driver application' })
  @ApiParam({ name: 'id', description: 'Driver Profile ID' })
  approveDriver(@Param('id') id: string) {
    return this.adminService.approveDriver(id);
  }

  @Patch('drivers/:id/reject')
  @ApiOperation({ summary: 'Reject a driver application with reason' })
  @ApiParam({ name: 'id', description: 'Driver Profile ID' })
  rejectDriver(@Param('id') id: string, @Body() dto: RejectDriverDto) {
    return this.adminService.rejectDriver(id, dto);
  }

  @Patch('users/:id/block')
  @ApiOperation({ summary: 'Block a user account' })
  @ApiParam({ name: 'id', description: 'User ID' })
  blockUser(@Param('id') id: string) {
    return this.adminService.blockUser(id);
  }
}