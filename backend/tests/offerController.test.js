const { __testables } = require('../src/controllers/offerController');

describe('offerController helpers', () => {
  const { computeOfferStatus, normalizeStatus } = __testables;

  test('normalizeStatus handles known values', () => {
    expect(normalizeStatus('ACTIVE')).toBe('active');
    expect(normalizeStatus(' draft ')).toBe('draft');
    expect(normalizeStatus('unknown')).toBeNull();
  });

  test('computeOfferStatus returns draft when inactive', () => {
    const now = new Date();
    const startsAt = new Date(now.getTime() - 60 * 1000);
    const endsAt = new Date(now.getTime() + 60 * 1000);
    expect(computeOfferStatus({ startsAt, endsAt, isActive: false })).toBe('draft');
  });

  test('computeOfferStatus returns scheduled for future start', () => {
    const now = new Date();
    const startsAt = new Date(now.getTime() + 60 * 60 * 1000);
    const endsAt = new Date(now.getTime() + 2 * 60 * 60 * 1000);
    expect(computeOfferStatus({ startsAt, endsAt, isActive: true })).toBe('scheduled');
  });

  test('computeOfferStatus returns active for current window', () => {
    const now = new Date();
    const startsAt = new Date(now.getTime() - 60 * 1000);
    const endsAt = new Date(now.getTime() + 60 * 1000);
    expect(computeOfferStatus({ startsAt, endsAt, isActive: true })).toBe('active');
  });

  test('computeOfferStatus returns ended for past end', () => {
    const now = new Date();
    const startsAt = new Date(now.getTime() - 2 * 60 * 1000);
    const endsAt = new Date(now.getTime() - 60 * 1000);
    expect(computeOfferStatus({ startsAt, endsAt, isActive: true })).toBe('ended');
  });
});
