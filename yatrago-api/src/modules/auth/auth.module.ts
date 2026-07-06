import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { RedisService } from './redis.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { TotpService } from './totp.service';
import { appConfig } from '../../config/app.config';

@Module({
  imports: [
    PassportModule,
    JwtModule.register({
      secret: appConfig.jwtAccessSecret,
      signOptions: {
        expiresIn: appConfig.jwtExpiresIn,
        issuer: appConfig.jwtIssuer,
        audience: appConfig.jwtAudience,
      },
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    RedisService,
    JwtStrategy,
    JwtAuthGuard,
    TotpService,
  ],
  exports: [JwtAuthGuard, RedisService, JwtModule],
})
export class AuthModule {}
