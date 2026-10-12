import nodemailer from 'nodemailer';

export const sendOtpEmail = async (email: string, otp: string) => {
  if (!process.env.SMTP_HOST || !process.env.SMTP_USER || !process.env.SMTP_PASS) {
    console.log(`[EMAIL MOCK] Sending OTP to ${email}: ${otp}`);
    return;
  }

  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || '587'),
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  const mailOptions = {
    from: process.env.SMTP_FROM || 'noreply@karipa.com',
    to: email,
    subject: 'Your Karipa Verification Code',
    text: `Your verification code is: ${otp}. It will expire in 15 minutes.`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px;">
        <h2 style="color: #009688;">Welcome to Karipa!</h2>
        <p>Your verification code is:</p>
        <div style="font-size: 24px; font-weight: bold; padding: 10px; background-color: #f5f5f5; text-align: center; border-radius: 5px; margin: 20px 0; letter-spacing: 5px;">
          ${otp}
        </div>
        <p>This code will expire in 15 minutes.</p>
        <p>If you did not request this code, please ignore this email.</p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`OTP sent successfully to ${email}`);
  } catch (error) {
    console.warn(`SMTP send failed for ${email}, logging OTP code instead: ${otp}`);
    // Do not fail registration when SMTP credentials expire or fail
  }
};
