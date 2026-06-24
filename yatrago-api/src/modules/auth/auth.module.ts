import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { RedisService } from './redis.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { appConfig } from '../../config/app.config';

@Module({
  imports: [
    PassportModule,
    JwtModule.register({
      secret: appConfig.jwtSecret,
      signOptions: { expiresIn: appConfig.jwtExpiresIn },
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, RedisService, JwtStrategy, JwtAuthGuard],
  exports: [JwtAuthGuard, RedisService, JwtModule],
})
export class AuthModule {}