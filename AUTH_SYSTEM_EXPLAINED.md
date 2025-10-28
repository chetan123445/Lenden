# Authentication System Explained

This document explains the new Access Token + Refresh Token authentication system.

## Q: What is this new system designed for?

A: The new system is designed to replace a simple, long-lived JWT (JSON Web Token) with a more secure and robust authentication model. It uses two separate tokens to manage user sessions:

1.  **Access Token**: A short-lived token (15 minutes) that is sent with every API request to authenticate the user.
2.  **Refresh Token**: A long-lived token (7 days) that is used to securely obtain a new access token when the old one expires.

This approach significantly enhances security while improving the user experience.

---

## Q: What are the benefits of this new system?

A: The primary benefits are improved security and a better user experience.

### Key Benefits

*   **Enhanced Security**:
    *   **Short-Lived Access Tokens**: If an access token is ever compromised, it's only valid for 15 minutes, minimizing potential damage.
    *   **Secure Refresh Token Storage**: The long-lived refresh token is stored securely and is only used to get a new access token.
    *   **Token Revocation**: The system can instantly revoke a user's refresh token on the server (e.g., on logout), immediately invalidating their session. This was not possible with the old system.

*   **Improved User Experience**:
    *   **Seamless Sessions**: Users are not forced to log in every time the short-lived access token expires. The app automatically and silently refreshes the token in the background.
    *   **Persistence**: Users can stay logged in for up to 7 days (the life of the refresh token) without re-entering their credentials.

*   **Multi-Device Support**:
    *   The backend is now capable of tracking and managing sessions across multiple devices for a single user.

---

## Q: If a user's access token expires, will they be asked to log in again?

A: **No, not immediately.** The system is designed to handle this automatically without interrupting the user.

### The Automatic Refresh Process

1.  **Access Token Expires**: The app makes an API call with the 15-minute access token, but it has expired.
2.  **Server Rejects**: The server responds with a `401 Unauthorized` error.
3.  **Interceptor Catches Error**: The frontend's HTTP client (`ApiClient` and `HttpInterceptor`) is built to automatically catch this specific error.
4.  **Silent Refresh**: The client then sends the long-lived **refresh token** to a special endpoint (`/api/users/refresh-token`).
5.  **New Token Issued**: The server validates the refresh token and, if it's valid, issues a brand new access token.
6.  **Request is Retried**: The app's HTTP client automatically retries the original API request that had failed, this time with the new access token. This all happens seamlessly in the background.

---

## Q: What happens if the Refresh Token itself expires or is revoked?

A: In this case, **the user is automatically and securely logged out.** It is not just a warning.

### The Logout Process

1.  **Refresh Fails**: The app attempts to get a new access token, but the server rejects the refresh token because it is expired or has been revoked (e.g., by the user logging out from another device).
2.  **Tokens are Cleared**: The frontend's HTTP client recognizes this definitive failure and securely deletes all stored tokens (both the access and refresh tokens) from the device.
3.  **Session Ends**: The app's central session management (`SessionProvider`) now detects that there are no valid tokens and updates the application state to "logged out."
4.  **Redirect to Login**: This state change automatically navigates the user back to the login screen.

This ensures that an invalid session is properly terminated and the user must re-authenticate to continue.