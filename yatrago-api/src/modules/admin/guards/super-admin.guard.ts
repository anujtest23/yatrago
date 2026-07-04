import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';

// Restricts an endpoint to super admins only — used for managing the admin
// roster itself (granting/revoking admin access).
@Injectable()
export class SuperAdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (user?.role !== 'super_admin') {
      throw new ForbiddenException(
        'Access denied. Super admin privileges required.',
      );
    }

    return true;
  }
}
