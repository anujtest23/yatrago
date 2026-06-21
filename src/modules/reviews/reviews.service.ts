import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CreateReviewDto } from './dto/create-review.dto';

@Injectable()
export class ReviewsService {
  constructor(private prisma: PrismaService) {}

  // ── POST /reviews ────────────────────────────────────────────
  async create(userId: string, dto: CreateReviewDto) {
    // Get the booking
    const booking = await this.prisma.booking.findUnique({
      where: { id: dto.bookingId },
      include: {
        ride: {
          include: {
            driver: true,
          },
        },
      },
    });

    if (!booking) throw new NotFoundException('Booking not found');

    // Booking must be completed to leave a review
    if (booking.status !== 'completed' && booking.status !== 'confirmed') {
      throw new BadRequestException(
        'You can only review after the trip is completed or confirmed',
      );
    }

    // Verify the reviewer is part of this booking
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });

    const isPassenger = booking.passengerId === userId;
    const isDriver = driver && booking.ride.driverId === driver.id;

    if (!isPassenger && !isDriver) {
      throw new ForbiddenException(
        'You are not part of this booking',
      );
    }

    // Passenger can only rate driver, driver can only rate passenger
    if (isPassenger && dto.rateeType !== 'driver') {
      throw new BadRequestException('Passengers can only rate drivers');
    }
    if (isDriver && dto.rateeType !== 'passenger') {
      throw new BadRequestException('Drivers can only rate passengers');
    }

    // Check not already reviewed
    const existingReview = await this.prisma.rating.findFirst({
      where: {
        bookingId: dto.bookingId,
        raterId: userId,
      },
    });

    if (existingReview) {
      throw new ConflictException(
        'You have already submitted a review for this booking',
      );
    }

    // Validate score
    if (dto.score < 1 || dto.score > 5) {
      throw new BadRequestException('Score must be between 1 and 5');
    }

    // Create the review
    const review = await this.prisma.rating.create({
      data: {
        bookingId: dto.bookingId,
        raterId: userId,
        rateeId: dto.rateeId,
        rateeType: dto.rateeType as any,
        score: dto.score,
        reviewText: dto.reviewText,
      },
    });

    // Update the ratee's average rating
    await this.updateAverageRating(dto.rateeId, dto.rateeType);

    return {
      message: 'Review submitted successfully',
      review,
    };
  }

  // ── GET /reviews/user/:id ────────────────────────────────────
  async getUserReviews(userId: string) {
    const reviews = await this.prisma.rating.findMany({
      where: { rateeId: userId },
      include: {
        rater: {
          select: {
            id: true,
            fullName: true,
            profilePhotoUrl: true,
          },
        },
        booking: {
          select: {
            ride: {
              select: {
                originName: true,
                destName: true,
                departureAt: true,
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    // Calculate average
    const total = reviews.length;
    const average =
      total > 0
        ? reviews.reduce((sum, r) => sum + r.score, 0) / total
        : 0;

    // Score breakdown — how many 1s, 2s, 3s, 4s, 5s
    const breakdown = [1, 2, 3, 4, 5].map((score) => ({
      score,
      count: reviews.filter((r) => r.score === score).length,
    }));

    return {
      userId,
      averageRating: Math.round(average * 10) / 10,
      totalReviews: total,
      breakdown,
      reviews,
    };
  }

  // ── Helper: recalculate and update average rating ────────────
  private async updateAverageRating(
    rateeId: string,
    rateeType: string,
  ): Promise<void> {
    const allRatings = await this.prisma.rating.findMany({
      where: { rateeId },
      select: { score: true },
    });

    if (allRatings.length === 0) return;

    const average =
      allRatings.reduce((sum, r) => sum + r.score, 0) / allRatings.length;
    const rounded = Math.round(average * 100) / 100;

    if (rateeType === 'driver') {
      // Update driver profile average rating
      const driverProfile = await this.prisma.driverProfile.findUnique({
        where: { userId: rateeId },
      });
      if (driverProfile) {
        await this.prisma.driverProfile.update({
          where: { id: driverProfile.id },
          data: { averageRating: rounded },
        });
      }
    }
    // For passengers we just store on ratings table
    // No separate average field needed for MVP
  }
}