import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { appConfig } from '../../../config/app.config';

/**
 * Optional IP allowlist for the admin surface (SECURITY.md: admin IP allow
 * list support). Disabled when ADMIN_IP_ALLOWLIST is empty, so development
 * and single-office deployments need no config. When set, requests from any
 * other IP are refused before the handler runs.
 *
 * Relies on Express `req.ip`, which honours X-Forwarded-For only when
 * TRUST_PROXY is enabled — otherwise it is the direct socket address.
 */
@Injectable()
export class AdminIpGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const allowlist = appConfig.adminIpAllowlist;
    if (allowlist.length === 0) return true;

    const req = context.switchToHttp().getRequest();
    const ip: string = (req.ip ?? '').replace(/^::ffff:/, '');

    if (!allowlist.includes(ip)) {
      throw new ForbiddenException('Access denied from this network');
    }
    return true;
  }
}
