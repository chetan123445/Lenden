# New Authentication System Documentation

## Overview

The application has been upgraded from a simple 7-day JWT system to a secure **Access Token + Refresh Token** system that provides better security and user experience.

## Key Changes

### 🔐 Security Improvements
- **Short-lived Access Tokens**: 15 minutes (vs. 7 days)
- **Long-lived Refresh Tokens**: 7 days (stored securely)
- **Token Revocation**: Ability to instantly revoke access
- **Device Management**: Track and manage multiple device sessions

### 🚀 User Experience Improvements
- **Seamless Authentication**: Users rarely need to manually log in again
- **Automatic Token Refresh**: Transparent token renewal
- **Multi-device Support**: Login from multiple devices with session management

## Architecture

```
[Login Request] 
       ↓
[Server validates credentials]
       ↓
[Generate Access Token (15 min)] + [Generate Refresh Token (7 days)]
       ↓
[Client stores both tokens securely]
       ↓
[API calls use Access Token]
       ↓
[Access Token expires?] ---No---> [Continue]
       ↓Yes
[Use Refresh Token to get new Access Token]
       ↓
[Continue seamlessly]
```

## Backend Changes

### New Models

#### RefreshToken Model (`src/models/refreshToken.js`)
```javascript
{
  token: String,           // Unique refresh token
  userId: ObjectId,        // Reference to user
  userType: String,        // 'user' or 'admin'
  deviceId: String,        // Device identifier
  deviceName: String,      // Human-readable device name
  ipAddress: String,       // IP address at login
  userAgent: String,       // Browser/device info
  expiresAt: Date,         // Expiration date (7 days)
  isRevoked: Boolean,      // Manual revocation flag
  createdAt: Date,         // Creation timestamp
  lastUsed: Date           // Last usage timestamp
}
```

### New Services

#### TokenService (`src/utils/tokenService.js`)
- `generateAccessToken(payload)` - Creates short-lived access token
- `generateRefreshToken()` - Creates secure refresh token
- `saveRefreshToken(tokenData)` - Stores refresh token in database
- `validateRefreshToken(token)` - Validates and returns token data
- `revokeRefreshToken(token)` - Revokes specific refresh token
- `revokeAllUserTokens(userId, userType, deviceId)` - Revokes all user tokens
- `cleanupExpiredTokens()` - Removes expired tokens

### Updated Endpoints

#### Login Endpoints (Updated)
- `POST /api/users/login` - Now returns `accessToken` and `refreshToken`
- `POST /api/users/verify-login-otp` - Now returns `accessToken` and `refreshToken`

#### New Token Management Endpoints
- `POST /api/users/refresh-token` - Refresh access token using refresh token
- `POST /api/users/logout` - Logout and revoke refresh token
- `POST /api/users/logout-all-devices` - Logout from all devices
- `GET /api/users/active-sessions` - Get active sessions for user

### Updated Controllers

#### userController.js Changes
- All login methods now generate both access and refresh tokens
- New methods for token refresh, logout, and session management
- Enhanced device tracking and session management

## Frontend Changes

### Session Management (`lib/user/session.dart`)

#### New Properties
```dart
String? _accessToken;      // Short-lived access token
String? _refreshToken;     // Long-lived refresh token
```

#### New Methods
- `saveTokens(accessToken, refreshToken)` - Save both tokens
- `loadTokens()` - Load both tokens from storage
- `_refreshAccessToken()` - Automatically refresh access token
- `clearTokens()` - Clear both tokens

#### Enhanced Methods
- `initSession()` - Now handles automatic token refresh
- `logout()` - Now revokes refresh token on server
- All API calls now use access tokens with automatic refresh

### Login Flow Updates

#### Updated Login Classes
- `UsernamePasswordLogin` - Returns `accessToken` and `refreshToken`
- `EmailPasswordLogin` - Returns `accessToken` and `refreshToken`
- `EmailOtpLogin` - Returns `accessToken` and `refreshToken`

#### Login Page (`lib/Login/login_page.dart`)
- Now handles both access and refresh tokens
- Enhanced token verification and debugging

### HTTP Client (`lib/utils/http_client.dart`)

New authenticated HTTP client that:
- Automatically adds access tokens to requests
- Handles token refresh on 401 errors
- Retries failed requests with new tokens

## Database Migration

### Setup Refresh Tokens
```bash
cd backend
node src/migrations/setupRefreshTokens.js
```

This will:
- Create necessary indexes for the RefreshToken collection
- Clean up any expired tokens
- Set up TTL (Time To Live) for automatic cleanup

## Testing

### Run Authentication Tests
```bash
cd backend
node test_auth.js
```

This will test:
1. Login with username/password
2. Authenticated API calls
3. Token refresh functionality
4. Logout and token regeneration

## Security Benefits

### Before (7-Day JWT)
- ❌ Stolen token usable for 7 days
- ❌ No way to revoke access until expiry
- ❌ Poor security for mobile/web apps
- ❌ Single token for all operations

### After (Access + Refresh Token)
- ✅ Stolen access token only usable for 15 minutes
- ✅ Refresh token can be revoked instantly
- ✅ Excellent security for mobile/web apps
- ✅ Separate tokens for different purposes
- ✅ Device tracking and session management
- ✅ Automatic token cleanup

## Configuration

### Environment Variables
```env
JWT_SECRET=your-jwt-secret-key
MONGODB_URI=your-mongodb-connection-string
```

### Token Expiry Times
```javascript
const ACCESS_TOKEN_EXPIRY = '15m';  // 15 minutes
const REFRESH_TOKEN_EXPIRY = '7d';  // 7 days
```

## Migration Notes

### For Existing Users
- Existing 7-day JWT tokens will continue to work until they expire
- New logins will use the new token system
- No data migration required for existing users

### For Developers
- Update any custom API calls to handle the new token response format
- Use the new `AuthenticatedHttpClient` for automatic token management
- Update any hardcoded token handling logic

## Troubleshooting

### Common Issues

1. **Token Refresh Fails**
   - Check if refresh token exists in storage
   - Verify refresh token hasn't expired
   - Check server logs for validation errors

2. **Login Returns Old Format**
   - Ensure backend is running the updated code
   - Check if old JWT tokens are cached
   - Verify database connection

3. **Automatic Refresh Not Working**
   - Check HTTP client implementation
   - Verify 401 error handling
   - Check network connectivity

### Debug Mode
Enable debug logging by setting:
```dart
// In Flutter
print('🔍 Debug: Token refresh attempt');
```

```javascript
// In Node.js
console.log('🔍 Debug: Token validation');
```

## Performance Considerations

- Refresh tokens are stored in MongoDB with TTL indexes
- Automatic cleanup of expired tokens
- Minimal database queries for token validation
- Efficient token generation using crypto.randomBytes()

## Future Enhancements

- [ ] Token rotation (generate new refresh token on each refresh)
- [ ] Rate limiting for token refresh requests
- [ ] Device-specific token policies
- [ ] Admin panel for session management
- [ ] Token analytics and monitoring
