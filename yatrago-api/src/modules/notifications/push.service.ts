import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';

@Injectable()
export class PushService {
  constructor(private prisma: PrismaService) {}

  private get firebaseConfigured(): boolean {
    return Boolean(
      process.env.FIREBASE_PROJECT_ID &&
      process.env.FIREBASE_CLIENT_EMAIL &&
      process.env.FIREBASE_PRIVATE_KEY,
    );
  }

  // Send a push notification to every registered device of a user.
  // Gracefully no-ops when Firebase credentials are not configured.
  async sendToUser(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, any>,
  ): Promise<void> {
    if (!this.firebaseConfigured) {
      console.log(`[DEV] Push to ${userId}: ${title}`);
      return;
    }

    const tokens = await this.prisma.deviceToken.findMany({
      where: { userId },
    });
    if (tokens.length === 0) return;

    // TODO: when Firebase credentials exist, add the `firebase-admin`
    // dependency and initialize it here with a service-account credential
    // (FIREBASE_PROJECT_ID / FIREBASE_CLIENT_EMAIL / FIREBASE_PRIVATE_KEY),
    // then call admin.messaging().sendEachForMulticast({
    //   tokens: tokens.map((t) => t.fcmToken),
    //   notification: { title, body },
    //   data: data ? Object.fromEntries(
    //     Object.entries(data).map(([k, v]) => [k, String(v)]),
    //   ) : undefined,
    // }) and prune tokens that come back as unregistered/invalid.
    console.log(
      `[PUSH] Would send "${title}" to ${tokens.length} device(s) of user ${userId}`,
      data ?? {},
    );
  }
}
