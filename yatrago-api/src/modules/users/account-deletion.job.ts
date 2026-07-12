import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../database/prisma.service';

// Finalizes accounts whose 30-day deletion grace period has elapsed:
// pending_deletion → deleted. Personal data (including the phone number) is
// RETAINED, not anonymized — the record is what lets us detect a deleted
// phone re-registering and, on admin approval, restore the account intact.
// Accounts that cancelled the deletion are back to `active` and never match.
@Injectable()
export class AccountDeletionJob {
  private readonly logger = new Logger(AccountDeletionJob.name);

  constructor(private prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async finalizeExpiredDeletions() {
    const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const users = await this.prisma.user.findMany({
      where: {
        accountStatus: 'pending_deletion',
        deletionRequestedAt: { lt: cutoff },
      },
      select: { id: true },
      take: 500,
    });

    let deleted = 0;
    for (const user of users) {
      try {
        await this.prisma.$transaction([
          this.prisma.user.update({
            where: { id: user.id },
            // isActive false so JwtStrategy also rejects; accountStatus is the
            // canonical lifecycle flag. Data kept for restore-on-reactivation.
            data: { accountStatus: 'deleted', isActive: false },
          }),
          // Revoke any lingering sessions from the grace-period browse access.
          this.prisma.authSession.deleteMany({ where: { userId: user.id } }),
        ]);
        deleted++;
      } catch (error) {
        this.logger.error(
          `Failed to finalize deletion for user ${user.id}: ${error.message}`,
        );
      }
    }

    if (deleted > 0) {
      this.logger.log(`Finalized ${deleted} account deletion(s)`);
    }
  }
}
