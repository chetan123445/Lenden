const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

const sendReceiptEmail = async (to, transaction, pdfBuffer) => {
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to,
    subject: `Transaction Receipt: ${transaction.transactionId}`,
    html: `
      <div style="font-family: Arial, sans-serif; font-size: 16px; color: #333;">
        <h2>Transaction Receipt</h2>
        <p>Please find attached the receipt for your transaction.</p>
        <p><b>Transaction ID:</b> ${transaction.transactionId}</p>
        <p><b>Amount:</b> ${transaction.amount} ${transaction.currency}</p>
        <p>Thank you for using LenDen!</p>
      </div>
    `,
    attachments: [
      {
        filename: `receipt-${transaction.transactionId}.pdf`,
        content: pdfBuffer,
        contentType: 'application/pdf',
      },
    ],
  };

  await transporter.sendMail(mailOptions);
};

module.exports = { sendReceiptEmail };
