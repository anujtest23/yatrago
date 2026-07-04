import { Injectable } from '@nestjs/common';
import axios from 'axios';
import { appConfig } from '../../config/app.config';

// Central Sparrow SMS sender. All modules (auth OTP, safety SOS,
// booking-event fallbacks) delegate here so the gateway integration
// lives in exactly one place.
@Injectable()
export class SmsService {
  async send(phone: string, message: string): Promise<void> {
    // In development, just log the SMS instead of sending a real one
    if (appConfig.nodeEnv === 'development' || !appConfig.sparrowToken) {
      console.log(`[DEV] SMS to ${phone}: ${message}`);
      return;
    }

    try {
      await axios.get('http://api.sparrowsms.com/v2/sms/', {
        params: {
          token: appConfig.sparrowToken,
          from: appConfig.sparrowFrom,
          to: phone,
          text: message,
        },
      });
    } catch (error) {
      console.error('SMS send failed:', error.message);
      // Don't throw — SMS delivery must never break the caller
    }
  }
}
