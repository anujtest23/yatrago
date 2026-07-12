import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { FraudService } from '../platform/fraud.service';
import { SafeBrowsingService } from '../platform/safe-browsing.service';
import { moderateMessage } from '../../common/utils/content-moderation';
import { ChatGateway } from './chat.gateway';

// A confirmed booking whose ride finished stays open for post-trip questions
// for this long, then becomes read-only history.
const POST_COMPLETION_CHAT_WINDOW_MS = 24 * 60 * 60 * 1000;

interface ChatAccess {
  booking: {
    id: string;
    passengerId: string;
    status: string;
    confirmedAt: Date | null;
    completedAt: Date | null;
    driverUserId: string;
  };
  isPassenger: boolean;
  isDriver: boolean;
  // true while new messages are allowed; false = read-only history.
  canSend: boolean;
}

@Injectable()
export class ChatService {
  constructor(
    private prisma: PrismaService,
    private fraud: FraudService,
    private safeBrowsing: SafeBrowsingService,
    @Inject(forwardRef(() => ChatGateway))
    private gateway: ChatGateway,
  ) {}

  // ── Authorization core ───────────────────────────────────────
  // A conversation EXISTS only once the driver has accepted the request
  // (confirmedAt set). Before that there is nothing to read or send.
  // Sending is further gated to the active window; reading survives for
  // history. Throws unless the caller is the passenger or the ride's driver.
  async resolveAccess(userId: string, bookingId: string): Promise<ChatAccess> {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { ride: { include: { driver: true } } },
    });

    if (!booking) throw new NotFoundException('Booking not found');

    const isPassenger = booking.passengerId === userId;
    const isDriver = booking.ride.driver.userId === userId;

    // Privacy: only the two participants may touch this conversation.
    if (!isPassenger && !isDriver) {
      throw new ForbiddenException('You are not part of this conversation');
    }

    // Chat opens on acceptance — never before.
    if (!booking.confirmedAt) {
      throw new ForbiddenException(
        'Chat is available only after the booking is accepted',
      );
    }

    return {
      booking: {
        id: booking.id,
        passengerId: booking.passengerId,
        status: booking.status,
        confirmedAt: booking.confirmedAt,
        completedAt: booking.completedAt,
        driverUserId: booking.ride.driver.userId,
      },
      isPassenger,
      isDriver,
      canSend: this.isSendable(booking.status, booking.completedAt),
    };
  }

  // Send window: while the ride is live (confirmed) or for a grace period
  // after completion. A cancelled/rejected/expired ride is read-only.
  private isSendable(status: string, completedAt: Date | null): boolean {
    if (status === 'confirmed') return true;
    if (status === 'completed' && completedAt) {
      return Date.now() - completedAt.getTime() <= POST_COMPLETION_CHAT_WINDOW_MS;
    }
    return false;
  }

  // ── Send a message ───────────────────────────────────────────
  async sendMessage(userId: string, bookingId: string, content: string) {
    const access = await this.resolveAccess(userId, bookingId);

    if (!access.canSend) {
      throw new ForbiddenException(
        'This conversation is closed. You can view history but not send new messages.',
      );
    }

    // Spam guard: max 20 messages per sender per 30s window.
    const recentCount = await this.prisma.message.count({
      where: { senderId: userId, sentAt: { gte: new Date(Date.now() - 30_000) } },
    });
    if (recentCount >= 20) {
      throw new BadRequestException(
        'You are sending messages too quickly. Please slow down.',
      );
    }

    // Moderate: redact phone/links/emails (off-platform bypass), flag abuse.
    // The message is delivered but sanitized.
    const { clean, flags, urls } = moderateMessage(content);
    if (flags.includes('phone') || flags.includes('link')) {
      await this.fraud.record(userId, 'chat_contact_share', 5, {
        bookingId,
        flags,
      });
    }
    if (flags.includes('suspicious_link')) {
      await this.fraud.record(userId, 'chat_suspicious_link', 10, { bookingId });
    }
    if (flags.includes('abuse')) {
      await this.fraud.record(userId, 'chat_abuse', 15, { bookingId });
    }
    if (urls.length > 0 && this.safeBrowsing.enabled) {
      void this.safeBrowsing.anyMalicious(urls).then((malicious) => {
        if (malicious) {
          void this.fraud.record(userId, 'chat_malware_link', 25, { bookingId });
        }
      });
    }

    const receiverId = access.isPassenger
      ? access.booking.driverUserId
      : access.booking.passengerId;

    const message = await this.prisma.message.create({
      data: { bookingId, senderId: userId, receiverId, content: clean },
      include: {
        sender: {
          select: { id: true, fullName: true, profilePhotoUrl: true },
        },
      },
    });

    // Fan out in real time to the conversation room and nudge the receiver's
    // personal room so their unread badge updates even off-screen.
    this.gateway.broadcastMessage(bookingId, message, receiverId);

    return message;
  }

  // ── Message history (marks received messages read) ───────────
  async getMessages(userId: string, bookingId: string) {
    const access = await this.resolveAccess(userId, bookingId);

    const messages = await this.prisma.message.findMany({
      where: { bookingId },
      orderBy: { sentAt: 'asc' },
      include: {
        sender: {
          select: { id: true, fullName: true, profilePhotoUrl: true },
        },
      },
    });

    await this.markRead(userId, bookingId);

    return { messages, total: messages.length, canSend: access.canSend };
  }

  // ── Mark my received messages as read ────────────────────────
  async markRead(userId: string, bookingId: string) {
    // Guard access (throws for non-participants / un-accepted bookings).
    const access = await this.resolveAccess(userId, bookingId);

    const result = await this.prisma.message.updateMany({
      where: { bookingId, receiverId: userId, isRead: false },
      data: { isRead: true },
    });

    if (result.count > 0) {
      // Let the other party's open thread flip the ticks to "read".
      const otherUserId = access.isPassenger
        ? access.booking.driverUserId
        : access.booking.passengerId;
      this.gateway.broadcastRead(bookingId, userId, otherUserId);
    }

    return { updated: result.count };
  }

  // ── Conversation list for the Messages tab ───────────────────
  // Every accepted booking the user is part of, with the other participant,
  // last message, unread count and whether it is still open for sending.
  async listConversations(userId: string) {
    const bookings = await this.prisma.booking.findMany({
      where: {
        confirmedAt: { not: null },
        OR: [{ passengerId: userId }, { ride: { driver: { userId } } }],
      },
      include: {
        passenger: {
          select: { id: true, fullName: true, profilePhotoUrl: true },
        },
        ride: {
          select: {
            originName: true,
            destName: true,
            departureAt: true,
            driver: {
              select: {
                user: {
                  select: { id: true, fullName: true, profilePhotoUrl: true },
                },
              },
            },
          },
        },
        messages: { orderBy: { sentAt: 'desc' }, take: 1 },
      },
      orderBy: { confirmedAt: 'desc' },
    });

    const conversations = await Promise.all(
      bookings.map(async (b) => {
        const isPassenger = b.passengerId === userId;
        const other = isPassenger ? b.ride.driver.user : b.passenger;
        const unreadCount = await this.prisma.message.count({
          where: { bookingId: b.id, receiverId: userId, isRead: false },
        });
        const lastMessage = b.messages[0] ?? null;

        return {
          bookingId: b.id,
          status: b.status,
          canSend: this.isSendable(b.status, b.completedAt),
          otherUser: {
            id: other.id,
            fullName: other.fullName,
            profilePhotoUrl: other.profilePhotoUrl,
          },
          role: isPassenger ? 'passenger' : 'driver',
          ride: {
            originName: b.ride.originName,
            destName: b.ride.destName,
            departureAt: b.ride.departureAt,
          },
          lastMessage: lastMessage
            ? {
                content: lastMessage.content,
                sentAt: lastMessage.sentAt,
                senderId: lastMessage.senderId,
                isRead: lastMessage.isRead,
              }
            : null,
          unreadCount,
          // Sort key: newest activity first (last message, else acceptance).
          lastActivityAt: lastMessage ? lastMessage.sentAt : b.confirmedAt,
        };
      }),
    );

    conversations.sort(
      (a, b) =>
        new Date(b.lastActivityAt as Date).getTime() -
        new Date(a.lastActivityAt as Date).getTime(),
    );

    return { conversations, total: conversations.length };
  }

  // ── Total unread across all conversations (nav badge) ────────
  async unreadCount(userId: string) {
    const count = await this.prisma.message.count({
      where: {
        receiverId: userId,
        isRead: false,
        booking: { confirmedAt: { not: null } },
      },
    });
    return { unreadCount: count };
  }

  // Called by BookingsService the moment a request is accepted so both
  // participants get an immediate "chat is now open" signal.
  notifyChatOpened(bookingId: string, passengerId: string, driverUserId: string) {
    this.gateway.broadcastConversationOpened(bookingId, [
      passengerId,
      driverUserId,
    ]);
  }
}
