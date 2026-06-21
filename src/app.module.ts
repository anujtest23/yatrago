import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER, APP_INTERCEPTOR } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { ResponseInterceptor } from './common/interceptors/response.interceptor';

@Module({
  imports: [
    // Load .env globally across all modules
    ConfigModule.forRoot({ isGlobal: true }),
    // Database — available everywhere due to @Global()
    DatabaseModule,
  ],
  providers: [
    // Apply exception filter to every route
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    // Apply response wrapper to every route
    { provide: APP_INTERCEPTOR, useClass: ResponseInterceptor },
  ],
})
export class AppModule {}