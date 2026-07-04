import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';

// Grants access to any admin (admin or super_admin). Role lives on the User
// row and is attached to request.user by the JWT strategy — replaces the old
// ADMIN_PHONES env allow-list.
@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (user?.role !== 'admin' && user?.role !== 'super_admin') {
      throw new ForbiddenException(
        'Access denied. Admin privileges required.',
      );
    }

    return true;
  }
}
