import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';

@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    // For MVP — check if the user phone is in the admin list
    // In production this will check admin_users table
    const adminPhones = (process.env.ADMIN_PHONES ?? '')
      .split(',')
      .map((p) => p.trim());

    if (!adminPhones.includes(user.phoneNumber)) {
      throw new ForbiddenException(
        'Access denied. Admin privileges required.',
      );
    }

    return true;
  }
}