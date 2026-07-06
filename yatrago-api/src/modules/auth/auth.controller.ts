import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  ParseUUIDPipe,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiResponse,
} from '@nestjs/swagger';
import type { Request } from 'express';
import { AuthService, RequestContext } from './auth.service';
import { TotpService } from './totp.service';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { TotpCodeDto } from './dto/totp-code.dto';
import { VerifyMfaDto } from './dto/verify-mfa.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(
    private authService: AuthService,
    private totpService: TotpService,
  ) {}

  /** Client context for session records and audit logs. */
  private ctx(req: Request): RequestContext {
    return {
      ip: req.ip ?? 'unknown',
      deviceInfo:
        typeof req.headers['user-agent'] === 'string'
          ? req.headers['user-agent']
          : undefined,
      // Stable client-generated identifier; hashed server-side before
      // storage and used for account-farming detection.
      deviceId:
        typeof req.headers['x-device-id'] === 'string'
          ? req.headers['x-device-id']
          : undefined,
      // Runtime environment self-report from the app (rooted/emulator/...).
      // Trust level is low (strippable) — it only feeds fraud scoring.
      integrityFlags:
        typeof req.headers['x-device-integrity'] === 'string'
          ? req.headers['x-device-integrity']
              .split(',')
              .map((f) => f.trim().toLowerCase())
              .filter(Boolean)
              .slice(0, 8)
          : undefined,
    };
  }

  // Strict per-route limits on top of the Redis per-phone/per-IP counters.
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('send-otp')
  @ApiOperation({ summary: 'Send OTP to phone number' })
  @ApiResponse({ status: 201, description: 'OTP sent successfully' })
  sendOtp(@Body() dto: SendOtpDto, @Req() req: Request) {
    return this.authService.sendOtp(dto, this.ctx(req));
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('verify-otp')
  @ApiOperation({ summary: 'Verify OTP and login or create account' })
  @ApiResponse({ status: 201, description: 'Returns tokens and user object' })
  verifyOtp(@Body() dto: VerifyOtpDto, @Req() req: Request) {
    return this.authService.verifyOtp(dto, this.ctx(req));
  }

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post('refresh')
  @ApiOperation({ summary: 'Exchange a refresh token for new tokens' })
  @ApiResponse({
    status: 201,
    description: 'Returns new access and refresh tokens',
  })
  refresh(@Body() dto: RefreshTokenDto, @Req() req: Request) {
    return this.authService.refresh(dto.refreshToken, this.ctx(req));
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('totp/verify')
  @ApiOperation({ summary: 'Complete an MFA login with a TOTP code' })
  verifyMfa(@Body() dto: VerifyMfaDto, @Req() req: Request) {
    return this.authService.completeMfaLogin(
      dto.mfaToken,
      dto.code,
      this.ctx(req),
    );
  }

  @Post('totp/setup')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Begin TOTP MFA enrollment (admin only)' })
  totpSetup(@CurrentUser() user: { id: string; role: string }) {
    return this.totpService.setup(user.id, user.role);
  }

  @Post('totp/enable')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Enable TOTP MFA with a confirming code' })
  totpEnable(
    @CurrentUser() user: { id: string; role: string },
    @Body() dto: TotpCodeDto,
  ) {
    return this.totpService.enable(user.id, user.role, dto.code);
  }

  @Post('totp/disable')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Disable TOTP MFA with a confirming code' })
  totpDisable(
    @CurrentUser() user: { id: string; role: string },
    @Body() dto: TotpCodeDto,
  ) {
    return this.totpService.disable(user.id, user.role, dto.code);
  }

  // No JwtAuthGuard: possession of the refresh token is sufficient to revoke
  // it, and logout must still work after the access token has expired.
  @Post('logout')
  @ApiOperation({ summary: 'Logout and invalidate refresh token' })
  logout(@Body() dto: RefreshTokenDto) {
    return this.authService.logout(dto.refreshToken);
  }

  @Post('logout-all')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Revoke every active session for this account' })
  logoutAll(@CurrentUser() user: { id: string }) {
    return this.authService.logoutAll(user.id);
  }

  @Get('sessions')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List active device sessions' })
  listSessions(@CurrentUser() user: { id: string }) {
    return this.authService.listSessions(user.id);
  }

  @Delete('sessions/:id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Revoke a specific device session' })
  revokeSession(
    @CurrentUser() user: { id: string },
    @Param('id', ParseUUIDPipe) sessionId: string,
  ) {
    return this.authService.revokeSession(user.id, sessionId);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current logged in user' })
  getMe(@CurrentUser() user: { id: string }) {
    return this.authService.getMe(user.id);
  }
}
