import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateSosDto } from './dto/create-sos.dto';
import { CreateEmergencyContactDto } from './dto/create-emergency-contact.dto';
import { SmsService } from '../platform/sms.service';

const MAX_EMERGENCY_CONTACTS = 3;
const SOS_DEBOUNCE_MS = 2 * 60 * 1000;

@Injectable()
export class SafetyService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private sms: SmsService,
  ) {}

  // ── Send SMS via shared SmsService (never throws) ───────────
  private async sendSms(phone: string, message: string): Promise<void> {
    await this.sms.send(phone, message);
  }

  // ── POST /sos ────────────────────────────────────────────────
  async createSos(userId: string, dto: CreateSosDto) {
    // Debounce: reuse an open alert created within the last 2 minutes
    const recentOpen = await this.prisma.sosAlert.findFirst({
      where: {
        userId,
        status: 'open' as any,
        createdAt: { gte: new Date(Date.now() - SOS_DEBOUNCE_MS) },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (recentOpen) {
      return {
        message: 'An SOS alert is already active',
        alert: recentOpen,
      };
    }

    const alert = await this.prisma.sosAlert.create({
      data: {
        userId,
        bookingId: dto.bookingId,
        lat: dto.lat,
        lng: dto.lng,
        note: dto.note,
      },
    });

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { fullName: true, phoneNumber: true },
    });
    const name = user?.fullName ?? user?.phoneNumber ?? 'A YatraGo user';

    // Alert the user's emergency contacts by SMS
    const contacts = await this.prisma.emergencyContact.findMany({
      where: { userId },
    });
    const smsText = `[YatraGo SOS] ${name} triggered an emergency alert. Location: https://maps.google.com/?q=${dto.lat},${dto.lng}`;
    await Promise.all(
      contacts.map((c) => this.sendSms(c.phoneNumber, smsText)),
    );

    // Confirm to the user that the alert went out
    this.notifications
      .createNotification(
        userId,
        'sos_alert',
        'SOS Alert Sent',
        `Your emergency alert has been sent to ${contacts.length} emergency contact${contacts.length === 1 ? '' : 's'} and the YatraGo safety team.`,
        { sosId: alert.id },
      )
      .catch(() => undefined);

    return { message: 'SOS alert created', alert };
  }

  // ── GET /sos/mine ────────────────────────────────────────────
  async getMyAlerts(userId: string) {
    const alerts = await this.prisma.sosAlert.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
    return { alerts, total: alerts.length };
  }

  // ── GET /users/me/emergency-contacts ─────────────────────────
  async getEmergencyContacts(userId: string) {
    const contacts = await this.prisma.emergencyContact.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
    });
    return { contacts, total: contacts.length };
  }

  // ── POST /users/me/emergency-contacts ────────────────────────
  async addEmergencyContact(userId: string, dto: CreateEmergencyContactDto) {
    const count = await this.prisma.emergencyContact.count({
      where: { userId },
    });
    if (count >= MAX_EMERGENCY_CONTACTS) {
      throw new BadRequestException(
        `You can only have up to ${MAX_EMERGENCY_CONTACTS} emergency contacts`,
      );
    }

    const contact = await this.prisma.emergencyContact.create({
      data: {
        userId,
        fullName: dto.fullName,
        phoneNumber: dto.phoneNumber,
        relationship: dto.relationship,
      },
    });

    return { message: 'Emergency contact added', contact };
  }

  // ── DELETE /users/me/emergency-contacts/:id ──────────────────
  async removeEmergencyContact(userId: string, contactId: string) {
    const contact = await this.prisma.emergencyContact.findUnique({
      where: { id: contactId },
    });
    if (!contact) throw new NotFoundException('Emergency contact not found');
    if (contact.userId !== userId) {
      throw new ForbiddenException(
        'This emergency contact does not belong to you',
      );
    }

    await this.prisma.emergencyContact.delete({ where: { id: contactId } });

    return { message: 'Emergency contact removed' };
  }
}
