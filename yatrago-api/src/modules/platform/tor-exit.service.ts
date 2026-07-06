import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import axios from 'axios';
import { appConfig } from '../../config/app.config';

const TOR_EXIT_LIST_URL = 'https://check.torproject.org/torbulkexitlist';
const REFRESH_INTERVAL_MS = 12 * 60 * 60 * 1000; // 12 hours

/**
 * Maintains an in-memory set of Tor exit-node IPs, refreshed in the
 * background. Logins from an exit are a fraud signal (anonymity network →
 * common account-farming / ban-evasion vector), NOT a block: legitimate
 * privacy-conscious users still get in, they just start with a score.
 *
 * Failure-tolerant by design: if the list can't be fetched, checks return
 * false and the app keeps working.
 */
@Injectable()
export class TorExitService implements OnModuleInit {
  private readonly logger = new Logger(TorExitService.name);
  private exits = new Set<string>();
  private timer: NodeJS.Timeout | null = null;

  onModuleInit() {
    if (!appConfig.torCheckEnabled) return;
    // Fire-and-forget: never block boot on an external fetch.
    void this.refresh();
    this.timer = setInterval(() => void this.refresh(), REFRESH_INTERVAL_MS);
    this.timer.unref();
  }

  private async refresh(): Promise<void> {
    try {
      const res = await axios.get<string>(TOR_EXIT_LIST_URL, {
        timeout: 15_000,
        responseType: 'text',
        maxContentLength: 5 * 1024 * 1024,
      });
      const ips = res.data
        .split('\n')
        .map((l) => l.trim())
        .filter((l) => l && !l.startsWith('#'));
      if (ips.length > 0) {
        this.exits = new Set(ips);
        this.logger.log(`Tor exit list refreshed: ${ips.length} nodes`);
      }
    } catch (error) {
      this.logger.warn(
        `Tor exit list refresh failed: ${(error as Error).message}`,
      );
    }
  }

  isTorExit(ip: string): boolean {
    return this.exits.has(ip);
  }
}
