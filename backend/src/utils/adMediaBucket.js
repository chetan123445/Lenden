const mongoose = require('mongoose');

let cachedBucket = null;

const getAdMediaBucket = () => {
  if (!mongoose.connection?.db) {
    throw new Error('MongoDB connection is not ready yet.');
  }

  if (!cachedBucket) {
    cachedBucket = new mongoose.mongo.GridFSBucket(mongoose.connection.db, {
      bucketName: 'appAdsMedia',
    });
  }

  return cachedBucket;
};

module.exports = {
  getAdMediaBucket,
};
