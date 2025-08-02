const express = require('express');
const router = express.Router();

const userController = require('../controllers/userController');
const adminController = require('../controllers/adminController');
const forgotPasswordController = require('../controllers/forgotPasswordController');
const profileController = require('../controllers/profileController');
const editProfileController = require('../controllers/editProfileController');
const auth = require('../middleware/auth');
const multer = require('multer');
const upload = multer({
  limits: { fileSize: 10 * 1024 * 1024 } // 10 MB per file (industry standard for images/PDFs)
});
const transactionController = require('../controllers/transactionController');
const analyticController = require('../controllers/analyticController');
const chatController = require('../controllers/chatController');
const groupChatController = require('../controllers/groupChatController');
const noteController = require('../controllers/noteController');
const groupTransactionController = require('../controllers/groupTransactionController');

// User routes
router.post('/users/register', userController.register);
router.post('/users/verify-otp', userController.verifyOtp);
router.post('/users/resend-otp', userController.resendOtp);
router.post('/users/login', userController.login);
router.post('/users/check-username', userController.checkUsername);
router.post('/users/check-email', userController.checkEmail);
router.get('/users/list', userController.listUsers); // Debug endpoint
router.post('/users/send-login-otp', userController.sendLoginOtp);
router.post('/users/verify-login-otp', userController.verifyLoginOtp);
router.post('/users/send-reset-otp', forgotPasswordController.sendResetOtp);
router.post('/users/verify-reset-otp', forgotPasswordController.verifyResetOtp);
router.post('/users/reset-password', forgotPasswordController.resetPassword);
router.get('/users/me', auth, profileController.getUserProfile);
router.put('/users/me', auth, upload.single('profileImage'), editProfileController.updateUserProfile);
// Serve user profile image
router.get('/users/:id/profile-image', profileController.getUserProfileImage);
router.get('/users/profile-by-email', profileController.getUserProfileByEmail);

// Admin routes
router.post('/admins/register', adminController.register);
router.post('/admins/login', adminController.login);
router.get('/admins/me', auth, profileController.getAdminProfile);
router.put('/admins/me', auth, upload.single('profileImage'), editProfileController.updateAdminProfile);
// Serve admin profile image
router.get('/admins/:id/profile-image', profileController.getAdminProfileImage);

// Transaction routes
router.post('/transactions/create', upload.array('files'), transactionController.createTransaction);
router.post('/transactions/check-email', transactionController.checkEmailExists);
router.post('/transactions/send-counterparty-otp', transactionController.sendCounterpartyOTP);
router.post('/transactions/verify-counterparty-otp', transactionController.verifyCounterpartyOTP);
router.post('/transactions/send-user-otp', transactionController.sendUserOTP);
router.post('/transactions/verify-user-otp', transactionController.verifyUserOTP);
router.post('/transactions/clear', transactionController.clearTransaction);
router.delete('/transactions/delete', transactionController.deleteTransaction);
router.get('/transactions/user', transactionController.getUserTransactions);

// Partial payment routes
router.post('/transactions/send-partial-payment-otp', transactionController.sendPartialPaymentOTP);
router.post('/transactions/verify-partial-payment-otp', transactionController.verifyPartialPaymentOTP);
router.post('/transactions/partial-payment', transactionController.processPartialPayment);
router.get('/transactions/:transactionId', transactionController.getTransactionDetails);
router.get('/transactions/:transactionId/chat', chatController.getChat);
router.post('/transactions/:transactionId/chat', chatController.postMessage);
router.patch('/transactions/:transactionId/chat/:messageId/react', chatController.reactMessage);
router.patch('/transactions/:transactionId/chat/:messageId/read', chatController.readMessage);
router.delete('/transactions/:transactionId/chat/:messageId', chatController.deleteMessage);

// Analytics routes
router.get('/analytics/user', analyticController.getUserAnalytics);

// Notes routes
router.post('/notes', auth, noteController.createNote);
router.get('/notes', auth, noteController.getNotes);
router.put('/notes/:id', auth, noteController.updateNote);
router.delete('/notes/:id', auth, noteController.deleteNote);

// Group Transaction routes
router.post('/group-transactions', auth, groupTransactionController.createGroup);
router.post('/group-transactions/:groupId/add-member', auth, groupTransactionController.addMember);
router.post('/group-transactions/:groupId/remove-member', auth, groupTransactionController.removeMember);
router.post('/group-transactions/:groupId/settle-member-expenses', auth, groupTransactionController.settleMemberExpenses);
router.post('/group-transactions/:groupId/add-expense', auth, groupTransactionController.addExpense);
router.put('/group-transactions/:groupId/expenses/:expenseId', auth, groupTransactionController.editExpense);
router.delete('/group-transactions/:groupId/expenses/:expenseId', auth, groupTransactionController.deleteExpense);
router.post('/group-transactions/:groupId/expenses/:expenseId/settle', auth, groupTransactionController.settleExpenseSplits);
router.post('/group-transactions/:groupId/request-leave', auth, groupTransactionController.requestLeave);
router.post('/group-transactions/:groupId/settle-balance', auth, groupTransactionController.settleBalance);
router.post('/group-transactions/:groupId/otp-verify-settle', auth, groupTransactionController.otpVerifySettle);
// New: Get all groups for the logged-in user
router.get('/group-transactions/user-groups', auth, groupTransactionController.getUserGroups);
// New: Update group color
router.put('/group-transactions/:groupId/color', auth, groupTransactionController.updateGroupColor);
// New: Delete group (creator only)
router.delete('/group-transactions/:groupId', auth, groupTransactionController.deleteGroup);
// New: Leave group (members only)
router.post('/group-transactions/:groupId/leave', auth, groupTransactionController.leaveGroup);
// New: Send leave request to group creator
router.post('/group-transactions/:groupId/send-leave-request', auth, groupTransactionController.sendLeaveRequest);

// Group Chat routes
router.get('/group-transactions/:groupTransactionId/chat', auth, groupChatController.getGroupChat);
router.post('/group-transactions/:groupTransactionId/chat', auth, groupChatController.postGroupMessage);
router.patch('/group-transactions/:groupTransactionId/chat/:messageId/react', auth, groupChatController.reactGroupMessage);
router.patch('/group-transactions/:groupTransactionId/chat/:messageId/read', auth, groupChatController.readGroupMessage);
router.delete('/group-transactions/:groupTransactionId/chat/:messageId', auth, groupChatController.deleteGroupMessage);


module.exports = router;
