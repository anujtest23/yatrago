import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';

@Injectable()
export class NotificationsService {
  constructor(private prisma: PrismaService) {}

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
      throw new ForbiddenException(
        'This notification does not belong to you',
      );
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
    return this.prisma.notification.create({
      data: {
        userId,
        type: type as any,
        title,
        body,
        data: data ?? {},
      },
    });
  }
}