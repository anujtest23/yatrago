import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import * as Sentry from '@sentry/node';
import { appConfig } from '../../config/app.config';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const message =
      exception instanceof HttpException
        ? exception.getResponse()
        : 'Internal server error';

    // Log the FULL error including stack trace
    this.logger.error(
      `${request.method} ${request.url} → ${status}`,
      exception instanceof Error ? exception.stack : String(exception),
    );

    // Ship unexpected failures (5xx only — expected 4xx are noise) to Sentry
    // when configured. Route + method only; never bodies/headers (no PII).
    if (status >= 500 && appConfig.sentryDsn) {
      Sentry.captureException(exception, {
        tags: { method: request.method },
        extra: { path: request.url },
      });
    }

    response.status(status).json({
      success: false,
      statusCode: status,
      message:
        typeof message === 'object'
          ? (message as any).message || message
          : message,
      timestamp: new Date().toISOString(),
      path: request.url,
    });
  }
}
