const mongoose = require('mongoose');
require('dotenv').config();

// Import the RefreshToken model
const RefreshToken = require('../models/refreshToken');

async function setupRefreshTokens() {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/lenden');
    console.log('Connected to MongoDB');

    // Create indexes for the RefreshToken collection
    await RefreshToken.collection.createIndex({ token: 1 }, { unique: true });
    await RefreshToken.collection.createIndex({ userId: 1, deviceId: 1 });
    await RefreshToken.collection.createIndex({ token: 1, isRevoked: 1 });
    await RefreshToken.collection.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 });
    
    console.log('✅ RefreshToken indexes created successfully');
    
    // Clean up any existing expired tokens
    const result = await RefreshToken.deleteMany({
      expiresAt: { $lt: new Date() }
    });
    
    console.log(`✅ Cleaned up ${result.deletedCount} expired refresh tokens`);
    
    console.log('✅ RefreshToken setup completed successfully');
    
  } catch (error) {
    console.error('❌ Error setting up RefreshTokens:', error);
  } finally {
    await mongoose.disconnect();
    console.log('Disconnected from MongoDB');
  }
}

// Run the setup if this file is executed directly
if (require.main === module) {
  setupRefreshTokens();
}

module.exports = setupRefreshTokens;
