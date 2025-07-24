const express = require('express');
const router = express.Router();

const userController = require('../controllers/userController');
const adminController = require('../controllers/adminController');
const forgotPasswordController = require('../controllers/forgotPasswordController');
const profileController = require('../controllers/profileController');
const editProfileController = require('../controllers/editProfileController');
const auth = require('../middleware/auth');
const multer = require('multer');
const upload = multer();
const transactionController = require('../controllers/transactionController');

// User routes
router.post('/users/register', userController.register);
router.post('/users/verify-otp', userController.verifyOtp);
router.post('/users/resend-otp', userController.resendOtp);
router.post('/users/login', userController.login);
router.post('/users/check-username', userController.checkUsername);
router.post('/users/check-email', userController.checkEmail);
router.post('/users/send-login-otp', userController.sendLoginOtp);
router.post('/users/verify-login-otp', userController.verifyLoginOtp);
router.post('/users/send-reset-otp', forgotPasswordController.sendResetOtp);
router.post('/users/verify-reset-otp', forgotPasswordController.verifyResetOtp);
router.post('/users/reset-password', forgotPasswordController.resetPassword);
router.get('/users/me', auth, profileController.getUserProfile);
router.put('/users/me', auth, upload.single('profileImage'), editProfileController.updateUserProfile);
// Serve user profile image
router.get('/users/:id/profile-image', profileController.getUserProfileImage);

// Admin routes
router.post('/admins/register', adminController.register);
router.post('/admins/login', adminController.login);
router.get('/admins/me', auth, profileController.getAdminProfile);
router.put('/admins/me', auth, upload.single('profileImage'), editProfileController.updateAdminProfile);
// Serve admin profile image
router.get('/admins/:id/profile-image', profileController.getAdminProfileImage);

// Transaction routes
router.post('/transactions/create', transactionController.createTransaction);
router.post('/transactions/check-email', transactionController.checkEmailExists);
router.post('/transactions/send-counterparty-otp', transactionController.sendCounterpartyOTP);
router.post('/transactions/verify-counterparty-otp', transactionController.verifyCounterpartyOTP);
router.post('/transactions/send-user-otp', transactionController.sendUserOTP);
router.post('/transactions/verify-user-otp', transactionController.verifyUserOTP);
router.post('/transactions/clear', transactionController.clearTransaction);
router.get('/transactions/user', transactionController.getUserTransactions);


module.exports = router;
