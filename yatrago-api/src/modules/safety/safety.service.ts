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
import { UpdateEmergencyContactDto } from './dto/update-emergency-contact.dto';
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

    // A referenced booking must actually involve the caller — otherwise a
    // stray/forged id pollutes the safety team's incident context.
    if (dto.bookingId) {
      const booking = await this.prisma.booking.findUnique({
        where: { id: dto.bookingId },
        include: { ride: { include: { driver: true } } },
      });
      const isParticipant =
        booking &&
        (booking.passengerId === userId ||
          booking.ride.driver.userId === userId);
      if (!isParticipant) {
        throw new ForbiddenException('You are not part of this booking');
      }
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
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
    });
    return { contacts, total: contacts.length };
  }

  // Digits-only comparison so +9779800000000 and 9800000000 count as one.
  private normalizePhone(phone: string): string {
    return phone.replace(/\D/g, '').slice(-10);
  }

  // ── POST /users/me/emergency-contacts ────────────────────────
  async addEmergencyContact(userId: string, dto: CreateEmergencyContactDto) {
    const existing = await this.prisma.emergencyContact.findMany({
      where: { userId },
    });
    if (existing.length >= MAX_EMERGENCY_CONTACTS) {
      throw new BadRequestException(
        `You can only have up to ${MAX_EMERGENCY_CONTACTS} emergency contacts`,
      );
    }
    const incoming = this.normalizePhone(dto.phoneNumber);
    if (existing.some((c) => this.normalizePhone(c.phoneNumber) === incoming)) {
      throw new BadRequestException('This phone number is already a contact');
    }

    const nextOrder =
      existing.reduce((max, c) => Math.max(max, c.sortOrder), -1) + 1;

    const contact = await this.prisma.emergencyContact.create({
      data: {
        userId,
        fullName: dto.fullName,
        phoneNumber: dto.phoneNumber,
        relationship: dto.relationship,
        sortOrder: nextOrder,
      },
    });

    return { message: 'Emergency contact added', contact };
  }

  // ── PATCH /users/me/emergency-contacts/:id ───────────────────
  async updateEmergencyContact(
    userId: string,
    contactId: string,
    dto: UpdateEmergencyContactDto,
  ) {
    const contact = await this.getOwnedContact(userId, contactId);

    if (dto.phoneNumber) {
      const incoming = this.normalizePhone(dto.phoneNumber);
      const clash = await this.prisma.emergencyContact.findFirst({
        where: { userId, id: { not: contactId } },
      });
      if (
        clash &&
        this.normalizePhone(clash.phoneNumber) === incoming
      ) {
        throw new BadRequestException('This phone number is already a contact');
      }
    }

    const updated = await this.prisma.emergencyContact.update({
      where: { id: contact.id },
      data: {
        fullName: dto.fullName ?? undefined,
        phoneNumber: dto.phoneNumber ?? undefined,
        relationship: dto.relationship ?? undefined,
      },
    });
    return { message: 'Emergency contact updated', contact: updated };
  }

  // ── PATCH /users/me/emergency-contacts/reorder ───────────────
  async reorderEmergencyContacts(userId: string, orderedIds: string[]) {
    const owned = await this.prisma.emergencyContact.findMany({
      where: { userId },
      select: { id: true },
    });
    const ownedIds = new Set(owned.map((c) => c.id));
    if (
      orderedIds.length !== owned.length ||
      !orderedIds.every((id) => ownedIds.has(id))
    ) {
      throw new BadRequestException(
        'orderedIds must contain exactly your current contact IDs',
      );
    }

    await this.prisma.$transaction(
      orderedIds.map((id, index) =>
        this.prisma.emergencyContact.update({
          where: { id },
          data: { sortOrder: index },
        }),
      ),
    );
    return this.getEmergencyContacts(userId);
  }

  // ── DELETE /users/me/emergency-contacts/:id ──────────────────
  async removeEmergencyContact(userId: string, contactId: string) {
    const contact = await this.getOwnedContact(userId, contactId);
    await this.prisma.emergencyContact.delete({ where: { id: contact.id } });
    return { message: 'Emergency contact removed' };
  }

  private async getOwnedContact(userId: string, contactId: string) {
    const contact = await this.prisma.emergencyContact.findUnique({
      where: { id: contactId },
    });
    if (!contact) throw new NotFoundException('Emergency contact not found');
    if (contact.userId !== userId) {
      throw new ForbiddenException(
        'This emergency contact does not belong to you',
      );
    }
    return contact;
  }
}
