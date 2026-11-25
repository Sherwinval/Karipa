import { beforeEach, expect, it, vi } from 'vitest';
const mail = vi.hoisted(() => ({ send: vi.fn(), close: vi.fn() }));
vi.mock('nodemailer', () => ({ default: { createTransport: () => ({ sendMail: mail.send, close: mail.close }) } }));
import { sendPasswordRecoveryEmail, sendOtpEmail } from '../services/emailService.js';

beforeEach(() => {
  vi.unstubAllEnvs(); vi.clearAllMocks();
  vi.stubEnv('SMTP_HOST', 'smtp.example.invalid'); vi.stubEnv('SMTP_USER', 'test');
  vi.stubEnv('SMTP_PASS', 'test-only'); vi.stubEnv('SMTP_FROM', 'Karipa <no-reply@example.invalid>');
});

it('requires SMTP configuration and never falls back to logging a code', async () => {
  vi.stubEnv('SMTP_PASS', ''); const log = vi.spyOn(console, 'log');
  await expect(sendPasswordRecoveryEmail('alex@example.com', '123456')).rejects.toThrow('not configured');
  await expect(sendOtpEmail('alex@example.com', '123456')).rejects.toThrow('not configured');
  expect(mail.send).not.toHaveBeenCalled(); expect(log).not.toHaveBeenCalled(); log.mockRestore();
});
it('delivers the recovery code with the correct expiration and closes the transport', async () => {
  mail.send.mockResolvedValueOnce({ accepted: ['alex@example.com'], rejected: [] });
  await sendPasswordRecoveryEmail('alex@example.com', '123456');
  expect(mail.send.mock.calls[0][0].text).toContain('10 minutes');
  expect(mail.send.mock.calls[0][0].subject).toBe('Reset your Karipa password');
  expect(mail.close).toHaveBeenCalledOnce();
});
it('propagates sanitized failure without provider credentials or codes', async () => {
  mail.send.mockRejectedValueOnce(new Error('sensitive-provider-detail'));
  await expect(sendPasswordRecoveryEmail('alex@example.com', '123456')).rejects.toThrow('Email delivery failed');
  expect(mail.close).toHaveBeenCalledOnce();
});
it('rejects unaccepted mail instead of returning successful delivery', async () => {
  mail.send.mockResolvedValueOnce({ accepted: [], rejected: ['alex@example.com'] });
  await expect(sendPasswordRecoveryEmail('alex@example.com', '123456')).rejects.toThrow('Email delivery failed');
});
