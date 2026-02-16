const { cleanupExpiredOffers } = require('../controllers/offerController');

let offerCleanupInterval = null;

const runCleanup = async () => {
  try {
    const result = await cleanupExpiredOffers();
    if (result.deletedOffers > 0 || result.deletedClaims > 0) {
      console.log(
        `[OfferCleanup] Deleted ${result.deletedOffers} expired offers and ${result.deletedClaims} related claims`
      );
    }
  } catch (error) {
    console.error('[OfferCleanup] Failed:', error.message);
  }
};

const initializeOfferCleanupScheduler = () => {
  if (offerCleanupInterval) return;

  runCleanup();
  offerCleanupInterval = setInterval(runCleanup, 60 * 60 * 1000);
  console.log('[OfferCleanup] Scheduler initialized (hourly)');
};

module.exports = {
  initializeOfferCleanupScheduler,
};
