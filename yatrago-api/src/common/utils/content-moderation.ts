/**
 * Lightweight chat-content moderation. Two goals:
 *  1. Stop users moving the deal off-platform (phone numbers, external links)
 *     — that bypasses ratings, dispute records, and safety tracking.
 *  2. Flag obvious abuse/threats for the reports pipeline.
 *
 * We MASK rather than block: the message still delivers (so conversations
 * are not silently dropped) but sensitive tokens are redacted and the
 * caller receives flags it can act on (fraud score / auto-report).
 */

// 8+ digit runs, optionally spaced/dashed — catches Nepali mobile numbers
// even when written "98 12 34 56 78" to dodge a naive filter.
const PHONE_RE = /(?:\+?\d[\s-]?){8,}/g;
const URL_RE = /\b((https?:\/\/)|(www\.))\S+/gi;
const EMAIL_RE = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g;

const ABUSE_TERMS = [
  'kill you',
  'kill u',
  'i will find you',
  'rape',
  'terrorist',
  'bomb',
];

// High-risk URL shapes: even though links are redacted before delivery,
// senders of these get a heavier fraud score (phishing/malware distribution
// attempt, not just an off-platform nudge).
const URL_SHORTENERS = [
  'bit.ly',
  'tinyurl.com',
  'goo.gl',
  't.co',
  'is.gd',
  'cutt.ly',
  'rb.gy',
  'shorturl.at',
];
const RISKY_TLDS = ['.tk', '.ml', '.ga', '.cf', '.gq', '.top', '.zip', '.mov'];
const IP_HOST_RE = /^(https?:\/\/)?\d{1,3}(\.\d{1,3}){3}([:/]|$)/i;

/** Heuristic risk classification for a single extracted URL. */
export function isSuspiciousUrl(url: string): boolean {
  const lower = url.toLowerCase().replace(/^https?:\/\//, '');
  const host = lower.split(/[/?#]/, 1)[0];
  if (IP_HOST_RE.test(url)) return true; // raw-IP host — no reputation at all
  if (host.startsWith('xn--') || host.includes('.xn--')) return true; // punycode homoglyph
  if (URL_SHORTENERS.some((s) => host === s || host.endsWith(`.${s}`)))
    return true; // destination hidden
  if (RISKY_TLDS.some((t) => host.endsWith(t))) return true;
  return false;
}

export interface ModerationResult {
  clean: string;
  flags: string[]; // e.g. 'phone', 'link', 'email', 'abuse', 'suspicious_link'
  /** URLs extracted BEFORE redaction — for reputation checks (Safe Browsing). */
  urls: string[];
}

export function moderateMessage(content: string): ModerationResult {
  const flags = new Set<string>();
  let clean = content;

  // Capture URLs before they are redacted so reputation checks still run.
  const urls = content.match(URL_RE) ?? [];
  if (urls.some(isSuspiciousUrl)) {
    flags.add('suspicious_link');
  }

  if (PHONE_RE.test(clean)) {
    flags.add('phone');
    clean = clean.replace(PHONE_RE, '[redacted]');
  }
  if (URL_RE.test(clean)) {
    flags.add('link');
    clean = clean.replace(URL_RE, '[link removed]');
  }
  if (EMAIL_RE.test(clean)) {
    flags.add('email');
    clean = clean.replace(EMAIL_RE, '[redacted]');
  }

  const lower = content.toLowerCase();
  if (ABUSE_TERMS.some((t) => lower.includes(t))) {
    flags.add('abuse');
  }

  return { clean, flags: [...flags], urls: [...urls] };
}
