import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';
import { appConfig } from '../../config/app.config';

// Central Sparrow SMS sender. All modules (auth OTP, safety SOS,
// booking-event fallbacks) delegate here so the gateway integration
// lives in exactly one place.
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  private maskPhone(phone: string): string {
    return phone.slice(0, 6) + '******' + phone.slice(-2);
  }

  async send(phone: string, message: string): Promise<void> {
    // In development, just log the SMS instead of sending a real one
    if (appConfig.nodeEnv === 'development' || !appConfig.sparrowToken) {
      this.logger.debug(`[DEV] SMS to ${phone}: ${message}`);
      return;
    }

    try {
      // HTTPS + POST: the API token and OTP must never cross the wire in
      // cleartext or land in intermediary access logs as query params.
      await axios.post(
        'https://api.sparrowsms.com/v2/sms/',
        {
          token: appConfig.sparrowToken,
          from: appConfig.sparrowFrom,
          to: phone,
          text: message,
        },
        { timeout: 10_000 },
      );
    } catch (error) {
      // Never log message content in production — it may contain an OTP.
      this.logger.error(
        `SMS send failed for ${this.maskPhone(phone)}: ${error.message}`,
      );
      // Don't throw — SMS delivery must never break the caller
    }
  }
}
