import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../../database/prisma.service';
import { EsewaInitiateDto, EsewaVerifyDto } from '../dto/esewa-payment.dto';
import { appConfig } from '../../../config/app.config';
import axios from 'axios';
import * as crypto from 'crypto';

@Injectable()
export class EsewaService {
  constructor(private prisma: PrismaService) {}

  // ── Generate eSewa signature ─────────────────────────────────
  private generateSignature(
    totalAmount: number,
    transactionUuid: string,
    productCode: string,
  ): string {
    const message = `total_amount=${totalAmount},transaction_uuid=${transactionUuid},product_code=${productCode}`;
    return crypto
      .createHmac('sha256', appConfig.esewaSecret)
      .update(message)
      .digest('base64');
  }

  // ── POST /payments/esewa/initiate ────────────────────────────
  async initiate(userId: string, dto: EsewaInitiateDto) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: dto.bookingId },
      include: {
        ride: {
          select: { originName: true, destName: true },
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

    const transactionUuid = `${dto.bookingId}-${Date.now()}`;
    const productCode = appConfig.esewaMerchantId;

    // In development — return mock form data
    if (appConfig.nodeEnv === 'development') {
      console.log(`[DEV] eSewa initiate for booking ${dto.bookingId}, amount: NPR ${dto.amount}`);

      await this.prisma.payment.create({
        data: {
          bookingId: dto.bookingId,
          userId,
          amount: dto.amount,
          method: 'esewa',
          status: 'pending',
          gatewayRef: transactionUuid,
        },
      });

      return {
        message: 'eSewa payment initiated (sandbox)',
        transactionUuid,
        productCode,
        amount: dto.amount,
        bookingId: dto.bookingId,
        // These are the form fields Flutter needs to POST to eSewa
        formData: {
          amount: dto.amount,
          tax_amount: 0,
          total_amount: dto.amount,
          transaction_uuid: transactionUuid,
          product_code: productCode,
          product_service_charge: 0,
          product_delivery_charge: 0,
          success_url: 'https://yatrago.com/payment/esewa/success',
          failure_url: 'https://yatrago.com/payment/esewa/failure',
          signed_field_names: 'total_amount,transaction_uuid,product_code',
          signature: this.generateSignature(dto.amount, transactionUuid, productCode),
        },
        esewaUrl: appConfig.esewaBaseUrl,
      };
    }

    // Production form data
    const signature = this.generateSignature(
      dto.amount,
      transactionUuid,
      productCode,
    );

    await this.prisma.payment.create({
      data: {
        bookingId: dto.bookingId,
        userId,
        amount: dto.amount,
        method: 'esewa',
        status: 'pending',
        gatewayRef: transactionUuid,
      },
    });

    return {
      transactionUuid,
      formData: {
        amount: dto.amount,
        tax_amount: 0,
        total_amount: dto.amount,
        transaction_uuid: transactionUuid,
        product_code: productCode,
        product_service_charge: 0,
        product_delivery_charge: 0,
        success_url: 'https://yatrago.com/payment/esewa/success',
        failure_url: 'https://yatrago.com/payment/esewa/failure',
        signed_field_names: 'total_amount,transaction_uuid,product_code',
        signature,
      },
      esewaUrl: `${appConfig.esewaBaseUrl}/api/epay/main/v2/form`,
    };
  }

  // ── POST /payments/esewa/verify ──────────────────────────────
  async verify(userId: string, dto: EsewaVerifyDto) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: dto.bookingId },
    });

    if (!booking) throw new NotFoundException('Booking not found');

    // In development — auto approve
    if (appConfig.nodeEnv === 'development') {
      console.log(`[DEV] eSewa verify for booking ${dto.bookingId}`);

      await this.prisma.$transaction(async (tx) => {
        await tx.payment.updateMany({
          where: {
            bookingId: dto.bookingId,
            method: 'esewa',
            status: 'pending',
          },
          data: {
            status: 'paid',
            completedAt: new Date(),
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
        message: 'eSewa payment verified successfully (sandbox)',
        bookingId: dto.bookingId,
        status: 'paid',
      };
    }

    // Production — decode and verify eSewa response
    try {
      const decoded = Buffer.from(dto.encodedData, 'base64').toString('utf-8');
      const esewaResponse = JSON.parse(decoded);

      if (esewaResponse.status !== 'COMPLETE') {
        throw new BadRequestException(
          `eSewa payment not completed. Status: ${esewaResponse.status}`,
        );
      }

      await this.prisma.$transaction(async (tx) => {
        await tx.payment.updateMany({
          where: {
            bookingId: dto.bookingId,
            method: 'esewa',
            status: 'pending',
          },
          data: {
            status: 'paid',
            completedAt: new Date(),
            gatewayResponse: esewaResponse,
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
        message: 'eSewa payment verified successfully',
        bookingId: dto.bookingId,
        status: 'paid',
      };
    } catch (error) {
      throw new BadRequestException(
        `eSewa verification failed: ${error.message}`,
      );
    }
  }
}