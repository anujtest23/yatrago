import {
  Controller,
  Get,
  Header,
  NotFoundException,
  Req,
  UnauthorizedException,
} from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { ApiExcludeController } from '@nestjs/swagger';
import type { Request } from 'express';
import { createHash, timingSafeEqual } from 'crypto';
import { MetricsService } from './metrics.service';
import { appConfig } from '../../config/app.config';

/**
 * Prometheus scrape endpoint. Fails closed: without METRICS_TOKEN the route
 * behaves as if it does not exist (404, same as any unknown path — no oracle
 * that monitoring is merely "misconfigured"). With a token, the scraper must
 * send `Authorization: Bearer <METRICS_TOKEN>`.
 */
@ApiExcludeController()
@SkipThrottle()
@Controller('metrics')
export class MetricsController {
  constructor(private metrics: MetricsService) {}

  @Get()
  @Header('Content-Type', 'text/plain; version=0.0.4')
  async scrape(@Req() req: Request): Promise<string> {
    if (!appConfig.metricsToken) {
      throw new NotFoundException();
    }
    const header = req.headers.authorization ?? '';
    const presented = header.startsWith('Bearer ') ? header.slice(7) : '';
    // Hash both sides so timingSafeEqual gets equal-length buffers.
    const a = createHash('sha256').update(presented).digest();
    const b = createHash('sha256').update(appConfig.metricsToken).digest();
    if (!timingSafeEqual(a, b)) {
      throw new UnauthorizedException();
    }
    return this.metrics.metrics();
  }
}
