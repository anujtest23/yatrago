// Ride + Chat end-to-end. Covers ride creation (real POST /trips by an
// approved driver), booking, acceptance, chat gating (no chat before accept),
// message send, read receipts, unread count, and unauthorized chat access.
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
  return req('POST', '/auth/verify-otp', { body: { phoneNumber: phone, otp: s.body?.data?.otp } });
}

async function main() {
  console.log('=== Ride + Chat ===');

  // Approved driver + active vehicle (seeded), then driver logs in for a token.
  const driverPhone = randPhone();
  const driverUser = await prisma.user.create({ data: { phoneNumber: driverPhone, activeMode: 'driver' } });
  const driver = await prisma.driverProfile.create({ data: { userId: driverUser.id, verificationStatus: 'approved' } });
  // Posting a ride requires the driver to hold the minimum wallet balance.
  await prisma.wallet.create({ data: { userId: driverUser.id, balance: 1000 } });
  const vehicle = await prisma.vehicle.create({
    data: {
      driverId: driver.id, make: 'Hyundai', model: 'i20', year: 2021,
      plateNumber: `BA${Math.floor(1000 + Math.random() * 8999)}CHA`, vehicleType: 'car', totalSeats: 4, isActive: true,
    },
  });
  const driverTok = (await login(driverPhone)).body.data.accessToken;

  // ── Ride creation (real endpoint) ──
  const created = await req('POST', '/trips', {
    token: driverTok,
    body: {
      vehicleId: vehicle.id,
      originName: 'Kathmandu', originLat: 27.7, originLng: 85.3,
      destName: 'Pokhara', destLat: 28.2, destLng: 83.99,
      departureAt: new Date(Date.now() + 86400000).toISOString(),
      totalSeats: 3, pricePerSeat: 800,
    },
  });
  ok('approved driver creates a ride', created.status < 300, `status ${created.status} ${JSON.stringify(created.body?.message)}`);
  const rideId = created.body?.data?.trip?.id ?? created.body?.data?.id;
  ok('ride id returned', !!rideId);

  // Non-approved driver cannot post: a plain passenger hitting /trips → 403.
  const paxTok0 = (await login(randPhone())).body.data.accessToken;
  const forbiddenPost = await req('POST', '/trips', {
    token: paxTok0,
    body: {
      vehicleId: vehicle.id, originName: 'A', originLat: 27, originLng: 85,
      destName: 'B', destLat: 28, destLng: 84,
      departureAt: new Date(Date.now() + 86400000).toISOString(), totalSeats: 2, pricePerSeat: 100,
    },
  });
  ok('non-driver cannot create a ride (403)', forbiddenPost.status === 403, `status ${forbiddenPost.status}`);

  // ── Booking ──
  const paxPhone = randPhone();
  const paxTok = (await login(paxPhone)).body.data.accessToken;
  const paxId = (await req('GET', '/auth/me', { token: paxTok })).body.data.id;
  const booked = await req('POST', '/bookings', { token: paxTok, body: { rideId, seatsBooked: 1 } });
  ok('passenger books the ride', booked.status < 300, `status ${booked.status}`);
  const bookingId = booked.body.data.booking.id;

  // ── Chat is gated until acceptance ──
  const chatBefore = await req('GET', `/chat/${bookingId}/messages`, { token: paxTok });
  ok('no chat before acceptance (403)', chatBefore.status === 403, `status ${chatBefore.status}`);
  const sendBefore = await req('POST', `/chat/${bookingId}/messages`, { token: paxTok, body: { content: 'hi early' } });
  ok('cannot send before acceptance (403)', sendBefore.status === 403, `status ${sendBefore.status}`);

  // ── Driver accepts (ride acceptance) → chat opens ──
  const accepted = await req('PATCH', `/bookings/${bookingId}/accept`, { token: driverTok });
  ok('driver accepts booking', accepted.status < 300, `status ${accepted.status}`);

  // ── Message send + delivery ──
  const sent = await req('POST', `/chat/${bookingId}/messages`, { token: paxTok, body: { content: 'Hello, where do I meet you?' } });
  ok('passenger sends a message', sent.status < 300, `status ${sent.status}`);

  // Unread must be checked BEFORE the driver opens the thread (opening or an
  // explicit read clears it).
  const unreadBefore = await req('GET', '/chat/unread-count', { token: driverTok });
  const ub = unreadBefore.body?.data?.unreadCount ?? unreadBefore.body?.data?.count;
  ok('driver has an unread message', (ub ?? 0) >= 1, `unread ${JSON.stringify(unreadBefore.body?.data)}`);

  const driverView = await req('GET', `/chat/${bookingId}/messages`, { token: driverTok });
  const msgs = driverView.body?.data?.messages ?? driverView.body?.data;
  ok('driver sees the message', Array.isArray(msgs) && msgs.some((m) => m.content === 'Hello, where do I meet you?'), JSON.stringify(driverView.body?.data)?.slice(0, 120));

  const read = await req('POST', `/chat/${bookingId}/read`, { token: driverTok });
  ok('driver marks conversation read', read.status < 300, `status ${read.status}`);

  const unreadAfter = await req('GET', '/chat/unread-count', { token: driverTok });
  const ua = unreadAfter.body?.data?.unreadCount ?? unreadAfter.body?.data?.count;
  ok('unread count clears after read', (ua ?? 0) === 0, `unread ${JSON.stringify(unreadAfter.body?.data)}`);

  const paxView = await req('GET', `/chat/${bookingId}/messages`, { token: paxTok });
  const paxMsgs = paxView.body?.data?.messages ?? paxView.body?.data;
  ok('read receipt reflected (message isRead)', paxMsgs.find((m) => m.content.startsWith('Hello'))?.isRead === true);

  // ── Conversations list ──
  const convos = await req('GET', '/chat/conversations', { token: driverTok });
  const list = convos.body?.data?.conversations ?? convos.body?.data;
  ok('conversation appears in driver list', Array.isArray(list) && list.some((c) => c.bookingId === bookingId || c.id === bookingId), JSON.stringify(list)?.slice(0, 120));

  // ── Unauthorized chat access (IDOR) ──
  const strangerTok = (await login(randPhone())).body.data.accessToken;
  const idor = await req('GET', `/chat/${bookingId}/messages`, { token: strangerTok });
  ok('stranger cannot read the conversation (403)', idor.status === 403, `status ${idor.status}`);
  const idorSend = await req('POST', `/chat/${bookingId}/messages`, { token: strangerTok, body: { content: 'intrusion' } });
  ok('stranger cannot post to the conversation (403)', idorSend.status === 403, `status ${idorSend.status}`);

  void paxId;
  console.log(`\n──────────\nPASS ${pass}  FAIL ${fail}`);
  if (fail) console.log('FAILURES:\n - ' + failures.join('\n - '));
  await prisma.$disconnect();
  redis.quit();
  process.exit(fail ? 1 : 0);
}
main().catch(async (e) => { console.error(e); await prisma.$disconnect(); redis.quit(); process.exit(2); });
