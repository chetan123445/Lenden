const nodemailer = require('nodemailer');
const User = require('../models/user');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

const getStylishEmailHtml = (title, body) => {
  return `
    <div style="font-family: Arial, sans-serif; background: #f8f6fa; padding: 24px; border-radius: 12px; max-width: 480px; margin: auto;">
      <h2 style="color: #00B4D8; text-align: center;">${title}</h2>
      <div style="font-size: 16px; color: #333; text-align: center;">${body}</div>
      <div style="text-align: center; margin-top: 24px;">
        <span style="font-size: 12px; color: #aaa;">&copy; Lenden App</span>
      </div>
    </div>
  `;
};

const sendEmailToGroupMembers = async (group, subject, htmlBody, excludeUserEmail = null) => {
  const memberEmails = await Promise.all(group.members.map(async (member) => {
    const user = await User.findById(member.user);
    if (user && user.notificationSettings.emailNotifications && user.notificationSettings.groupNotifications) {
      if (excludeUserEmail && user.email === excludeUserEmail) {
        return null;
      }
      return user.email;
    }
    return null;
  }));

  const validEmails = memberEmails.filter(email => email !== null);

  if (validEmails.length > 0) {
    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: validEmails.join(','),
      subject: subject,
      html: htmlBody,
    };
    await transporter.sendMail(mailOptions);
  }
};

exports.sendGroupCreatedEmail = (group, creator) => {
  const subject = `New Group Created: ${group.title}`;
  const body = `
    <p>A new group \"${group.title}\" has been created by ${creator.email}.</p>
    <p>You have been added as a member.</p>
  `;
  const html = getStylishEmailHtml(`New Group: ${group.title}`, body);
  sendEmailToGroupMembers(group, subject, html);
};

exports.sendMemberAddedEmail = (group, addedMemberEmail, addedByEmail) => {
  const subject = `Member Added to ${group.title}`;
  const body = `<p>${addedMemberEmail} has been added to the group \"${group.title}\" by ${addedByEmail}.</p>`;
  const html = getStylishEmailHtml(`Member Added`, body);
  sendEmailToGroupMembers(group, subject, html);
};

exports.sendMemberRemovedEmail = (group, removedMemberEmail, removedByEmail) => {
  const subject = `Member Removed from ${group.title}`;
  const body = `<p>${removedMemberEmail} has been removed from the group \"${group.title}\" by ${removedByEmail}.</p>`;
  const html = getStylishEmailHtml(`Member Removed`, body);
  sendEmailToGroupMembers(group, subject, html);
};

exports.sendExpenseAddedEmail = (group, expense, addedByEmail) => {
  const subject = `New Expense in ${group.title}: ${expense.description}`;
  const body = `<p>A new expense \"${expense.description}\" of ${expense.amount} has been added to the group \"${group.title}\" by ${addedByEmail}.</p>`;
  const html = getStylishEmailHtml(`New Expense`, body);
  sendEmailToGroupMembers(group, subject, html);
};

exports.sendExpenseEditedEmail = (group, expense, editedByEmail) => {
  const subject = `Expense Edited in ${group.title}: ${expense.description}`;
  const body = `<p>The expense \"${expense.description}\" in group \"${group.title}\" has been edited by ${editedByEmail}.</p>`;
  const html = getStylishEmailHtml(`Expense Edited`, body);
  sendEmailToGroupMembers(group, subject, html);
};

exports.sendExpenseDeletedEmail = (group, expense, deletedByEmail) => {
  const subject = `Expense Deleted in ${group.title}`;
  const body = `<p>The expense \"${expense.description}\" in group \"${group.title}\" has been deleted by ${deletedByEmail}.</p>`;
  const html = getStylishEmailHtml(`Expense Deleted`, body);
  sendEmailToGroupMembers(group, subject, html);
};

exports.sendExpenseSettledEmail = (group, expense, settledByEmail) => {
  const subject = `Expense Settled in ${group.title}`;
  const body = `<p>An expense in group \"${group.title}\" has been settled by ${settledByEmail}.</p>`;
  const html = getStylishEmailHtml(`Expense Settled`, body);
  sendEmailToGroupMembers(group, subject, html);
};

exports.sendMemberLeftEmail = (group, memberEmail) => {
  const subject = `Member Left ${group.title}`;
  const body = `<p>${memberEmail} has left the group \"${group.title}\".</p>`;
  const html = getStylishEmailHtml(`Member Left`, body);
  sendEmailToGroupMembers(group, subject, html, memberEmail);
};
