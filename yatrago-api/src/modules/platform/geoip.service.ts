import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { appConfig } from '../../config/app.config';

export interface GeoLookup {
  country: string | null;
  lat: number | null;
  lng: number | null;
}

/**
 * Optional GeoIP lookups backed by a local MaxMind GeoLite2/GeoIP2 City
 * database (GEOIP_DB_PATH). No network calls — the .mmdb file is read once
 * at boot. When no database is configured every lookup returns null and the
 * anomaly checks that depend on it silently no-op (fail open by design:
 * missing enrichment data must never block logins).
 */
@Injectable()
export class GeoIpService implements OnModuleInit {
  private readonly logger = new Logger(GeoIpService.name);
  private reader:
    | import('maxmind').Reader<import('maxmind').CityResponse>
    | null = null;

  async onModuleInit() {
    if (!appConfig.geoipDbPath) return;
    try {
      const maxmind = await import('maxmind');
      this.reader = await maxmind.open(appConfig.geoipDbPath);
      this.logger.log(`GeoIP database loaded: ${appConfig.geoipDbPath}`);
    } catch (error) {
      // Enrichment only — never fatal, but loud so ops notices.
      this.logger.error(
        `GeoIP database failed to load (${(error as Error).message}); geo anomaly detection disabled.`,
      );
    }
  }

  get enabled(): boolean {
    return this.reader !== null;
  }

  lookup(ip: string): GeoLookup {
    const empty: GeoLookup = { country: null, lat: null, lng: null };
    if (!this.reader || !ip) return empty;
    // Private/loopback addresses have no geo data.
    try {
      const hit = this.reader.get(ip);
      if (!hit) return empty;
      return {
        country: hit.country?.iso_code ?? null,
        lat: hit.location?.latitude ?? null,
        lng: hit.location?.longitude ?? null,
      };
    } catch {
      return empty;
    }
  }
}
