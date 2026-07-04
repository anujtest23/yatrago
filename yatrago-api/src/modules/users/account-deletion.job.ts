import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../database/prisma.service';

// Anonymizes accounts whose 30-day deletion grace period has elapsed.
// Users who logged back in during the grace period had their
// deletionRequestedAt cleared (see AuthService.verifyOtp), so they
// never match this query. Already-anonymized accounts are excluded by
// their 'deleted-' phone number prefix.
@Injectable()
export class AccountDeletionJob {
  private readonly logger = new Logger(AccountDeletionJob.name);

  constructor(private prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async anonymizeExpiredDeletions() {
    const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const users = await this.prisma.user.findMany({
      where: {
        deletionRequestedAt: { lt: cutoff },
        NOT: { phoneNumber: { startsWith: 'deleted-' } },
      },
      select: { id: true },
      take: 500,
    });

    let anonymized = 0;
    for (const user of users) {
      try {
        await this.prisma.user.update({
          where: { id: user.id },
          data: {
            fullName: 'Deleted User',
            phoneNumber: `deleted-${user.id}`,
            profilePhotoUrl: null,
            gender: null,
            dateOfBirth: null,
            notificationSettings: null as any,
          },
        });
        anonymized++;
      } catch (error) {
        this.logger.error(
          `Failed to anonymize user ${user.id}: ${error.message}`,
        );
      }
    }

    if (anonymized > 0) {
      this.logger.log(`Anonymized ${anonymized} deleted account(s)`);
    }
  }
}
