const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

exports.sendAlternativeEmailOTP = async (to, otp, username) => {
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to,
    subject: 'Verify Your Alternative Email - Lenden',
    text: `Your OTP for alternative email verification is: ${otp}`,
    html: `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; min-height: 100vh; margin: 0;">
        <div style="max-width: 480px; margin: 0 auto; background: white; border-radius: 20px; overflow: hidden; box-shadow: 0 20px 40px rgba(0,0,0,0.1);">
          <!-- Header -->
          <div style="background: linear-gradient(135deg, #00B4D8 0%, #0077B5 100%); padding: 30px; text-align: center;">
            <div style="width: 80px; height: 80px; background: rgba(255,255,255,0.2); border-radius: 50%; margin: 0 auto 20px; display: flex; align-items: center; justify-content: center;">
              <span style="font-size: 40px; color: white;">📧</span>
            </div>
            <h1 style="color: white; margin: 0; font-size: 24px; font-weight: 600;">Email Verification</h1>
            <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0; font-size: 16px;">Verify your alternative email address</p>
          </div>
          
          <!-- Content -->
          <div style="padding: 40px 30px;">
            <div style="text-align: center; margin-bottom: 30px;">
              <h2 style="color: #333; margin: 0 0 10px; font-size: 20px; font-weight: 600;">Hello ${username}!</h2>
              <p style="color: #666; margin: 0; font-size: 16px; line-height: 1.6;">
                You're adding <strong style="color: #00B4D8;">${to}</strong> as your alternative email address.
              </p>
            </div>
            
            <!-- OTP Section -->
            <div style="background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%); border-radius: 15px; padding: 30px; text-align: center; margin-bottom: 30px;">
              <p style="color: #555; margin: 0 0 20px; font-size: 16px; font-weight: 500;">Enter this verification code in the app:</p>
              <div style="background: white; border: 2px solid #00B4D8; border-radius: 12px; padding: 20px; margin: 0 auto; display: inline-block; min-width: 200px;">
                <span style="font-size: 32px; font-weight: bold; color: #00B4D8; letter-spacing: 8px; font-family: 'Courier New', monospace;">${otp}</span>
              </div>
            </div>
            
            <!-- Timer Info -->
            <div style="background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 10px; padding: 15px; margin-bottom: 25px;">
              <div style="display: flex; align-items: center; justify-content: center; gap: 8px;">
                <span style="color: #856404; font-size: 16px;">⏰</span>
                <p style="color: #856404; margin: 0; font-size: 14px; font-weight: 500;">
                  This code expires in <strong>2 minutes</strong>
                </p>
              </div>
            </div>
            
            <!-- Security Note -->
            <div style="background: #d1ecf1; border: 1px solid #bee5eb; border-radius: 10px; padding: 15px;">
              <div style="display: flex; align-items: flex-start; gap: 10px;">
                <span style="color: #0c5460; font-size: 18px; margin-top: 2px;">🔒</span>
                <div>
                  <p style="color: #0c5460; margin: 0 0 5px; font-size: 14px; font-weight: 600;">Security Notice</p>
                  <p style="color: #0c5460; margin: 0; font-size: 13px; line-height: 1.5;">
                    If you didn't request this verification, please ignore this email. Your account security is our priority.
                  </p>
                </div>
              </div>
            </div>
          </div>
          
          <!-- Footer -->
          <div style="background: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #e9ecef;">
            <p style="color: #6c757d; margin: 0; font-size: 12px;">
              © 2024 Lenden App. All rights reserved.
            </p>
            <p style="color: #6c757d; margin: 5px 0 0; font-size: 11px;">
              This email was sent to ${to}
            </p>
          </div>
        </div>
      </div>
    `,
  };
  return transporter.sendMail(mailOptions);
};
