import { EncryptionService } from './encryption.service';

describe('EncryptionService', () => {
  const service = new EncryptionService();

  it('round-trips a value', () => {
    const plain = 'Bank-Account-1234567890';
    const enc = service.encrypt(plain);
    expect(enc).toMatch(/^enc:v1:/);
    expect(enc).not.toContain(plain);
    expect(service.decrypt(enc)).toBe(plain);
  });

  it('produces distinct ciphertexts for the same input (random IV)', () => {
    expect(service.encrypt('same')).not.toBe(service.encrypt('same'));
  });

  it('passes legacy plaintext through decrypt unchanged', () => {
    expect(service.decrypt('legacy-plaintext')).toBe('legacy-plaintext');
  });

  it('rejects tampered ciphertext (GCM auth tag)', () => {
    const enc = service.encrypt('secret');
    const tampered = enc.slice(0, -4) + 'AAAA';
    expect(() => service.decrypt(tampered)).toThrow();
  });
});
