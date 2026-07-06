import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { appConfig } from '../../../config/app.config';

// Grants access to any admin (admin or super_admin). Role lives on the User
// row and is attached to request.user by the JWT strategy — replaces the old
// ADMIN_PHONES env allow-list.
//
// Forced MFA: when ADMIN_MFA_REQUIRED is on (production default), an admin
// account without TOTP enrolled cannot use any /admin/* route. Enrollment
// endpoints (/auth/totp/*) sit outside this guard, so the admin can always
// complete enrollment and regain access — no lock-out deadlock.
@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<{
      user?: { role?: string; totpEnabledAt?: Date | null };
    }>();
    const user = request.user;

    if (user?.role !== 'admin' && user?.role !== 'super_admin') {
      throw new ForbiddenException('Access denied. Admin privileges required.');
    }

    if (appConfig.adminMfaRequired && !user.totpEnabledAt) {
      throw new ForbiddenException(
        'MFA enrollment required. Set up two-factor authentication to access admin functions.',
      );
    }

    return true;
  }
}
