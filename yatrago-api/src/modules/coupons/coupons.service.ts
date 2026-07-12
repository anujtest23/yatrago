import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { CreateCouponDto } from './dto/create-coupon.dto';
import { UpdateCouponDto } from './dto/update-coupon.dto';

export interface CouponQuote {
  couponId: string;
  code: string;
  discountAmount: number;
  finalAmount: number;
}

// Central coupon engine. NOTHING here trusts a client-supplied discount —
// every amount is recomputed from the stored coupon definition. Used by the
// booking flow (apply) and exposed for a preview endpoint.
@Injectable()
export class CouponsService {
  constructor(private prisma: PrismaService) {}

  private norm(code: string): string {
    return code.trim().toUpperCase();
  }

  private round2(n: number): number {
    return Math.round(n * 100) / 100;
  }

  // Validate a code against an amount + audience and return the computed
  // discount. Throws BadRequestException with a user-facing reason on any
  // failure. `role` is the redeeming user's active mode ('passenger'|'driver').
  async quote(
    userId: string,
    rawCode: string,
    amount: number,
    role: 'passenger' | 'driver',
  ): Promise<CouponQuote> {
    const code = this.norm(rawCode);
    const coupon = await this.prisma.coupon.findUnique({ where: { code } });
    if (!coupon || !coupon.isActive) {
      throw new BadRequestException('Invalid or inactive coupon code');
    }

    const now = new Date();
    if (coupon.validFrom && coupon.validFrom > now) {
      throw new BadRequestException('This coupon is not active yet');
    }
    if (coupon.validUntil && coupon.validUntil < now) {
      throw new BadRequestException('This coupon has expired');
    }
    if (coupon.audience !== 'all' && coupon.audience !== role) {
      throw new BadRequestException(
        `This coupon is only for ${coupon.audience}s`,
      );
    }
    if (amount < coupon.minAmount) {
      throw new BadRequestException(
        `A minimum amount of NPR ${coupon.minAmount} is required for this coupon`,
      );
    }

    // Usage caps count only non-reversed redemptions.
    if (coupon.usageLimit != null) {
      const used = await this.prisma.couponRedemption.count({
        where: { couponId: coupon.id, status: 'applied' },
      });
      if (used >= coupon.usageLimit) {
        throw new BadRequestException('This coupon has reached its usage limit');
      }
    }
    if (coupon.perUserLimit != null) {
      const usedByUser = await this.prisma.couponRedemption.count({
        where: { couponId: coupon.id, userId, status: 'applied' },
      });
      if (usedByUser >= coupon.perUserLimit) {
        throw new BadRequestException(
          'You have already used this coupon the maximum number of times',
        );
      }
    }

    let discount =
      coupon.discountType === 'percentage'
        ? (amount * coupon.discountValue) / 100
        : coupon.discountValue;
    if (coupon.maxDiscount != null) discount = Math.min(discount, coupon.maxDiscount);
    // Never discount below zero payable.
    discount = this.round2(Math.min(discount, amount));

    return {
      couponId: coupon.id,
      code: coupon.code,
      discountAmount: discount,
      finalAmount: this.round2(amount - discount),
    };
  }

  // Records a redemption inside the caller's transaction. One redemption per
  // booking (enforced by a unique index on bookingId).
  async recordRedemption(
    tx: Prisma.TransactionClient,
    params: {
      couponId: string;
      userId: string;
      bookingId: string;
      discountAmount: number;
    },
  ) {
    await tx.couponRedemption.create({ data: { ...params, status: 'applied' } });
  }

  // Reverses a booking's redemption so it no longer counts against limits.
  // Safe no-op if no redemption exists (booking used no coupon).
  async reverseForBooking(bookingId: string) {
    await this.prisma.couponRedemption.updateMany({
      where: { bookingId, status: 'applied' },
      data: { status: 'reversed', reversedAt: new Date() },
    });
  }

  // ── Admin CRUD ────────────────────────────────────────────────
  async create(dto: CreateCouponDto) {
    const code = this.norm(dto.code);
    const exists = await this.prisma.coupon.findUnique({ where: { code } });
    if (exists) throw new BadRequestException('Coupon code already exists');
    this.assertValidDefinition(dto);
    return this.prisma.coupon.create({ data: { ...dto, code } });
  }

  async update(id: string, dto: UpdateCouponDto) {
    await this.getOrThrow(id);
    if (dto.code) dto.code = this.norm(dto.code);
    this.assertValidDefinition(dto);
    return this.prisma.coupon.update({ where: { id }, data: dto });
  }

  async remove(id: string) {
    await this.getOrThrow(id);
    // Soft-disable rather than delete so redemption history stays intact.
    return this.prisma.coupon.update({
      where: { id },
      data: { isActive: false },
    });
  }

  async list() {
    return this.prisma.coupon.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async redemptions(couponId: string) {
    await this.getOrThrow(couponId);
    return this.prisma.couponRedemption.findMany({
      where: { couponId },
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, fullName: true, phoneNumber: true } },
      },
    });
  }

  private async getOrThrow(id: string) {
    const coupon = await this.prisma.coupon.findUnique({ where: { id } });
    if (!coupon) throw new NotFoundException('Coupon not found');
    return coupon;
  }

  private assertValidDefinition(dto: Partial<CreateCouponDto>) {
    if (
      dto.discountType === 'percentage' &&
      dto.discountValue != null &&
      (dto.discountValue <= 0 || dto.discountValue > 100)
    ) {
      throw new BadRequestException(
        'Percentage discount must be between 0 and 100',
      );
    }
    if (
      dto.discountType === 'fixed' &&
      dto.discountValue != null &&
      dto.discountValue <= 0
    ) {
      throw new BadRequestException('Fixed discount must be greater than 0');
    }
    if (
      dto.validFrom &&
      dto.validUntil &&
      new Date(dto.validFrom) > new Date(dto.validUntil)
    ) {
      throw new BadRequestException('validFrom must be before validUntil');
    }
  }
}
