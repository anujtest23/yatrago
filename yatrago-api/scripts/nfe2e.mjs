// End-to-end validation for the new production features: Coupons, Emergency
// Contacts, Contact Us, Report Issue, Notification Preferences, Privacy
// Settings. Drives the real API over HTTP; Prisma only for admin role
// elevation, limit-seeding and assertions. Requires NODE_ENV=development.
import 'dotenv/config';
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
const section = (t) => console.log(`\n=== ${t} ===`);

async function clearLimits() {
  for (const pat of ['otp_ip:*', 'otp_sends:*', 'otp_fails:*']) {
    const keys = await redis.keys(pat);
    if (keys.length) await redis.del(...keys);
  }
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
    /* */
  }
  return { status: res.status, body: json };
}

function randPhone() {
  const rest = String(Math.floor(10000000 + Math.random() * 89999999));
  return `+97798${rest}`;
}

async function login(phone) {
  await clearLimits();
  const s = await req('POST', '/auth/send-otp', { body: { phoneNumber: phone } });
  const otp = s.body?.data?.otp;
  if (!otp) return { status: s.status, body: s.body };
  return req('POST', '/auth/verify-otp', { body: { phoneNumber: phone, otp } });
}

async function makeAdmin() {
  const login1 = await login(randPhone());
  const id = login1.body.data.user.id;
  await prisma.user.update({ where: { id }, data: { role: 'super_admin' } });
  return login1.body.data.accessToken;
}

async function main() {
  const adminTok = await makeAdmin();

  // ─── COUPONS ──────────────────────────────────────────────────
  section('Coupons');
  const uniq = Date.now().toString().slice(-6);
  const mk = (body) =>
    req('POST', '/admin/coupons', { token: adminTok, body });

  const pct = await mk({
    code: `PCT${uniq}`,
    discountType: 'percentage',
    discountValue: 10,
    minAmount: 200,
  });
  ok('admin creates percentage coupon', pct.status < 300, `status ${pct.status}`);

  const capped = await mk({
    code: `CAP${uniq}`,
    discountType: 'percentage',
    discountValue: 50,
    maxDiscount: 100,
  });
  const driverOnly = await mk({
    code: `DRV${uniq}`,
    discountType: 'fixed',
    discountValue: 50,
    audience: 'driver',
  });
  const expired = await mk({
    code: `EXP${uniq}`,
    discountType: 'fixed',
    discountValue: 50,
    validUntil: new Date(Date.now() - 86400000).toISOString(),
  });
  ok('admin creates capped/driver/expired coupons',
    capped.status < 300 && driverOnly.status < 300 && expired.status < 300);

  const dupe = await mk({
    code: `PCT${uniq}`,
    discountType: 'fixed',
    discountValue: 5,
  });
  ok('duplicate coupon code rejected (400)', dupe.status === 400, `status ${dupe.status}`);

  const badPct = await mk({
    code: `BAD${uniq}`,
    discountType: 'percentage',
    discountValue: 150,
  });
  ok('percentage > 100 rejected (400)', badPct.status === 400, `status ${badPct.status}`);

  // A passenger validates coupons (server computes the discount).
  const uTok = (await login(randPhone())).body.data.accessToken;
  const v = (code, amount) =>
    req('POST', '/coupons/validate', { token: uTok, body: { code, amount } });

  const vp = await v(`PCT${uniq}`, 500);
  ok('percentage discount computed server-side',
    vp.status < 300 && vp.body.data.discountAmount === 50 && vp.body.data.finalAmount === 450,
    JSON.stringify(vp.body?.data));

  const vc = await v(`CAP${uniq}`, 1000);
  ok('percentage cap applied', vc.status < 300 && vc.body.data.discountAmount === 100,
    JSON.stringify(vc.body?.data));

  const vmin = await v(`PCT${uniq}`, 100);
  ok('below-minimum rejected', vmin.status === 400 && /minimum/i.test(vmin.body?.message || ''),
    vmin.body?.message);

  const vexp = await v(`EXP${uniq}`, 500);
  ok('expired coupon rejected', vexp.status === 400 && /expired/i.test(vexp.body?.message || ''),
    vexp.body?.message);

  const vdrv = await v(`DRV${uniq}`, 500);
  ok('audience mismatch rejected (passenger vs driver-only)',
    vdrv.status === 400 && /driver/i.test(vdrv.body?.message || ''), vdrv.body?.message);

  const vbad = await v(`NOPE${uniq}`, 500);
  ok('unknown coupon rejected', vbad.status === 400);

  // Per-user limit: seed one applied redemption then expect the cap to bite.
  const limited = await mk({
    code: `LIM${uniq}`,
    discountType: 'fixed',
    discountValue: 20,
    perUserLimit: 1,
  });
  const limitedId = limited.body.data.id;
  const uId = (await req('GET', '/auth/me', { token: uTok })).body.data.id;
  await prisma.couponRedemption.create({
    data: { couponId: limitedId, userId: uId, discountAmount: 20, status: 'applied' },
  });
  const vlim = await v(`LIM${uniq}`, 500);
  ok('per-user limit enforced', vlim.status === 400 && /maximum number of times/i.test(vlim.body?.message || ''),
    vlim.body?.message);

  const list = await req('GET', '/admin/coupons', { token: adminTok });
  ok('admin lists coupons', list.status === 200 && Array.isArray(list.body.data));

  const deact = await req('DELETE', `/admin/coupons/${limitedId}`, { token: adminTok });
  ok('admin deactivates coupon (soft)', deact.status < 300);
  const vdeact = await v(`LIM${uniq}`, 500);
  ok('deactivated coupon no longer valid', vdeact.status === 400 && /invalid or inactive/i.test(vdeact.body?.message || ''));

  const escalate = await req('POST', '/admin/coupons', {
    token: uTok,
    body: { code: `HACK${uniq}`, discountType: 'fixed', discountValue: 1 },
  });
  ok('non-admin cannot create coupons (403)', escalate.status === 403, `status ${escalate.status}`);

  // ─── EMERGENCY CONTACTS ───────────────────────────────────────
  section('Emergency Contacts');
  const ecTok = (await login(randPhone())).body.data.accessToken;
  const ec = (m, p, body) =>
    req(m, `/users/me/emergency-contacts${p}`, { token: ecTok, body });

  const c1 = await ec('POST', '', { fullName: 'Ama', phoneNumber: '+9779800000001', relationship: 'Mother' });
  const c2 = await ec('POST', '', { fullName: 'Bhai', phoneNumber: '9800000002' });
  ok('add two contacts', c1.status < 300 && c2.status < 300);

  const dup = await ec('POST', '', { fullName: 'Dup', phoneNumber: '9800000001' });
  ok('duplicate phone rejected', dup.status === 400 && /already a contact/i.test(dup.body?.message || ''),
    dup.body?.message);

  const badPhone = await ec('POST', '', { fullName: 'X', phoneNumber: 'not-a-number' });
  ok('invalid phone rejected (400)', badPhone.status === 400);

  await ec('POST', '', { fullName: 'C3', phoneNumber: '9800000003' });
  const c4 = await ec('POST', '', { fullName: 'C4', phoneNumber: '9800000004' });
  ok('max 3 contacts enforced', c4.status === 400 && /up to 3/i.test(c4.body?.message || ''),
    c4.body?.message);

  const listed = await ec('GET', '');
  const contacts = listed.body.data.contacts;
  ok('list returns contacts in order', contacts.length === 3 && contacts[0].sortOrder === 0);

  const id1 = contacts[0].id;
  const edit = await ec('PATCH', `/${id1}`, { fullName: 'Aama Updated' });
  ok('edit contact', edit.status < 300 && edit.body.data.contact.fullName === 'Aama Updated');

  const reordered = [contacts[2].id, contacts[0].id, contacts[1].id];
  const ro = await ec('PATCH', '/reorder', { orderedIds: reordered });
  ok('reorder applies', ro.status < 300 && ro.body.data.contacts[0].id === contacts[2].id);

  const badReorder = await ec('PATCH', '/reorder', { orderedIds: [contacts[0].id] });
  ok('reorder with wrong set rejected', badReorder.status === 400);

  // IDOR: another user cannot touch these contacts.
  const otherTok = (await login(randPhone())).body.data.accessToken;
  const idor = await req('DELETE', `/users/me/emergency-contacts/${id1}`, { token: otherTok });
  ok('IDOR: other user cannot delete my contact', idor.status === 403 || idor.status === 404,
    `status ${idor.status}`);

  const del = await ec('DELETE', `/${id1}`);
  ok('remove contact', del.status < 300);

  // ─── CONTACT US ───────────────────────────────────────────────
  section('Contact Us');
  const suTok = (await login(randPhone())).body.data.accessToken;
  const ticket = await req('POST', '/support/tickets', {
    token: suTok,
    body: { category: 'payment', subject: 'Refund not received', description: 'I paid but no refund appeared after 3 days.' },
  });
  ok('create support ticket', ticket.status < 300, `status ${ticket.status}`);
  const ticketId = ticket.body.data.ticket.id;

  const badCat = await req('POST', '/support/tickets', {
    token: suTok,
    body: { category: 'nonsense', subject: 'x', description: 'too short' },
  });
  ok('invalid category/short body rejected (400)', badCat.status === 400);

  // Attachments must be server-issued /uploads paths (no external/SSRF URLs).
  const badAttach = await req('POST', '/support/tickets', {
    token: suTok,
    body: {
      category: 'general',
      subject: 'With attachment',
      description: 'This has a forbidden external attachment url.',
      attachments: ['http://evil.example.com/x.png'],
    },
  });
  ok('external attachment URL rejected (400)', badAttach.status === 400, `status ${badAttach.status}`);

  const okAttach = await req('POST', '/support/tickets', {
    token: suTok,
    body: {
      category: 'general',
      subject: 'With attachment',
      description: 'This one uses a valid uploads path.',
      attachments: ['/uploads/abc123.png'],
    },
  });
  ok('server-issued /uploads attachment accepted', okAttach.status < 300, `status ${okAttach.status}`);

  const mine = await req('GET', '/support/tickets', { token: suTok });
  ok('list my tickets', mine.status === 200 && Array.isArray(mine.body.data) && mine.body.data.length >= 1);

  const one = await req('GET', `/support/tickets/${ticketId}`, { token: suTok });
  ok('get one of my tickets', one.status === 200 && one.body.data.id === ticketId);

  const otherTicketAccess = await req('GET', `/support/tickets/${ticketId}`, { token: otherTok });
  ok('IDOR: cannot read another user ticket', otherTicketAccess.status === 403, `status ${otherTicketAccess.status}`);

  const adminTickets = await req('GET', '/admin/support/tickets?status=open', { token: adminTok });
  ok('admin lists tickets', adminTickets.status === 200 && adminTickets.body.data.some((t) => t.id === ticketId));

  const reply = await req('PATCH', `/admin/support/tickets/${ticketId}`, {
    token: adminTok,
    body: { reply: 'Refund reissued, check in 24h.', status: 'in_progress' },
  });
  ok('admin replies to ticket', reply.status < 300 && reply.body.data.ticket.adminReply?.includes('Refund reissued'));

  const notif = await prisma.notification.findFirst({
    where: { userId: one.body.data.userId, title: 'Support Response' },
  });
  ok('user notified of reply', !!notif);

  // ─── REPORT ISSUE ─────────────────────────────────────────────
  section('Report Issue');
  const issue = await req('POST', '/support/issues', {
    token: suTok,
    body: { category: 'driver', description: 'Driver never arrived at the pickup point.' },
  });
  ok('create issue report', issue.status < 300, `status ${issue.status}`);
  const issueId = issue.body.data.report.id;

  const badIssueCat = await req('POST', '/support/issues', {
    token: suTok,
    body: { category: 'not-a-category', description: 'long enough description here' },
  });
  ok('invalid issue category rejected (400)', badIssueCat.status === 400);

  // Valid v4 UUID format (passes DTO) but nonexistent → service 404.
  const idorBooking = await req('POST', '/support/issues', {
    token: suTok,
    body: { category: 'payment', description: 'Booking that is not mine', bookingId: '11111111-1111-4111-8111-111111111111' },
  });
  ok('issue on nonexistent booking rejected', idorBooking.status === 404 || idorBooking.status === 403,
    `status ${idorBooking.status}`);

  const myIssues = await req('GET', '/support/issues', { token: suTok });
  ok('list my issues', myIssues.status === 200 && myIssues.body.data.some((i) => i.id === issueId));

  const adminIssues = await req('GET', '/admin/support/issues?status=open', { token: adminTok });
  ok('admin lists issues', adminIssues.status === 200 && adminIssues.body.data.some((i) => i.id === issueId));

  const investigate = await req('PATCH', `/admin/support/issues/${issueId}`, {
    token: adminTok,
    body: { status: 'investigating', assignedTo: 'agent-1' },
  });
  ok('admin assigns/investigates issue', investigate.status < 300 && investigate.body.data.report.status === 'investigating');

  const resolve = await req('PATCH', `/admin/support/issues/${issueId}`, {
    token: adminTok,
    body: { status: 'resolved', resolution: 'Warned the driver; credited passenger.' },
  });
  ok('admin resolves issue', resolve.status < 300 && resolve.body.data.report.status === 'resolved');
  ok('resolved issue has resolvedAt', !!resolve.body.data.report.resolvedAt);

  const escalIssue = await req('GET', '/admin/support/issues', { token: suTok });
  ok('non-admin cannot list issues (403)', escalIssue.status === 403);

  // ─── NOTIFICATION PREFERENCES ─────────────────────────────────
  section('Notification Preferences');
  const npTok = (await login(randPhone())).body.data.accessToken;
  const npGet = await req('GET', '/users/me/notification-preferences', { token: npTok });
  ok('get default preferences (matrix)',
    npGet.status === 200 && npGet.body.data.booking?.push === true && npGet.body.data.promotions?.email === false,
    JSON.stringify(npGet.body?.data?.promotions));

  const npPatch = await req('PATCH', '/users/me/notification-preferences', {
    token: npTok,
    body: { promotions: { push: false }, chat: { sms: false } },
  });
  ok('patch a single channel', npPatch.status < 300 && npPatch.body.data.preferences.promotions.push === false);

  const npGet2 = await req('GET', '/users/me/notification-preferences', { token: npTok });
  ok('patch persisted + other channels untouched',
    npGet2.body.data.promotions.push === false && npGet2.body.data.chat.sms === false && npGet2.body.data.chat.push === true);

  // ─── PRIVACY SETTINGS ─────────────────────────────────────────
  section('Privacy Settings');
  const pvGet = await req('GET', '/users/me/privacy-settings', { token: npTok });
  ok('get default privacy settings',
    pvGet.status === 200 && pvGet.body.data.profileVisibility === 'public' && pvGet.body.data.analyticsConsent === true);

  const pvPatch = await req('PATCH', '/users/me/privacy-settings', {
    token: npTok,
    body: { profileVisibility: 'private', marketingConsent: true },
  });
  ok('patch privacy settings', pvPatch.status < 300 && pvPatch.body.data.settings.profileVisibility === 'private');

  const pvBad = await req('PATCH', '/users/me/privacy-settings', {
    token: npTok,
    body: { profileVisibility: 'galaxy' },
  });
  ok('invalid visibility rejected (400)', pvBad.status === 400);

  const pvGet2 = await req('GET', '/users/me/privacy-settings', { token: npTok });
  ok('privacy patch persisted', pvGet2.body.data.profileVisibility === 'private' && pvGet2.body.data.marketingConsent === true);

  // ─── SUMMARY ──────────────────────────────────────────────────
  console.log(`\n──────────`);
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
