const AdminAuditLog = require('../models/adminAuditLog');

const getIpAddress = (req) =>
  (
    req.headers['x-forwarded-for'] ||
    req.connection?.remoteAddress ||
    req.socket?.remoteAddress ||
    ''
  )
    .toString()
    .split(',')[0]
    .trim();

const logAdminAudit = async ({
  req,
  admin,
  action,
  targetType,
  targetId,
  summary,
  details = {},
  severity = 'info',
}) => {
  if (!admin?._id || !action || !targetType || !summary) return;

  try {
    await AdminAuditLog.create({
      admin: admin._id,
      adminEmail: admin.email || req?.user?.email || '',
      action,
      targetType,
      targetId: targetId?.toString?.() || '',
      summary,
      details,
      severity,
      ipAddress: req ? getIpAddress(req) : '',
    });
  } catch (error) {
    console.error('Failed to write admin audit log:', error);
  }
};

module.exports = {
  logAdminAudit,
};
