// End-to-end validation of the Account Deletion + Reactivation lifecycle.
// Drives the REAL running API over HTTP; uses Prisma directly only for setup,
// back-dating (to simulate the 30-day grace elapsing) and DB assertions; runs
// the REAL cron via scripts/run-cron.ts. Requires NODE_ENV=development so the
// send-otp/request-otp responses include the OTP.
import 'dotenv/config';
import { execSync } from 'node:child_process';
import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';

const BASE = 'http://localhost:3000/api/v1';
const prisma = new PrismaClient();
const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: Number(process.env.REDIS_PORT || 6379),
  password: process.env.REDIS_PASSWORD || undefined,
  maxRetriesPerRequest: 2,
});

// The API enforces OTP_SENDS_PER_IP (10/hr) and PER_PHONE (3/10min). This
// suite legitimately logs in many test users from one host, so clear those
// throttle counters between logins. Only the send/IP windows are cleared —
// the OTPs themselves (otp:*, action_otp:*) and the deletion-request limiter
// under test are left untouched.
async function clearLimits() {
  for (const pat of ['otp_ip:*', 'otp_sends:*', 'otp_fails:*']) {
    const keys = await redis.keys(pat);
    if (keys.length) await redis.del(...keys);
  }
}

let pass = 0;
let fail = 0;
const failures = [];
function ok(name, cond, extra = '') {
  if (cond) {
    pass++;
    console.log(`  ✓ ${name}`);
  } else {
    fail++;
    failures.push(name + (extra ? ` — ${extra}` : ''));
    console.log(`  ✗ ${name}${extra ? ` — ${extra}` : ''}`);
  }
}
function section(t) {
  console.log(`\n=== ${t} ===`);
}

async function req(method, path, { token, body } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = null;
  try {
    json = await res.json();
  } catch {
    /* empty */
  }
  return { status: res.status, body: json };
}

function randPhone() {
  // Regex: /^\+9779[6-8]\d{8}$/  → "+97798" + 8 digits.
  const rest = String(Math.floor(10000000 + Math.random() * 89999999)); // 8 digits
  return `+97798${rest}`;
}

// send-otp → verify-otp. Returns the verify response ({status, body}).
async function login(phone) {
  await clearLimits();
  const s = await req('POST', '/auth/send-otp', { body: { phoneNumber: phone } });
  const otp = s.body?.data?.otp;
  if (!otp) return { status: s.status, body: s.body, otp: null };
  const v = await req('POST', '/auth/verify-otp', {
    body: { phoneNumber: phone, otp },
  });
  return { ...v, otp };
}

async function main() {
  // Preflight
  const health = await fetch(BASE.replace('/api/v1', '') + '/api/v1/auth/send-otp', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phoneNumber: randPhone() }),
  }).then((r) => r.status).catch(() => 0);
  if (!health) {
    console.error('API not reachable at ' + BASE);
    process.exit(2);
  }

  // ─── 1. ACCOUNT DELETION ──────────────────────────────────────
  section('1. Account Deletion');
  const phoneA = randPhone();
  const a = await login(phoneA);
  ok('new user login issues tokens', !!a.body?.data?.accessToken);
  const tokenA = a.body?.data?.accessToken;
  const userAId = a.body?.data?.user?.id;

  const reqOtp = await req('POST', '/users/me/deletion/request-otp', { token: tokenA });
  ok('request-otp returns 200/201', reqOtp.status < 300, `status ${reqOtp.status}`);
  const delOtp = reqOtp.body?.data?.otp;
  ok('deletion OTP sent (dev echo present)', !!delOtp);

  const wrong = await req('POST', '/users/me/deletion/confirm', {
    token: tokenA,
    body: { otp: delOtp === '000000' ? '111111' : '000000' },
  });
  ok('incorrect OTP rejected (400)', wrong.status === 400, `status ${wrong.status}`);
  let uA = await prisma.user.findUnique({ where: { id: userAId } });
  ok('account still active after wrong OTP', uA.accountStatus === 'active');

  const confirm = await req('POST', '/users/me/deletion/confirm', {
    token: tokenA,
    body: { otp: delOtp },
  });
  ok('correct OTP accepted', confirm.status < 300, `status ${confirm.status}`);
  ok('user receives confirmation message', typeof confirm.body?.data?.message === 'string');
  uA = await prisma.user.findUnique({ where: { id: userAId } });
  ok('account is PENDING_DELETION', uA.accountStatus === 'pending_deletion');
  ok('deletionRequestedAt set', !!uA.deletionRequestedAt);
  ok('isActive stays true (browse allowed)', uA.isActive === true);
  const auditReq = await prisma.auditLog.findFirst({
    where: { actorId: userAId, action: 'account.deletion_requested' },
  });
  ok('audit log: deletion_requested created', !!auditReq);

  // ─── 2. PENDING DELETION RESTRICTIONS ─────────────────────────
  section('2. Pending Deletion');
  const reLogin = await login(phoneA);
  ok('pending user can still log in', !!reLogin.body?.data?.accessToken, `status ${reLogin.status}`);
  const tokenAp = reLogin.body?.data?.accessToken || tokenA;

  const me = await req('GET', '/auth/me', { token: tokenAp });
  ok('can browse: GET /auth/me works', me.status === 200);
  ok('/auth/me exposes accountStatus=pending_deletion', me.body?.data?.accountStatus === 'pending_deletion');
  const wallet = await req('GET', '/wallet', { token: tokenAp });
  ok('can browse: GET /wallet works', wallet.status === 200, `status ${wallet.status}`);

  const book = await req('POST', '/bookings', { token: tokenAp, body: { rideId: '00000000-0000-0000-0000-000000000000', seats: 1 } });
  ok('cannot book rides (403)', book.status === 403, `status ${book.status}`);
  const post = await req('POST', '/trips', { token: tokenAp, body: {} });
  ok('cannot post rides (403)', post.status === 403, `status ${post.status}`);
  const accept = await req('PATCH', '/bookings/00000000-0000-0000-0000-000000000000/accept', { token: tokenAp });
  ok('cannot accept rides (403)', accept.status === 403, `status ${accept.status}`);
  const topup = await req('POST', '/wallet/payments/esewa/initiate', { token: tokenAp, body: { amount: 500 } });
  ok('cannot initiate top-up (403)', topup.status === 403, `status ${topup.status}`);
  const payout = await req('POST', '/drivers/payouts', { token: tokenAp, body: { amount: 500, method: 'esewa' } });
  ok('cannot request withdrawal (403)', payout.status === 403, `status ${payout.status}`);
  ok('403 carries pending-deletion message', /pending deletion/i.test(book.body?.message || ''), book.body?.message);

  // ─── 3. CANCEL DELETION ───────────────────────────────────────
  section('3. Cancel Deletion');
  const cancel = await req('POST', '/users/me/deletion/cancel', { token: tokenAp });
  ok('cancel returns 200', cancel.status < 300, `status ${cancel.status}`);
  uA = await prisma.user.findUnique({ where: { id: userAId } });
  ok('account back to ACTIVE', uA.accountStatus === 'active');
  ok('deletionRequestedAt cleared', uA.deletionRequestedAt === null);
  const bookAfter = await req('POST', '/bookings', { token: tokenAp, body: { rideId: '00000000-0000-0000-0000-000000000000', seats: 1 } });
  ok('restrictions removed (book no longer 403)', bookAfter.status !== 403, `status ${bookAfter.status}`);
  const auditCancel = await prisma.auditLog.findFirst({
    where: { actorId: userAId, action: 'account.deletion_cancelled' },
  });
  ok('audit log: deletion_cancelled created', !!auditCancel);
  const cancelAgain = await req('POST', '/users/me/deletion/cancel', { token: tokenAp });
  ok('cancel with no pending deletion rejected (400)', cancelAgain.status === 400, `status ${cancelAgain.status}`);

  // ─── 4. AUTOMATIC DELETION (cron, 30-day grace elapsed) ───────
  section('4. Automatic Deletion (cron)');
  // Put A back into pending and back-date beyond the 30-day cutoff.
  const r2 = await req('POST', '/users/me/deletion/request-otp', { token: tokenAp });
  await req('POST', '/users/me/deletion/confirm', { token: tokenAp, body: { otp: r2.body?.data?.otp } });
  await prisma.user.update({
    where: { id: userAId },
    data: { deletionRequestedAt: new Date(Date.now() - 31 * 24 * 3600 * 1000) },
  });
  // Also create a still-fresh pending user that must NOT be finalized.
  const phoneFresh = randPhone();
  const fresh = await login(phoneFresh);
  const freshId = fresh.body?.data?.user?.id;
  const rf = await req('POST', '/users/me/deletion/request-otp', { token: fresh.body.data.accessToken });
  await req('POST', '/users/me/deletion/confirm', { token: fresh.body.data.accessToken, body: { otp: rf.body?.data?.otp } });

  let cronOut = '';
  try {
    cronOut = execSync('npx ts-node -T scripts/run-cron.ts', {
      cwd: process.cwd(), encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (e) {
    cronOut = (e.stdout || '') + (e.stderr || '');
  }
  ok('cron job ran without failure', /CRON_DONE/.test(cronOut), cronOut.slice(-200));
  uA = await prisma.user.findUnique({ where: { id: userAId } });
  ok('expired account status = DELETED', uA.accountStatus === 'deleted');
  ok('phone number retained (reserved for reactivation)', uA.phoneNumber === phoneA);
  ok('personal data retained (not anonymized)', uA.phoneNumber === phoneA && !/^deleted-/.test(uA.phoneNumber));
  ok('sessions revoked on finalize', (await prisma.authSession.count({ where: { userId: userAId } })) === 0);
  const freshU = await prisma.user.findUnique({ where: { id: freshId } });
  ok('fresh pending account NOT finalized', freshU.accountStatus === 'pending_deletion');

  // Deleted user's old access token must be rejected by JwtStrategy.
  const oldTok = await req('GET', '/auth/me', { token: tokenAp });
  ok('deleted user old token rejected (401)', oldTok.status === 401, `status ${oldTok.status}`);

  // ─── 5. REACTIVATION REQUEST ──────────────────────────────────
  section('5. Reactivation Request');
  const relogin1 = await login(phoneA);
  ok('deleted phone login blocked (403)', relogin1.status === 403, `status ${relogin1.status}`);
  ok('block message mentions review', /review|reactivat/i.test(relogin1.body?.message || ''), relogin1.body?.message);
  let rr = await prisma.reactivationRequest.findMany({ where: { previousUserId: userAId } });
  ok('reactivation request created', rr.length === 1);
  ok('request status pending', rr[0]?.status === 'pending');
  const auditRr = await prisma.auditLog.findFirst({ where: { action: 'account.reactivation_requested', targetId: userAId } });
  ok('audit log: reactivation_requested created', !!auditRr);

  const relogin2 = await login(phoneA);
  ok('second attempt still blocked (403)', relogin2.status === 403);
  rr = await prisma.reactivationRequest.findMany({ where: { previousUserId: userAId } });
  ok('duplicate requests NOT spammed (still 1 pending)', rr.filter((x) => x.status === 'pending').length === 1);

  // Admin (super_admin) — real login + role elevation.
  const adminPhone = randPhone();
  const adminLogin = await login(adminPhone);
  const adminId = adminLogin.body?.data?.user?.id;
  await prisma.user.update({ where: { id: adminId }, data: { role: 'super_admin' } });
  const adminTok = adminLogin.body?.data?.accessToken;

  const list = await req('GET', '/admin/reactivations?status=pending', { token: adminTok });
  ok('admin sees pending reactivation requests', list.status === 200 && Array.isArray(list.body?.data) && list.body.data.some((x) => x.previousUserId === userAId), `status ${list.status}`);

  // ─── 6. ADMIN APPROVAL ────────────────────────────────────────
  section('6. Admin Approval');
  const reqId = rr.find((x) => x.status === 'pending').id;
  const walletBefore = await prisma.wallet.findUnique({ where: { userId: userAId } });
  const approve = await req('PATCH', `/admin/reactivations/${reqId}/approve`, { token: adminTok });
  ok('approve returns 200', approve.status < 300, `status ${approve.status}`);
  uA = await prisma.user.findUnique({ where: { id: userAId } });
  ok('original account restored to ACTIVE', uA.accountStatus === 'active' && uA.isActive === true);
  ok('same user id preserved (history/wallet intact)', uA.id === userAId);
  const walletAfter = await prisma.wallet.findUnique({ where: { userId: userAId } });
  ok('wallet preserved across reactivation', (!!walletBefore) === (!!walletAfter));
  const notif = await prisma.notification.findFirst({ where: { userId: userAId, title: 'Account Reactivated' } });
  ok('user notified of reactivation', !!notif);
  const auditAppr = await prisma.auditLog.findFirst({ where: { action: 'reactivation_approved', targetId: reqId } });
  ok('audit log: reactivation_approved created', !!auditAppr);
  const loginRestored = await login(phoneA);
  ok('restored user can log in again', !!loginRestored.body?.data?.accessToken, `status ${loginRestored.status}`);

  // ─── 7. ADMIN REJECTION ───────────────────────────────────────
  section('7. Admin Rejection');
  // New user B, delete + finalize + relogin to raise a request, then reject.
  const phoneB = randPhone();
  const b = await login(phoneB);
  const userBId = b.body?.data?.user?.id;
  const rb = await req('POST', '/users/me/deletion/request-otp', { token: b.body.data.accessToken });
  await req('POST', '/users/me/deletion/confirm', { token: b.body.data.accessToken, body: { otp: rb.body?.data?.otp } });
  await prisma.user.update({ where: { id: userBId }, data: { deletionRequestedAt: new Date(Date.now() - 31 * 24 * 3600 * 1000) } });
  try { execSync('npx ts-node -T scripts/run-cron.ts', { cwd: process.cwd(), stdio: 'ignore' }); } catch { /* */ }
  await login(phoneB); // raises reactivation request
  const rbReq = await prisma.reactivationRequest.findFirst({ where: { previousUserId: userBId, status: 'pending' } });
  const reject = await req('PATCH', `/admin/reactivations/${rbReq.id}/reject`, { token: adminTok, body: { reason: 'Identity could not be verified' } });
  ok('reject returns 200', reject.status < 300, `status ${reject.status}`);
  const rbAfter = await prisma.reactivationRequest.findUnique({ where: { id: rbReq.id } });
  ok('request marked rejected', rbAfter.status === 'rejected');
  ok('rejection reason stored', rbAfter.rejectionReason === 'Identity could not be verified');
  const uB = await prisma.user.findUnique({ where: { id: userBId } });
  ok('account remains DELETED after rejection', uB.accountStatus === 'deleted');
  const loginB = await login(phoneB);
  ok('user cannot bypass — login still blocked (403)', loginB.status === 403, `status ${loginB.status}`);
  const auditRej = await prisma.auditLog.findFirst({ where: { action: 'reactivation_rejected', targetId: rbReq.id } });
  ok('audit log: reactivation_rejected created', !!auditRej);

  // ─── 8. SECURITY ──────────────────────────────────────────────
  section('8. Security');
  const noAuth = await req('POST', '/users/me/deletion/request-otp');
  ok('JWT required: no token → 401', noAuth.status === 401, `status ${noAuth.status}`);
  const badAuth = await req('GET', '/auth/me', { token: 'garbage.token.here' });
  ok('invalid token rejected → 401', badAuth.status === 401, `status ${badAuth.status}`);

  // Non-admin hitting admin surface → 403 (privilege escalation blocked).
  const phoneC = randPhone();
  const c = await login(phoneC);
  const escal = await req('GET', '/admin/reactivations', { token: c.body.data.accessToken });
  ok('non-admin blocked from admin endpoint (403)', escal.status === 403, `status ${escal.status}`);
  const escal2 = await req('PATCH', `/admin/reactivations/${reqId}/approve`, { token: c.body.data.accessToken });
  ok('non-admin cannot approve reactivations (403)', escal2.status === 403, `status ${escal2.status}`);

  // OTP rate limit: request-otp shares the per-phone send window (max 5).
  const phoneD = randPhone();
  const d = await login(phoneD);
  let limited = false;
  for (let i = 0; i < 8; i++) {
    const r = await req('POST', '/users/me/deletion/request-otp', { token: d.body.data.accessToken });
    if (r.status === 400 && /too many/i.test(r.body?.message || '')) { limited = true; break; }
  }
  ok('OTP rate limiting enforced', limited);

  // Replay: consumed OTP cannot be reused (single-use).
  const phoneE = randPhone();
  const e = await login(phoneE);
  const re = await req('POST', '/users/me/deletion/request-otp', { token: e.body.data.accessToken });
  const eOtp = re.body?.data?.otp;
  await req('POST', '/users/me/deletion/confirm', { token: e.body.data.accessToken, body: { otp: eOtp } });
  // cancel so we can attempt replay on confirm again
  await req('POST', '/users/me/deletion/cancel', { token: e.body.data.accessToken });
  const replay = await req('POST', '/users/me/deletion/confirm', { token: e.body.data.accessToken, body: { otp: eOtp } });
  ok('OTP replay rejected (single-use, 400)', replay.status === 400, `status ${replay.status}`);

  // IDOR: deletion endpoints are self-scoped (act on JWT subject only, no id
  // param). Confirm E's action never touched D.
  const dStill = await prisma.user.findUnique({ where: { id: d.body.data.user.id } });
  ok('IDOR N/A — endpoints self-scoped (other user unaffected)', dStill.accountStatus === 'active');

  // Deleted user cannot reach a protected endpoint with a live token. Use a
  // fresh user: log in (real session), then finalize-delete via cron, then
  // reuse that still-live JWT — JwtStrategy must now reject it. (phoneA can't
  // be reused here: it was reactivated in §6 and is active again.)
  const phoneF = randPhone();
  const f = await login(phoneF);
  const fTok = f.body.data.accessToken;
  const rF = await req('POST', '/users/me/deletion/request-otp', { token: fTok });
  await req('POST', '/users/me/deletion/confirm', { token: fTok, body: { otp: rF.body?.data?.otp } });
  await prisma.user.update({
    where: { id: f.body.data.user.id },
    data: { deletionRequestedAt: new Date(Date.now() - 31 * 24 * 3600 * 1000) },
  });
  try { execSync('npx ts-node -T scripts/run-cron.ts', { cwd: process.cwd(), stdio: 'ignore' }); } catch { /* */ }
  const delTokMe = await req('GET', '/wallet', { token: fTok });
  ok('deleted user cannot access protected endpoint', delTokMe.status === 401, `status ${delTokMe.status}`);

  // ─── SUMMARY ──────────────────────────────────────────────────
  console.log(`\n──────────────────────────────`);
  console.log(`PASS ${pass}  FAIL ${fail}`);
  if (fail) console.log('FAILURES:\n - ' + failures.join('\n - '));
  await prisma.$disconnect();
  redis.quit();
  process.exit(fail ? 1 : 0);
}

main().catch(async (e) => {
  console.error(e);
  await prisma.$disconnect();
  redis.quit();
  process.exit(2);
});
