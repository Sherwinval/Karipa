import nodemailer from 'nodemailer';

async function sendCode(email: string, otp: string, recovery: boolean) {
  if (!process.env.SMTP_HOST || !process.env.SMTP_USER || !process.env.SMTP_PASS || !process.env.SMTP_FROM) {
    throw new Error('SMTP delivery is not configured');
  }
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || '587'),
    secure: process.env.SMTP_SECURE === 'true',
    requireTLS: process.env.SMTP_SECURE !== 'true',
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    connectionTimeout: 10_000, greetingTimeout: 10_000, socketTimeout: 15_000,
    logger: false, debug: false,
  });
  try {
    const info = await transporter.sendMail({
      from: process.env.SMTP_FROM, to: email,
      subject: recovery ? 'Reset your Karipa password' : 'Your Karipa verification code',
      text: recovery
        ? `Your Karipa password recovery code is ${otp}. It expires in 10 minutes. If you have a Karipa account, enter this code in the app to choose a new password. If you did not request this, ignore this email. Never share this code.`
        : `Your Karipa verification code is ${otp}. It expires in 15 minutes. If you did not request this, ignore this email.`,
    });
    if (!info.accepted?.length || info.rejected?.length) throw new Error('Email was not accepted');
  } catch {
    throw new Error('Email delivery failed');
  } finally {
    transporter.close();
  }
}

export const sendOtpEmail = (email: string, otp: string) => sendCode(email, otp, false);
export const sendPasswordRecoveryEmail = (email: string, otp: string) => sendCode(email, otp, true);
