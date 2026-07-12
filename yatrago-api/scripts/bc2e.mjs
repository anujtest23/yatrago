// Booking ↔ Coupon integration e2e. Seeds a driver/vehicle/ride directly via
// Prisma (bypassing KYC), then exercises the real POST /bookings path with and
// without a coupon: server-computed discount, redemption ledger, and reversal
// on cancel. Regression-covers the booking changes.
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';

const BASE = 'http://localhost:3000/api/v1';
const prisma = new PrismaClient();
const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: Number(process.env.REDIS_PORT || 6379),
  maxRetriesPerRequest: 2,
});

let pass = 0, fail = 0;
const failures = [];
const ok = (n, c, e = '') => {
  if (c) { pass++; console.log(`  ✓ ${n}`); }
  else { fail++; failures.push(`${n}${e ? ` — ${e}` : ''}`); console.log(`  ✗ ${n}${e ? ` — ${e}` : ''}`); }
};

async function clearLimits() {
  for (const p of ['otp_ip:*', 'otp_sends:*', 'otp_fails:*']) {
    const k = await redis.keys(p);
    if (k.length) await redis.del(...k);
  }
}
async function req(method, path, { token, body } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = null;
  try { json = await res.json(); } catch { /* */ }
  return { status: res.status, body: json };
}
const randPhone = () => `+97798${Math.floor(10000000 + Math.random() * 89999999)}`;
async function login(phone) {
  await clearLimits();
  const s = await req('POST', '/auth/send-otp', { body: { phoneNumber: phone } });
  const otp = s.body?.data?.otp;
  return req('POST', '/auth/verify-otp', { body: { phoneNumber: phone, otp } });
}

async function main() {
  console.log('=== Booking × Coupon integration ===');
  // Admin + coupon
  const adminLogin = await login(randPhone());
  await prisma.user.update({ where: { id: adminLogin.body.data.user.id }, data: { role: 'super_admin' } });
  const adminTok = adminLogin.body.data.accessToken;
  const code = `BOOK${Date.now().toString().slice(-6)}`;
  await req('POST', '/admin/coupons', {
    token: adminTok,
    body: { code, discountType: 'percentage', discountValue: 20, minAmount: 100 },
  });

  // Seed a driver + vehicle + published ride directly.
  const driverUser = await prisma.user.create({ data: { phoneNumber: randPhone() } });
  const driver = await prisma.driverProfile.create({
    data: { userId: driverUser.id, verificationStatus: 'approved' },
  });
  const vehicle = await prisma.vehicle.create({
    data: {
      driverId: driver.id, make: 'Toyota', model: 'Hiace', year: 2020,
      plateNumber: `BA${Math.floor(1000 + Math.random() * 8999)}PA`, vehicleType: 'car', totalSeats: 4,
    },
  });
  const ride = await prisma.ride.create({
    data: {
      driverId: driver.id, vehicleId: vehicle.id,
      originName: 'Kathmandu', originLat: 27.7, originLng: 85.3,
      destName: 'Pokhara', destLat: 28.2, destLng: 83.99,
      departureAt: new Date(Date.now() + 86400000),
      totalSeats: 4, availableSeats: 4, pricePerSeat: 500, status: 'published',
    },
  });

  // Passenger books WITH coupon.
  const pTok = (await login(randPhone())).body.data.accessToken;
  const booked = await req('POST', '/bookings', { token: pTok, body: { rideId: ride.id, seatsBooked: 1, couponCode: code } });
  ok('booking with coupon succeeds', booked.status < 300, `status ${booked.status} ${JSON.stringify(booked.body?.message)}`);
  const b = booked.body?.data?.booking;
  ok('discount computed server-side (20% of 500 = 100)', b?.discountAmount === 100, `discount ${b?.discountAmount}`);
  ok('payable reduced to 400', b?.totalAmount === 400, `total ${b?.totalAmount}`);

  const redemption = await prisma.couponRedemption.findFirst({ where: { bookingId: b?.id } });
  ok('redemption ledgered (applied)', redemption?.status === 'applied' && redemption?.discountAmount === 100);

  // Cancel → redemption reversed.
  const cancelled = await req('PATCH', `/bookings/${b.id}/cancel`, { token: pTok, body: { reason: 'changed plans' } });
  ok('cancel booking', cancelled.status < 300, `status ${cancelled.status}`);
  const reversed = await prisma.couponRedemption.findFirst({ where: { bookingId: b.id } });
  ok('redemption reversed on cancel', reversed?.status === 'reversed' && !!reversed?.reversedAt);

  // Second passenger books WITHOUT coupon → full fare, no redemption.
  const p2Tok = (await login(randPhone())).body.data.accessToken;
  const booked2 = await req('POST', '/bookings', { token: p2Tok, body: { rideId: ride.id, seatsBooked: 1 } });
  const b2 = booked2.body?.data?.booking;
  ok('booking without coupon: full fare', b2?.totalAmount === 500 && b2?.discountAmount === 0, `total ${b2?.totalAmount}`);
  const noRedemption = await prisma.couponRedemption.count({ where: { bookingId: b2?.id } });
  ok('no redemption without coupon', noRedemption === 0);

  console.log(`\n──────────\nPASS ${pass}  FAIL ${fail}`);
  if (fail) console.log('FAILURES:\n - ' + failures.join('\n - '));
  await prisma.$disconnect();
  redis.quit();
  process.exit(fail ? 1 : 0);
}
main().catch(async (e) => { console.error(e); await prisma.$disconnect(); redis.quit(); process.exit(2); });
