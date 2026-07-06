import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';
import { appConfig } from '../../config/app.config';

const API_URL =
  'https://safebrowsing.googleapis.com/v4/threatMatches:find?key=';

/**
 * Google Safe Browsing v4 URL reputation. Optional: without
 * SAFE_BROWSING_API_KEY every check returns false and the heuristic
 * classifier in content-moderation.ts remains the only signal.
 *
 * Used asynchronously after message delivery — chat links are already
 * redacted before the recipient sees them, so this check only decides how
 * hard to fraud-score the SENDER. A slow/failed lookup must never delay
 * or block messaging.
 */
@Injectable()
export class SafeBrowsingService {
  private readonly logger = new Logger(SafeBrowsingService.name);

  get enabled(): boolean {
    return Boolean(appConfig.safeBrowsingKey);
  }

  /** True if ANY of the URLs is a known malware/phishing/unwanted target. */
  async anyMalicious(urls: string[]): Promise<boolean> {
    if (!this.enabled || urls.length === 0) return false;
    try {
      const res = await axios.post<{ matches?: unknown[] }>(
        `${API_URL}${appConfig.safeBrowsingKey}`,
        {
          client: { clientId: 'yatrago', clientVersion: '1.0' },
          threatInfo: {
            threatTypes: [
              'MALWARE',
              'SOCIAL_ENGINEERING',
              'UNWANTED_SOFTWARE',
              'POTENTIALLY_HARMFUL_APPLICATION',
            ],
            platformTypes: ['ANY_PLATFORM'],
            threatEntryTypes: ['URL'],
            threatEntries: urls.slice(0, 20).map((url) => ({ url })),
          },
        },
        { timeout: 10_000 },
      );
      return Array.isArray(res.data?.matches) && res.data.matches.length > 0;
    } catch (error) {
      this.logger.warn(
        `Safe Browsing lookup failed: ${(error as Error).message}`,
      );
      return false;
    }
  }
}
