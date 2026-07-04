import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';

@Injectable()
export class AuditService {
  constructor(private prisma: PrismaService) {}

  // Fire-and-forget: audit failures must never break the main action.
  async log(
    actorId: string,
    action: string,
    targetType: string,
    targetId?: string,
    details?: Record<string, any>,
  ): Promise<void> {
    try {
      await this.prisma.auditLog.create({
        data: { actorId, action, targetType, targetId, details },
      });
    } catch (error) {
      console.error('Audit log write failed:', error.message);
    }
  }
}
