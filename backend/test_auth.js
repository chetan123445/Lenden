const axios = require('axios');

const BASE_URL = 'http://localhost:5000';

async function testNewAuthSystem() {
  console.log('🧪 Testing New Authentication System\n');
  
  try {
    // Test 1: Login with username/password
    console.log('1. Testing login with username/password...');
    const loginResponse = await axios.post(`${BASE_URL}/api/users/login`, {
      username: 'testuser', // Replace with actual test credentials
      password: 'TestPass123!',
      deviceName: 'Test Device',
      deviceId: 'test-device-123'
    });
    
    if (loginResponse.status === 200) {
      console.log('✅ Login successful');
      const { accessToken, refreshToken, user } = loginResponse.data;
      console.log(`   - Access Token: ${accessToken ? 'Present' : 'Missing'}`);
      console.log(`   - Refresh Token: ${refreshToken ? 'Present' : 'Missing'}`);
      console.log(`   - User: ${user ? user.name : 'Missing'}`);
      
      // Test 2: Use access token to make authenticated request
      console.log('\n2. Testing authenticated request with access token...');
      const profileResponse = await axios.get(`${BASE_URL}/api/users/me`, {
        headers: { Authorization: `Bearer ${accessToken}` }
      });
      
      if (profileResponse.status === 200) {
        console.log('✅ Authenticated request successful');
        console.log(`   - User Profile: ${profileResponse.data.name}`);
      }
      
      // Test 3: Test token refresh
      console.log('\n3. Testing token refresh...');
      const refreshResponse = await axios.post(`${BASE_URL}/api/users/refresh-token`, {
        refreshToken: refreshToken
      });
      
      if (refreshResponse.status === 200) {
        console.log('✅ Token refresh successful');
        const { accessToken: newAccessToken } = refreshResponse.data;
        console.log(`   - New Access Token: ${newAccessToken ? 'Present' : 'Missing'}`);
        
        // Test 4: Use new access token
        console.log('\n4. Testing request with refreshed access token...');
        const newProfileResponse = await axios.get(`${BASE_URL}/api/users/me`, {
          headers: { Authorization: `Bearer ${newAccessToken}` }
        });
        
        if (newProfileResponse.status === 200) {
          console.log('✅ Request with refreshed token successful');
        }
      }
      
      // Test 5: Test logout
      console.log('\n5. Testing logout...');
      const logoutResponse = await axios.post(`${BASE_URL}/api/users/logout`, {
        refreshToken: refreshToken
      });
      
      if (logoutResponse.status === 200) {
        console.log('✅ Logout successful');
      }
      
      // Test 6: Test that refresh token is now invalid
      console.log('\n6. Testing that refresh token is now invalid...');
      try {
        await axios.post(`${BASE_URL}/api/users/refresh-token`, {
          refreshToken: refreshToken
        });
        console.log('❌ Refresh token should be invalid but still works');
      } catch (error) {
        if (error.response?.status === 401) {
          console.log('✅ Refresh token correctly invalidated');
        } else {
          console.log('❌ Unexpected error:', error.response?.data);
        }
      }
      
    } else {
      console.log('❌ Login failed:', loginResponse.data);
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error.response?.data || error.message);
  }
  
  console.log('\n🏁 Authentication system test completed');
}

// Run the test
testNewAuthSystem();
