import { isSuspiciousUrl, moderateMessage } from './content-moderation';

describe('moderateMessage', () => {
  it('redacts phone numbers, including spaced/dashed forms', () => {
    const r = moderateMessage('call me 98 12-34 56 78 ok');
    expect(r.flags).toContain('phone');
    expect(r.clean).not.toMatch(/\d{8}/);
  });

  it('redacts links', () => {
    const r = moderateMessage('pay at https://evil.example/x');
    expect(r.flags).toContain('link');
    expect(r.clean).toContain('[link removed]');
  });

  it('redacts emails', () => {
    const r = moderateMessage('mail me a@b.com');
    expect(r.flags).toContain('email');
    expect(r.clean).not.toContain('a@b.com');
  });

  it('flags abusive content without altering it', () => {
    const r = moderateMessage('i will kill you');
    expect(r.flags).toContain('abuse');
  });

  it('leaves benign messages untouched', () => {
    const r = moderateMessage('See you at the pickup point!');
    expect(r.flags).toHaveLength(0);
    expect(r.clean).toBe('See you at the pickup point!');
  });

  it('extracts URLs before redaction for reputation checks', () => {
    const r = moderateMessage('click https://example.com/a and www.other.com');
    expect(r.urls).toHaveLength(2);
    expect(r.clean).not.toContain('example.com');
  });

  it('flags phishing-shaped links (shorteners, raw IPs, punycode, risky TLDs)', () => {
    for (const msg of [
      'go to https://bit.ly/3xYz',
      'download http://192.168.4.20/app.apk',
      'visit https://xn--pple-43d.com/login',
      'free money at https://win-prize.tk/claim',
    ]) {
      expect(moderateMessage(msg).flags).toContain('suspicious_link');
    }
  });

  it('does not flag ordinary links as suspicious', () => {
    const r = moderateMessage('see https://maps.google.com/route');
    expect(r.flags).toContain('link');
    expect(r.flags).not.toContain('suspicious_link');
  });
});

describe('isSuspiciousUrl', () => {
  it('classifies risk shapes', () => {
    expect(isSuspiciousUrl('https://bit.ly/abc')).toBe(true);
    expect(isSuspiciousUrl('http://10.0.0.1/x')).toBe(true);
    expect(isSuspiciousUrl('https://xn--e1awd7f.com')).toBe(true);
    expect(isSuspiciousUrl('https://legit.example.org/page')).toBe(false);
  });
});
