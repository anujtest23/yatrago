import {
  Controller,
  Get,
  Patch,
  Post,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  ParseUUIDPipe,
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
import { RejectPayoutDto } from './dto/reject-payout.dto';
import { RejectTopUpDto } from './dto/reject-topup.dto';
import { UpdateConfigDto } from './dto/update-config.dto';
import { RejectVehicleDto } from './dto/reject-vehicle.dto';
import { OverrideRidePriceDto } from './dto/override-ride-price.dto';
import { UpdateReportStatusDto } from './dto/update-report-status.dto';
import { HideRatingDto } from './dto/hide-rating.dto';
import { CreditWalletDto } from './dto/credit-wallet.dto';
import { CreateAdminDto } from './dto/create-admin.dto';
import { UpdateAdminRoleDto } from './dto/update-admin-role.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from './guards/admin.guard';
import { SuperAdminGuard } from './guards/super-admin.guard';
import { AdminIpGuard } from './guards/admin-ip.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Admin')
@ApiBearerAuth()
// Order matters: authenticate, then network allowlist, then role.
@UseGuards(JwtAuthGuard, AdminIpGuard, AdminGuard)
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
    return this.adminService.getUsers(parseInt(page), parseInt(limit), search);
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
    return this.adminService.getTrips(parseInt(page), parseInt(limit), status);
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
  approveDriver(@CurrentUser() admin: any, @Param('id') id: string) {
    return this.adminService.approveDriver(admin.id, id);
  }

  @Patch('drivers/:id/reject')
  @ApiOperation({ summary: 'Reject a driver application with reason' })
  @ApiParam({ name: 'id', description: 'Driver Profile ID' })
  rejectDriver(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Body() dto: RejectDriverDto,
  ) {
    return this.adminService.rejectDriver(admin.id, id, dto);
  }

  @Patch('users/:id/block')
  @ApiOperation({ summary: 'Block a user account' })
  @ApiParam({ name: 'id', description: 'User ID' })
  blockUser(@CurrentUser() admin: any, @Param('id') id: string) {
    return this.adminService.blockUser(admin.id, id);
  }

  @Get('payouts')
  @ApiOperation({ summary: 'List all payout requests' })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['pending', 'completed', 'failed'],
  })
  getPayouts(@Query('status') status?: string) {
    return this.adminService.getPayouts(status);
  }

  @Patch('payouts/:id/approve')
  @ApiOperation({ summary: 'Approve a pending payout' })
  @ApiParam({ name: 'id', description: 'Payout ID' })
  approvePayout(@CurrentUser() admin: any, @Param('id') id: string) {
    return this.adminService.approvePayout(admin.id, id);
  }

  @Patch('payouts/:id/reject')
  @ApiOperation({
    summary: 'Reject a pending payout and refund the driver wallet',
  })
  @ApiParam({ name: 'id', description: 'Payout ID' })
  rejectPayout(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Body() dto: RejectPayoutDto,
  ) {
    return this.adminService.rejectPayout(admin.id, id, dto);
  }

  @Get('sos')
  @ApiOperation({ summary: 'List SOS alerts' })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['open', 'acknowledged', 'resolved'],
  })
  getSosAlerts(@Query('status') status?: string) {
    return this.adminService.getSosAlerts(status);
  }

  @Patch('sos/:id/acknowledge')
  @ApiOperation({ summary: 'Acknowledge an open SOS alert' })
  @ApiParam({ name: 'id', description: 'SOS Alert ID' })
  acknowledgeSos(@CurrentUser() admin: any, @Param('id') id: string) {
    return this.adminService.acknowledgeSos(admin.id, id);
  }

  @Patch('sos/:id/resolve')
  @ApiOperation({ summary: 'Resolve an SOS alert' })
  @ApiParam({ name: 'id', description: 'SOS Alert ID' })
  resolveSos(@CurrentUser() admin: any, @Param('id') id: string) {
    return this.adminService.resolveSos(admin.id, id);
  }

  @Get('audit-logs')
  @ApiOperation({ summary: 'List admin audit logs, newest first' })
  @ApiQuery({ name: 'actorId', required: false })
  @ApiQuery({ name: 'targetType', required: false })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  getAuditLogs(
    @Query('actorId') actorId?: string,
    @Query('targetType') targetType?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.adminService.getAuditLogs({
      actorId,
      targetType,
      page: page ? parseInt(page, 10) : undefined,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
  }

  @Get('config')
  @ApiOperation({ summary: 'Get all platform config values' })
  getConfig() {
    return this.adminService.getConfig();
  }

  @Patch('config')
  @ApiOperation({ summary: 'Update a platform config value' })
  updateConfig(@CurrentUser() admin: any, @Body() dto: UpdateConfigDto) {
    return this.adminService.updateConfig(admin.id, dto);
  }

  @Post('wallets/:userId/credit')
  @ApiOperation({ summary: "Credit a user's wallet (driver top-up)" })
  @ApiParam({ name: 'userId' })
  creditWallet(
    @CurrentUser() admin: any,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() dto: CreditWalletDto,
  ) {
    return this.adminService.creditWallet(admin.id, admin.role, userId, dto);
  }

  @Get('fraud/flagged')
  @ApiOperation({ summary: 'List accounts with elevated fraud scores' })
  getFlaggedUsers() {
    return this.adminService.getFlaggedUsers();
  }

  @Get('fraud/:userId/events')
  @ApiOperation({ summary: 'Fraud event history for a user' })
  @ApiParam({ name: 'userId' })
  getFraudEvents(@Param('userId', ParseUUIDPipe) userId: string) {
    return this.adminService.getFraudEvents(userId);
  }

  @Get('topup-requests')
  @ApiOperation({ summary: 'List wallet top-up requests' })
  getTopUpRequests(@Query('status') status?: string) {
    const allowed = ['pending', 'approved', 'rejected'] as const;
    return this.adminService.getTopUpRequests(
      allowed.includes(status as (typeof allowed)[number])
        ? (status as (typeof allowed)[number])
        : undefined,
    );
  }

  @Patch('topup-requests/:id/approve')
  @ApiOperation({ summary: 'Approve a top-up request and credit the wallet' })
  @ApiParam({ name: 'id' })
  approveTopUpRequest(
    @CurrentUser() admin: any,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.adminService.approveTopUpRequest(admin.id, id);
  }

  @Patch('topup-requests/:id/reject')
  @ApiOperation({ summary: 'Reject a top-up request' })
  @ApiParam({ name: 'id' })
  rejectTopUpRequest(
    @CurrentUser() admin: any,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectTopUpDto,
  ) {
    return this.adminService.rejectTopUpRequest(admin.id, id, dto.note);
  }

  @Patch('rides/:id/cancel')
  @ApiOperation({ summary: 'Force-cancel a ride with full refunds' })
  @ApiParam({ name: 'id', description: 'Ride ID' })
  forceCancelRide(@CurrentUser() admin: any, @Param('id') id: string) {
    return this.adminService.forceCancelRide(admin.id, id);
  }

  @Patch('rides/:id/price')
  @ApiOperation({ summary: 'Override the per-seat price of a published ride' })
  @ApiParam({ name: 'id', description: 'Ride ID' })
  overrideRidePrice(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Body() dto: OverrideRidePriceDto,
  ) {
    return this.adminService.overrideRidePrice(admin.id, id, dto);
  }

  @Get('vehicles')
  @ApiOperation({ summary: 'List all vehicles with driver info' })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['active', 'inactive'],
  })
  getVehicles(@Query('status') status?: string) {
    return this.adminService.getVehicles(status);
  }

  @Patch('vehicles/:id/approve')
  @ApiOperation({ summary: 'Approve a vehicle for rides' })
  @ApiParam({ name: 'id', description: 'Vehicle ID' })
  approveVehicle(@CurrentUser() admin: any, @Param('id') id: string) {
    return this.adminService.approveVehicle(admin.id, id);
  }

  @Patch('vehicles/:id/reject')
  @ApiOperation({ summary: 'Reject a vehicle with reason' })
  @ApiParam({ name: 'id', description: 'Vehicle ID' })
  rejectVehicle(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Body() dto: RejectVehicleDto,
  ) {
    return this.adminService.rejectVehicle(admin.id, id, dto);
  }

  @Get('reports')
  @ApiOperation({ summary: 'List user incident reports' })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['open', 'investigating', 'resolved', 'dismissed'],
  })
  getReports(@Query('status') status?: string) {
    return this.adminService.getReports(status);
  }

  @Patch('reports/:id/status')
  @ApiOperation({ summary: 'Update the status of an incident report' })
  @ApiParam({ name: 'id', description: 'Report ID' })
  updateReportStatus(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Body() dto: UpdateReportStatusDto,
  ) {
    return this.adminService.updateReportStatus(admin.id, id, dto);
  }

  @Patch('ratings/:id/hide')
  @ApiOperation({
    summary: 'Hide a rating (excluded from averages and listings)',
  })
  @ApiParam({ name: 'id', description: 'Rating ID' })
  hideRating(
    @CurrentUser() admin: any,
    @Param('id') id: string,
    @Body() dto: HideRatingDto,
  ) {
    return this.adminService.hideRating(admin.id, id, dto);
  }

  @Patch('ratings/:id/unhide')
  @ApiOperation({ summary: 'Unhide a previously hidden rating' })
  @ApiParam({ name: 'id', description: 'Rating ID' })
  unhideRating(@CurrentUser() admin: any, @Param('id') id: string) {
    return this.adminService.unhideRating(admin.id, id);
  }

  // ── Admin roster management (super admin only) ───────────────

  @Get('admins')
  @ApiOperation({ summary: 'List all admins and super admins' })
  getAdmins() {
    return this.adminService.getAdmins();
  }

  @Post('admins')
  @UseGuards(SuperAdminGuard)
  @ApiOperation({
    summary: 'Grant admin access to a user by phone (super admin only)',
  })
  addAdmin(@CurrentUser() admin: any, @Body() dto: CreateAdminDto) {
    return this.adminService.addAdmin(admin.id, dto);
  }

  @Patch('admins/:userId/role')
  @UseGuards(SuperAdminGuard)
  @ApiOperation({ summary: "Change an admin's role (super admin only)" })
  @ApiParam({ name: 'userId', description: 'User ID of the admin' })
  updateAdminRole(
    @CurrentUser() admin: any,
    @Param('userId') userId: string,
    @Body() dto: UpdateAdminRoleDto,
  ) {
    return this.adminService.updateAdminRole(admin.id, userId, dto);
  }

  @Delete('admins/:userId')
  @UseGuards(SuperAdminGuard)
  @ApiOperation({ summary: 'Revoke a user’s admin access (super admin only)' })
  @ApiParam({ name: 'userId', description: 'User ID of the admin' })
  revokeAdmin(@CurrentUser() admin: any, @Param('userId') userId: string) {
    return this.adminService.revokeAdmin(admin.id, userId);
  }
}
