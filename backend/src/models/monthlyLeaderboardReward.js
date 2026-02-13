const mongoose = require('mongoose');

const rewardedUserSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    rank: { type: Number, required: true },
    points: { type: Number, required: true },
    coinsAwarded: { type: Number, required: true },
  },
  { _id: false }
);

const monthlyLeaderboardRewardSchema = new mongoose.Schema(
  {
    monthKey: { type: String, required: true, unique: true }, // YYYY-MM
    periodStart: { type: Date, required: true },
    periodEnd: { type: Date, required: true },
    rewardedUsers: [rewardedUserSchema],
    totalCoinsAwarded: { type: Number, default: 0 },
  },
  { timestamps: true }
);

module.exports = mongoose.model(
  'MonthlyLeaderboardReward',
  monthlyLeaderboardRewardSchema
);
