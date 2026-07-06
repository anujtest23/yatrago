import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { Logger, ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import * as Sentry from '@sentry/node';

import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import type { Response } from 'express';
import { appConfig } from './config/app.config';

/**
 * Application bootstrap. Lives in its own module (imported dynamically from
 * main.ts) so that managed secrets are hydrated into process.env BEFORE
 * app.config.ts — which reads env at import time — is ever evaluated.
 */
export async function run(): Promise<void> {
  const logger = new Logger('Bootstrap');

  // Error tracking: only active when a DSN is provided. No request bodies
  // or headers are ever attached — stacks only (no PII).
  if (appConfig.sentryDsn) {
    Sentry.init({
      dsn: appConfig.sentryDsn,
      environment: appConfig.nodeEnv,
      sendDefaultPii: false,
      tracesSampleRate: 0,
    });
  }

  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    rawBody: false,
  });

  // Behind a reverse proxy / WAF (nginx, Cloudflare, AWS ALB) trust
  // X-Forwarded-For only to the configured depth or from the configured
  // proxy IPs/CIDRs, so rate limiting and audit logs see the real client IP
  // while a direct client can never spoof one (IP-spoofing protection).
  if (appConfig.trustProxy !== false) {
    app.set('trust proxy', appConfig.trustProxy);
  }

  // Security headers (HSTS, nosniff, frame-deny, etc.)
  app.use(
    helmet({
      // API serves JSON + static uploads only; a strict default CSP is fine.
      crossOriginResourcePolicy: { policy: 'cross-origin' }, // uploads consumed by app/admin
    }),
  );

  // Cap request bodies — JSON APIs never need more than 1 MB.
  app.useBodyParser('json', { limit: '1mb' });
  app.useBodyParser('urlencoded', { limit: '1mb', extended: true });

  // Global prefix — all routes start with /api/v1
  app.setGlobalPrefix('api/v1');
  // Public uploads (profile/vehicle photos). KYC documents live OUTSIDE
  // this root (uploads-private/) and are served only via signed URLs.
  app.useStaticAssets(join(__dirname, '..', 'uploads'), {
    prefix: '/uploads',
    setHeaders: (res: Response) => {
      res.setHeader('X-Content-Type-Options', 'nosniff');
      // Neutralize any active content that might slip through validation.
      res.setHeader('Content-Security-Policy', "default-src 'none'; sandbox");
    },
  });

  // Auto-validate all incoming request bodies
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // strip unknown fields (mass-assignment defense)
      forbidNonWhitelisted: true,
      transform: true, // auto-convert types
    }),
  );

  // CORS: explicit browser-origin allowlist (admin console). Mobile apps
  // send no Origin header and are unaffected by CORS entirely.
  app.enableCors({
    origin: (origin, callback) => {
      if (!origin || appConfig.corsOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'), false);
      }
    },
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Device-Id'],
    maxAge: 600,
  });

  // Swagger docs: on by default outside production, opt-in (SWAGGER_ENABLED)
  // in production — never expose the API surface map by accident.
  if (appConfig.swaggerEnabled) {
    const config = new DocumentBuilder()
      .setTitle('YatraGo API')
      .setDescription('Nepal ride-sharing app')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('api/docs', app, document);
  }

  await app.listen(appConfig.port);
  logger.log(`YatraGo API running on port ${appConfig.port} (/api/v1)`);
  if (appConfig.swaggerEnabled) {
    logger.log(`Swagger docs at /api/docs`);
  }
}
