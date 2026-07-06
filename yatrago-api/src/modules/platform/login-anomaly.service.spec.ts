import { Test } from '@nestjs/testing';
import { LoginAnomalyService } from './login-anomaly.service';
import { GeoIpService } from './geoip.service';
import { TorExitService } from './tor-exit.service';
import { FraudService } from './fraud.service';
import { SmsService } from './sms.service';
import { AuditService } from './audit.service';
import { PrismaService } from '../../database/prisma.service';

const user = { id: 'user-1', phoneNumber: '+9779812345678' };
const ctx = { ip: '203.0.113.7', deviceId: 'device-abc' };

describe('LoginAnomalyService', () => {
  let service: LoginAnomalyService;
  let prisma: { authSession: Record<string, jest.Mock> };
  let geoip: { lookup: jest.Mock; enabled: boolean };
  let tor: { isTorExit: jest.Mock };
  let fraud: { record: jest.Mock };
  let sms: { send: jest.Mock };

  beforeEach(async () => {
    prisma = {
      authSession: {
        findFirst: jest.fn().mockResolvedValue(null),
        findMany: jest.fn().mockResolvedValue([]),
      },
    };
    geoip = {
      lookup: jest
        .fn()
        .mockReturnValue({ country: null, lat: null, lng: null }),
      enabled: false,
    };
    tor = { isTorExit: jest.fn().mockReturnValue(false) };
    fraud = { record: jest.fn() };
    sms = { send: jest.fn() };

    const module = await Test.createTestingModule({
      providers: [
        LoginAnomalyService,
        { provide: PrismaService, useValue: prisma },
        { provide: GeoIpService, useValue: geoip },
        { provide: TorExitService, useValue: tor },
        { provide: FraudService, useValue: fraud },
        { provide: SmsService, useValue: sms },
        { provide: AuditService, useValue: { log: jest.fn() } },
      ],
    }).compile();

    service = module.get(LoginAnomalyService);
  });

  it('hashes device ids server-side (never stores the raw value)', () => {
    const hash = service.hashDeviceId('device-abc');
    expect(hash).toMatch(/^[0-9a-f]{64}$/);
    expect(hash).not.toContain('device-abc');
    expect(service.hashDeviceId(undefined)).toBeNull();
    expect(service.hashDeviceId('   ')).toBeNull();
  });

  it('records a fraud signal for Tor exit logins', async () => {
    tor.isTorExit.mockReturnValue(true);
    await service.assessLogin(user, ctx, false);
    expect(fraud.record).toHaveBeenCalledWith(
      user.id,
      'tor_exit_login',
      15,
      expect.objectContaining({ ip: ctx.ip }),
    );
  });

  it('flags account farming when a device has spawned many accounts', async () => {
    prisma.authSession.findMany.mockResolvedValue([
      { userId: 'a' },
      { userId: 'b' },
      { userId: 'c' },
    ]);
    await service.assessLogin(user, ctx, true);
    expect(fraud.record).toHaveBeenCalledWith(
      user.id,
      'device_multi_account',
      25,
      expect.objectContaining({ otherAccounts: 3 }),
    );
  });

  it('does not farming-check existing users', async () => {
    await service.assessLogin(user, ctx, false);
    expect(prisma.authSession.findMany).not.toHaveBeenCalled();
  });

  it('detects a country change and warns the owner by SMS', async () => {
    geoip.lookup.mockReturnValue({ country: 'IN', lat: 28.6, lng: 77.2 });
    prisma.authSession.findFirst.mockResolvedValue({
      country: 'NP',
      geoLat: 27.7,
      geoLng: 85.3,
      lastUsedAt: new Date(Date.now() - 2 * 3600_000),
    });
    await service.assessLogin(user, ctx, false);
    expect(fraud.record).toHaveBeenCalledWith(
      user.id,
      'geo_country_change',
      20,
      { from: 'NP', to: 'IN' },
    );
    expect(sms.send).toHaveBeenCalledTimes(1);
  });

  it('detects impossible travel (too far, too fast)', async () => {
    // Kathmandu -> London (~7300 km) in 30 minutes.
    geoip.lookup.mockReturnValue({ country: 'GB', lat: 51.5, lng: -0.12 });
    prisma.authSession.findFirst.mockResolvedValue({
      country: 'GB', // same country so only the speed rule can fire
      geoLat: 27.7,
      geoLng: 85.3,
      lastUsedAt: new Date(Date.now() - 30 * 60_000),
    });
    await service.assessLogin(user, ctx, false);
    expect(fraud.record).toHaveBeenCalledWith(
      user.id,
      'geo_impossible_travel',
      30,
      expect.objectContaining({ km: expect.any(Number) }),
    );
  });

  it('stays quiet for plausible travel', async () => {
    // Kathmandu -> Pokhara (~145 km) in 4 hours.
    geoip.lookup.mockReturnValue({ country: 'NP', lat: 28.2, lng: 83.98 });
    prisma.authSession.findFirst.mockResolvedValue({
      country: 'NP',
      geoLat: 27.7,
      geoLng: 85.3,
      lastUsedAt: new Date(Date.now() - 4 * 3600_000),
    });
    await service.assessLogin(user, ctx, false);
    expect(fraud.record).not.toHaveBeenCalled();
    expect(sms.send).not.toHaveBeenCalled();
  });

  it('never throws out of assessLogin (enrichment must not block logins)', async () => {
    geoip.lookup.mockReturnValue({ country: 'NP', lat: 27.7, lng: 85.3 });
    prisma.authSession.findFirst.mockRejectedValue(new Error('db down'));
    await expect(service.assessLogin(user, ctx, false)).resolves.toEqual({
      geo: { country: 'NP', lat: 27.7, lng: 85.3 },
      deviceIdHash: expect.stringMatching(/^[0-9a-f]{64}$/),
    });
  });
});
