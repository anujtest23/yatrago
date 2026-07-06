import {
  CallHandler,
  ExecutionContext,
  HttpException,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, tap } from 'rxjs';
import type { Request, Response } from 'express';
import { MetricsService } from '../../modules/platform/metrics.service';

/** Records request counts (by status class) and duration for Prometheus. */
@Injectable()
export class MetricsInterceptor implements NestInterceptor {
  constructor(private metrics: MetricsService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') return next.handle();

    const req = context.switchToHttp().getRequest<Request>();
    const stop = this.metrics.httpDuration.startTimer({ method: req.method });

    return next.handle().pipe(
      tap({
        next: () => {
          stop();
          const res = context.switchToHttp().getResponse<Response>();
          this.metrics.httpRequests.inc({
            method: req.method,
            status: `${Math.floor(res.statusCode / 100)}xx`,
          });
        },
        error: (err: unknown) => {
          stop();
          const status = err instanceof HttpException ? err.getStatus() : 500;
          this.metrics.httpRequests.inc({
            method: req.method,
            status: `${Math.floor(status / 100)}xx`,
          });
        },
      }),
    );
  }
}
