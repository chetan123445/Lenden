function validateCoinCreationAccess({
  subscribed,
  freeRemaining,
  dailyCount,
  dailyLimit,
  dailyLimitMessage,
  coinBalance,
  coinCost,
  featureLabel,
}) {
  const dailyLimitExceeded =
    typeof dailyCount === 'number' && dailyCount >= dailyLimit;

  if (subscribed) {
    return {
      status: 409,
      error: `Your active subscription already includes unlimited ${featureLabel}. Use the regular create option instead of spending LenDen coins.`,
    };
  }

  if (dailyLimitExceeded) {
    if (typeof coinBalance === 'number' && coinBalance < coinCost) {
      return {
        status: 403,
        error: 'Insufficient LenDen coins.',
      };
    }

    return {
      warning: `${dailyLimitMessage} You can still continue by spending LenDen coins for this extra ${featureLabel}.`,
    };
  }

  if (typeof freeRemaining === 'number' && freeRemaining > 0) {
    const noun = freeRemaining === 1 ? 'attempt' : 'attempts';
    return {
      status: 409,
      error: `You still have ${freeRemaining} free ${featureLabel} ${noun} remaining today. Use those before spending LenDen coins.`,
    };
  }

  if (typeof coinBalance === 'number' && coinBalance < coinCost) {
    return {
      status: 403,
      error: 'Insufficient LenDen coins.',
    };
  }

  return null;
}

module.exports = {
  validateCoinCreationAccess,
};
