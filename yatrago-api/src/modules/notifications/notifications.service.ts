import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { PushService } from './push.service';
import {
  categoryForNotifType,
  mergeNotificationSettings,
} from './notification-preferences';

@Injectable()
export class NotificationsService {
  constructor(
    private prisma: PrismaService,
    private push: PushService,
  ) {}

  // ── GET /notifications ───────────────────────────────────────
  async findAll(userId: string, page = 1, limit = 20) {
    const skip = (page - 1) * limit;

    const [total, notifications, unreadCount] = await Promise.all([
      this.prisma.notification.count({
        where: { userId },
      }),
      this.prisma.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.notification.count({
        where: { userId, isRead: false },
      }),
    ]);

    return {
      notifications,
      unreadCount,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page * limit < total,
      },
    };
  }

  // ── PATCH /notifications/:id/read ────────────────────────────
  async markOneRead(userId: string, notificationId: string) {
    const notification = await this.prisma.notification.findUnique({
      where: { id: notificationId },
    });

    if (!notification) {
      throw new NotFoundException('Notification not found');
    }

    if (notification.userId !== userId) {
      throw new ForbiddenException('This notification does not belong to you');
    }

    await this.prisma.notification.update({
      where: { id: notificationId },
      data: { isRead: true },
    });

    return { message: 'Notification marked as read' };
  }

  // ── PATCH /notifications/read-all ────────────────────────────
  async markAllRead(userId: string) {
    const result = await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });

    return {
      message: 'All notifications marked as read',
      updatedCount: result.count,
    };
  }

  // ── Helper: create a notification ────────────────────────────
  // Called internally by other services
  async createNotification(
    userId: string,
    type: string,
    title: string,
    body: string,
    data?: object,
  ) {
    // Honor the user's notification preferences: a muted category still
    // gets an in-app Notification row (except promotions, which are
    // skipped entirely) but never a push.
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { notificationSettings: true },
    });
    const settings = mergeNotificationSettings(user?.notificationSettings);
    const muted = !settings[categoryForNotifType(type)];

    if (muted && type === 'promotion') return null;

    const notification = await this.prisma.notification.create({
      data: {
        userId,
        type: type as any,
        title,
        body,
        data: data ?? {},
      },
    });

    // Fire-and-forget push — must never break the caller
    if (!muted) {
      this.push
        .sendToUser(userId, title, body, data as Record<string, any>)
        .catch((error) =>
          console.error('Push notification failed:', error.message),
        );
    }

    return notification;
  }
}
