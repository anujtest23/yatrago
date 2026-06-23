import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';

@Injectable()
export class VehiclesService {
  constructor(private prisma: PrismaService) {}

  // ── Helper: get driver profile or throw ─────────────────────
  private async getDriverProfile(userId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
    });
    if (!driver) {
      throw new ForbiddenException(
        'Driver profile not found. Apply as a driver first.',
      );
    }
    return driver;
  }

  // ── Helper: verify vehicle belongs to driver ─────────────────
  private async getVehicleOrThrow(vehicleId: string, driverId: string) {
    const vehicle = await this.prisma.vehicle.findUnique({
      where: { id: vehicleId },
    });
    if (!vehicle) throw new NotFoundException('Vehicle not found');
    if (vehicle.driverId !== driverId) {
      throw new ForbiddenException('This vehicle does not belong to you');
    }
    return vehicle;
  }

  // ── POST /vehicles ──────────────────────────────────────────
  async create(userId: string, dto: CreateVehicleDto) {
    const driver = await this.getDriverProfile(userId);

    // Check plate number not already registered
    const existing = await this.prisma.vehicle.findUnique({
      where: { plateNumber: dto.plateNumber },
    });
    if (existing) {
      throw new ConflictException(
        'A vehicle with this plate number already exists',
      );
    }

    const vehicle = await this.prisma.vehicle.create({
      data: {
        driverId: driver.id,
        make: dto.make,
        model: dto.model,
        year: dto.year,
        plateNumber: dto.plateNumber,
        color: dto.color,
        vehicleType: dto.vehicleType as any,
        totalSeats: dto.totalSeats,
      },
    });

    return {
      message: 'Vehicle added successfully',
      vehicle,
    };
  }

  // ── GET /vehicles ───────────────────────────────────────────
  async findAll(userId: string) {
    const driver = await this.getDriverProfile(userId);

    const vehicles = await this.prisma.vehicle.findMany({
      where: {
        driverId: driver.id,
        isActive: true,
      },
      include: {
        documents: {
          select: {
            docType: true,
            status: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return { vehicles, total: vehicles.length };
  }

  // ── GET /vehicles/:id ───────────────────────────────────────
  async findOne(userId: string, vehicleId: string) {
    const driver = await this.getDriverProfile(userId);
    const vehicle = await this.getVehicleOrThrow(vehicleId, driver.id);

    return this.prisma.vehicle.findUnique({
      where: { id: vehicleId },
      include: {
        documents: {
          select: {
            id: true,
            docType: true,
            fileUrl: true,
            status: true,
          },
        },
      },
    });
  }

  // ── PATCH /vehicles/:id ─────────────────────────────────────
  async update(userId: string, vehicleId: string, dto: UpdateVehicleDto) {
    const driver = await this.getDriverProfile(userId);
    await this.getVehicleOrThrow(vehicleId, driver.id);

    const vehicle = await this.prisma.vehicle.update({
      where: { id: vehicleId },
      data: {
        ...(dto.make && { make: dto.make }),
        ...(dto.model && { model: dto.model }),
        ...(dto.year && { year: dto.year }),
        ...(dto.color && { color: dto.color }),
        ...(dto.vehicleType && { vehicleType: dto.vehicleType as any }),
        ...(dto.totalSeats && { totalSeats: dto.totalSeats }),
      },
    });

    return { message: 'Vehicle updated successfully', vehicle };
  }

  // ── DELETE /vehicles/:id ────────────────────────────────────
  async remove(userId: string, vehicleId: string) {
    const driver = await this.getDriverProfile(userId);
    await this.getVehicleOrThrow(vehicleId, driver.id);

    // Soft delete
    await this.prisma.vehicle.update({
      where: { id: vehicleId },
      data: { isActive: false },
    });

    return { message: 'Vehicle removed successfully' };
  }

  // ── POST /vehicles/:id/documents ────────────────────────────
async uploadDocument(
    userId: string,
    vehicleId: string,
    docType: 'bluebook' | 'insurance',
    file: Express.Multer.File,
  ) {
    const driver = await this.getDriverProfile(userId);
    await this.getVehicleOrThrow(vehicleId, driver.id);

    const fileUrl = `/uploads/${file.filename}`;

    const existingDoc = await this.prisma.vehicleDocument.findFirst({
      where: { vehicleId, docType: docType as any },
    });

    if (existingDoc) {
      await this.prisma.vehicleDocument.update({
        where: { id: existingDoc.id },
        data: { fileUrl, status: 'pending' },
      });
    } else {
      await this.prisma.vehicleDocument.create({
        data: {
          vehicleId,
          docType: docType as any,
          fileUrl,
          status: 'pending',
        },
      });
    }

    return {
      message: `${docType} uploaded successfully`,
      fileUrl,
    };
  }}