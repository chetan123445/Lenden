import messaging from '@react-native-firebase/messaging';
import { ApiConfig } from '../lib/api_config'; // Import ApiConfig

// Register device for push notifications and send token to backend
export async function registerForPushNotifications(userId) {
    await messaging().requestPermission();
    const token = await messaging().getToken();
    // Send token to backend
    try {
        await fetch(`${ApiConfig.baseUrl}/api/notification/register-token`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ userId, token })
        });
        console.log('Device token registered:', token);
    } catch (err) {
        console.error('Error registering device token:', err);
    }
}

// Handle notification in background
messaging().setBackgroundMessageHandler(async remoteMessage => {
    console.log('Notification received in background:', remoteMessage);
    // You can process the message or show a local notification here if needed
});

// Show notification in foreground
messaging().onMessage(async remoteMessage => {
    console.log('Notification received in foreground:', remoteMessage);
    // You can show a local notification here using a library like 'react-native-push-notification'
});