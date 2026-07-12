import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CreateSupportTicketDto } from './dto/create-support-ticket.dto';
import { CreateIssueReportDto } from './dto/create-issue-report.dto';
import { ReplyTicketDto } from './dto/reply-ticket.dto';
import { UpdateIssueDto } from './dto/update-issue.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditService } from '../platform/audit.service';
import { SupportStatus, ReportStatus } from '@prisma/client';

@Injectable()
export class SupportService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private audit: AuditService,
  ) {}

  // ── Contact Us (support tickets) ──────────────────────────────
  async createTicket(userId: string, dto: CreateSupportTicketDto) {
    const ticket = await this.prisma.supportTicket.create({
      data: {
        userId,
        category: dto.category,
        subject: dto.subject,
        description: dto.description,
        attachments: dto.attachments ?? [],
      },
    });
    return { message: 'Your message has been submitted', ticket };
  }

  listMyTickets(userId: string) {
    return this.prisma.supportTicket.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getMyTicket(userId: string, id: string) {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException('Ticket not found');
    if (ticket.userId !== userId) throw new ForbiddenException('Not your ticket');
    return ticket;
  }

  // ── Report an Issue (ride-specific) ───────────────────────────
  async createIssue(userId: string, dto: CreateIssueReportDto) {
    // If tied to a booking, verify the reporter is a party to it (IDOR guard).
    if (dto.bookingId) {
      const booking = await this.prisma.booking.findUnique({
        where: { id: dto.bookingId },
        include: { ride: { select: { driver: { select: { userId: true } } } } },
      });
      if (!booking) throw new NotFoundException('Booking not found');
      const isParty =
        booking.passengerId === userId ||
        booking.ride?.driver?.userId === userId;
      if (!isParty) {
        throw new ForbiddenException('You are not a party to this booking');
      }
    }

    const report = await this.prisma.issueReport.create({
      data: {
        userId,
        bookingId: dto.bookingId,
        rideId: dto.rideId,
        category: dto.category,
        description: dto.description,
        attachments: dto.attachments ?? [],
      },
    });
    return { message: 'Your issue has been reported', report };
  }

  listMyIssues(userId: string) {
    return this.prisma.issueReport.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ── Admin: tickets ────────────────────────────────────────────
  listTickets(status?: SupportStatus) {
    return this.prisma.supportTicket.findMany({
      where: status ? { status } : undefined,
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, fullName: true, phoneNumber: true } },
      },
    });
  }

  async replyTicket(adminId: string, id: string, dto: ReplyTicketDto) {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException('Ticket not found');

    const status = dto.status ?? 'in_progress';
    const updated = await this.prisma.supportTicket.update({
      where: { id },
      data: {
        adminReply: dto.reply ?? ticket.adminReply,
        status,
        resolvedAt: status === 'closed' ? new Date() : ticket.resolvedAt,
      },
    });

    if (dto.reply) {
      await this.notifications.createNotification(
        ticket.userId,
        'system',
        'Support Response',
        dto.reply,
        { ticketId: id },
      );
    }
    await this.audit.log(adminId, 'support.ticket_updated', 'support_ticket', id, {
      status,
    });
    return { message: 'Ticket updated', ticket: updated };
  }

  // ── Admin: issues ─────────────────────────────────────────────
  listIssues(status?: ReportStatus) {
    return this.prisma.issueReport.findMany({
      where: status ? { status } : undefined,
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, fullName: true, phoneNumber: true } },
      },
    });
  }

  async updateIssue(adminId: string, id: string, dto: UpdateIssueDto) {
    const issue = await this.prisma.issueReport.findUnique({ where: { id } });
    if (!issue) throw new NotFoundException('Issue report not found');

    const status = dto.status ?? issue.status;
    const updated = await this.prisma.issueReport.update({
      where: { id },
      data: {
        status,
        assignedTo: dto.assignedTo ?? issue.assignedTo,
        resolution: dto.resolution ?? issue.resolution,
        resolvedAt:
          status === 'resolved' || status === 'dismissed'
            ? new Date()
            : issue.resolvedAt,
      },
    });

    if (status === 'resolved' || status === 'dismissed') {
      await this.notifications.createNotification(
        issue.userId,
        'system',
        'Issue Update',
        `Your reported issue has been ${status}.` +
          (dto.resolution ? ` ${dto.resolution}` : ''),
        { issueId: id },
      );
    }
    await this.audit.log(adminId, 'support.issue_updated', 'issue_report', id, {
      status,
      assignedTo: dto.assignedTo,
    });
    return { message: 'Issue updated', report: updated };
  }
}
