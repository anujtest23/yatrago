import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../../database/prisma.service';
import { KhaltiInitiateDto, KhaltiVerifyDto } from '../dto/khalti-payment.dto';
import { appConfig } from '../../../config/app.config';
import axios from 'axios';

@Injectable()
export class KhaltiService {
  constructor(private prisma: PrismaService) {}

  // ── POST /payments/khalti/initiate ───────────────────────────
  async initiate(userId: string, dto: KhaltiInitiateDto) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: dto.bookingId },
      include: {
        ride: {
          select: {
            originName: true,
            destName: true,
          },
        },
      },
    });

    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.passengerId !== userId) {
      throw new BadRequestException('This booking does not belong to you');
    }
    if (booking.paymentStatus === 'paid') {
      throw new BadRequestException('This booking is already paid');
    }

    // Amount in paisa (Khalti uses paisa — multiply by 100)
    const amountInPaisa = dto.amount * 100;

    // In development — return mock response
    if (appConfig.nodeEnv === 'development') {
      console.log(`[DEV] Khalti initiate for booking ${dto.bookingId}, amount: NPR ${dto.amount}`);

      // Create a pending payment record
      await this.prisma.payment.create({
        data: {
          bookingId: dto.bookingId,
          userId,
          amount: dto.amount,
          method: 'khalti',
          status: 'pending',
          gatewayRef: `DEV_KHALTI_${Date.now()}`,
        },
      });

      return {
        message: 'Khalti payment initiated (sandbox)',
        pidx: `test_pidx_${Date.now()}`,
        paymentUrl: `https://test-pay.khalti.com/?pidx=test_pidx`,
        amount: dto.amount,
        amountInPaisa,
        bookingId: dto.bookingId,
      };
    }

    // Production — call real Khalti API
    try {
      const response = await axios.post(
        `${appConfig.khaltiBaseUrl}/epayment/initiate/`,
        {
          return_url: 'https://yatrago.com/payment/khalti/callback',
          website_url: 'https://yatrago.com',
          amount: amountInPaisa,
          purchase_order_id: dto.bookingId,
          purchase_order_name: `YatraGo - ${booking.ride.originName} to ${booking.ride.destName}`,
          customer_info: { userId },
        },
        {
          headers: {
            Authorization: `Key ${appConfig.khaltiSecretKey}`,
            'Content-Type': 'application/json',
          },
        },
      );

      // Save payment record
      await this.prisma.payment.create({
        data: {
          bookingId: dto.bookingId,
          userId,
          amount: dto.amount,
          method: 'khalti',
          status: 'pending',
          gatewayRef: response.data.pidx,
        },
      });

      return {
        pidx: response.data.pidx,
        paymentUrl: response.data.payment_url,
        amount: dto.amount,
        bookingId: dto.bookingId,
      };
    } catch (error) {
      throw new BadRequestException(
        `Khalti initiation failed: ${error.response?.data?.detail || error.message}`,
      );
    }
  }

  // ── POST /payments/khalti/verify ─────────────────────────────
  async verify(userId: string, dto: KhaltiVerifyDto) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: dto.bookingId },
    });

    if (!booking) throw new NotFoundException('Booking not found');

    // In development — auto-approve
    if (appConfig.nodeEnv === 'development') {
      console.log(`[DEV] Khalti verify for booking ${dto.bookingId}`);

      await this.prisma.$transaction(async (tx) => {
        // Mark payment as paid
        await tx.payment.updateMany({
          where: {
            bookingId: dto.bookingId,
            method: 'khalti',
            status: 'pending',
          },
          data: {
            status: 'paid',
            completedAt: new Date(),
            gatewayRef: dto.pidx,
          },
        });

        // Confirm the booking
        await tx.booking.update({
          where: { id: dto.bookingId },
          data: {
            status: 'confirmed',
            paymentStatus: 'paid',
            confirmedAt: new Date(),
          },
        });
      });

      return {
        message: 'Payment verified successfully (sandbox)',
        bookingId: dto.bookingId,
        status: 'paid',
      };
    }

    // Production — verify with Khalti
    try {
      const response = await axios.post(
        `${appConfig.khaltiBaseUrl}/epayment/lookup/`,
        { pidx: dto.pidx },
        {
          headers: {
            Authorization: `Key ${appConfig.khaltiSecretKey}`,
            'Content-Type': 'application/json',
          },
        },
      );

      if (response.data.status !== 'Completed') {
        throw new BadRequestException(
          `Payment not completed. Status: ${response.data.status}`,
        );
      }

      await this.prisma.$transaction(async (tx) => {
        await tx.payment.updateMany({
          where: {
            bookingId: dto.bookingId,
            method: 'khalti',
            status: 'pending',
          },
          data: {
            status: 'paid',
            completedAt: new Date(),
            gatewayRef: dto.pidx,
            gatewayResponse: response.data,
          },
        });

        await tx.booking.update({
          where: { id: dto.bookingId },
          data: {
            status: 'confirmed',
            paymentStatus: 'paid',
            confirmedAt: new Date(),
          },
        });
      });

      return {
        message: 'Payment verified successfully',
        bookingId: dto.bookingId,
        status: 'paid',
      };
    } catch (error) {
      throw new BadRequestException(
        `Khalti verification failed: ${error.response?.data?.detail || error.message}`,
      );
    }
  }
}