import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../../database/prisma.service';
import { appConfig } from '../../../config/app.config';

interface AccessTokenPayload {
  sub: string;
  type: string;
  iss: string;
  aud: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private prisma: PrismaService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: appConfig.jwtAccessSecret,
      // RFC 8725: pin issuer and audience so tokens minted for another
      // context can never authenticate here.
      issuer: appConfig.jwtIssuer,
      audience: appConfig.jwtAudience,
    });
  }

  async validate(payload: AccessTokenPayload) {
    // Only ACCESS tokens grant API access — never any other token class.
    if (payload.type !== 'access') {
      throw new UnauthorizedException('Invalid token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('User not found or deactivated');
    }

    return user; // attached to request.user
  }
}
