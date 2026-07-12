import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';

// Blocks state-changing actions for accounts in the 30-day deletion grace
// period. Such accounts may authenticate and browse (see JwtStrategy) but
// must not book, post rides, top up, withdraw, accept, or pay until they
// cancel the pending deletion.
//
// Apply AFTER JwtAuthGuard so request.user is populated:
//   @UseGuards(JwtAuthGuard, PendingDeletionGuard)
@Injectable()
export class PendingDeletionGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const user = context.switchToHttp().getRequest().user;
    if (user?.accountStatus === 'pending_deletion') {
      throw new ForbiddenException(
        'Your account is pending deletion. Cancel the deletion to use this feature.',
      );
    }
    return true;
  }
}
