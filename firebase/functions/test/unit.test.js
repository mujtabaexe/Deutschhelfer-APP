import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  MAX_DEVICES_PER_USER,
  RequestError,
  accountHash,
  claimsWithPremium,
  claimsWithRole,
  directMessageNotification,
  entitlementFromPlay,
  isDeviceToken,
  moderationNotification,
  parseProductTiers,
  purgeDate,
  recipientOf,
  requireCaller,
  requireRecentAuth,
  staleTokens,
  validatePurchaseRequest,
  validateRoleRequest,
} from '../src/logic.js';
import { createPlayClient } from '../src/play.js';

const owner = { uid: 'owner1', token: { email_verified: true, role: 'owner' } };
const student = { uid: 'stud1', token: { email_verified: true } };
const unverifiedOwner = { uid: 'owner1', token: { email_verified: false, role: 'owner' } };

function rejects(fn, code) {
  assert.throws(fn, (error) => error instanceof RequestError && error.code === code);
}

describe('caller checks', () => {
  it('requires a signed-in, verified caller with the right role', () => {
    assert.equal(requireCaller(owner, { role: 'owner' }), 'owner1');
    rejects(() => requireCaller(null, { role: 'owner' }), 'unauthenticated');
    rejects(() => requireCaller(student, { role: 'owner' }), 'permission-denied');
    rejects(() => requireCaller(unverifiedOwner, { role: 'owner' }), 'permission-denied');
    assert.equal(requireCaller(student), 'stud1');
  });

  it('accepts any of several roles', () => {
    const admin = { uid: 'a', token: { email_verified: true, role: 'student-admin' } };
    assert.equal(requireCaller(admin, { role: ['owner', 'student-admin'] }), 'a');
    rejects(() => requireCaller(student, { role: ['owner', 'student-admin'] }), 'permission-denied');
  });

  it('can skip verification for self-service account deletion', () => {
    const fresh = { uid: 'new1', token: { email_verified: false } };
    assert.equal(requireCaller(fresh, { verified: false }), 'new1');
  });
});

describe('role changes', () => {
  it('accepts grantable roles for other users', () => {
    assert.deepEqual(validateRoleRequest({ uid: 'abc123', role: 'student-admin' }, 'owner1'), {
      uid: 'abc123',
      role: 'student-admin',
    });
  });

  it('never grants owner, rejects bad ids and self-changes', () => {
    rejects(() => validateRoleRequest({ uid: 'abc', role: 'owner' }, 'owner1'), 'invalid-argument');
    rejects(() => validateRoleRequest({ uid: '../x', role: 'student' }, 'owner1'), 'invalid-argument');
    rejects(() => validateRoleRequest({ uid: 'owner1', role: 'student' }, 'owner1'), 'permission-denied');
    rejects(() => validateRoleRequest(null, 'owner1'), 'invalid-argument');
  });

  it('keeps unrelated claims when changing roles', () => {
    assert.deepEqual(claimsWithRole({ premium: true }, 'student-admin'), {
      premium: true,
      role: 'student-admin',
    });
    assert.deepEqual(claimsWithRole({ premium: true, role: 'student-admin' }, 'student'), {
      premium: true,
    });
    assert.deepEqual(claimsWithPremium({ role: 'owner', premium: true }, false), { role: 'owner' });
  });
});

describe('recent sign-in', () => {
  const now = Date.parse('2026-06-01T12:00:00Z');
  const at = (secondsAgo) => ({ uid: 'u', token: { auth_time: now / 1000 - secondsAgo } });

  it('accepts a sign-in from the last five minutes', () => {
    requireRecentAuth(at(60), now);
  });

  it('rejects old or missing sign-in times', () => {
    rejects(() => requireRecentAuth(at(301), now), 'failed-precondition');
    rejects(() => requireRecentAuth({ uid: 'u', token: {} }, now), 'failed-precondition');
  });
});

describe('retention', () => {
  it('purges 90 days after the request', () => {
    const now = new Date('2026-01-01T00:00:00Z');
    assert.equal(purgeDate(now).toISOString(), '2026-04-01T00:00:00.000Z');
  });
});

describe('subscriptions', () => {
  const now = new Date('2026-06-01T00:00:00Z');
  const tiers = { premium_monthly: 'premium', adfree_monthly: 'adFree' };
  const purchase = (overrides = {}) => ({
    subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
    acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
    externalAccountIdentifiers: { obfuscatedExternalAccountId: accountHash('u1') },
    lineItems: [{ productId: 'premium_monthly', expiryTime: '2026-07-01T00:00:00Z' }],
    ...overrides,
  });

  it('grants premium for an active, unexpired, bound purchase', () => {
    const e = entitlementFromPlay(purchase(), { now, tiers, uid: 'u1' });
    assert.equal(e.premium, true);
    assert.equal(e.adFree, true);
    assert.equal(e.needsAcknowledgement, true);
    assert.equal(e.expiresAt.toISOString(), '2026-07-01T00:00:00.000Z');
  });

  it('keeps access after cancellation until the paid period ends', () => {
    const e = entitlementFromPlay(purchase({ subscriptionState: 'SUBSCRIPTION_STATE_CANCELED' }), {
      now,
      tiers,
      uid: 'u1',
    });
    assert.equal(e.premium, true);
  });

  it('denies expired, on-hold, paused, pending and unknown states', () => {
    for (const subscriptionState of [
      'SUBSCRIPTION_STATE_EXPIRED',
      'SUBSCRIPTION_STATE_ON_HOLD',
      'SUBSCRIPTION_STATE_PAUSED',
      'SUBSCRIPTION_STATE_PENDING',
      'SOMETHING_NEW',
      undefined,
    ]) {
      const e = entitlementFromPlay(purchase({ subscriptionState }), { now, tiers, uid: 'u1' });
      assert.equal(e.premium, false, String(subscriptionState));
    }
  });

  it('denies a purchase bound to another account (token sharing)', () => {
    const e = entitlementFromPlay(purchase(), { now, tiers, uid: 'someone-else' });
    assert.equal(e.premium, false);
    assert.equal(e.accountMatches, false);
  });

  it('denies past expiry, unknown products and malformed input', () => {
    const expired = purchase({
      lineItems: [{ productId: 'premium_monthly', expiryTime: '2026-05-01T00:00:00Z' }],
    });
    assert.equal(entitlementFromPlay(expired, { now, tiers, uid: 'u1' }).premium, false);
    const unknown = purchase({
      lineItems: [{ productId: 'mystery', expiryTime: '2026-07-01T00:00:00Z' }],
    });
    assert.equal(entitlementFromPlay(unknown, { now, tiers, uid: 'u1' }).premium, false);
    assert.equal(entitlementFromPlay(null, { now, tiers, uid: 'u1' }).premium, false);
    assert.equal(
      entitlementFromPlay(purchase({ lineItems: [{ expiryTime: 'not a date' }] }), {
        now,
        tiers,
        uid: 'u1',
      }).premium,
      false,
    );
  });

  it('an ad-free product does not unlock premium content', () => {
    const e = entitlementFromPlay(
      purchase({ lineItems: [{ productId: 'adfree_monthly', expiryTime: '2026-07-01T00:00:00Z' }] }),
      { now, tiers, uid: 'u1' },
    );
    assert.equal(e.premium, false);
    assert.equal(e.adFree, true);
  });

  it('validates purchase requests and product configuration', () => {
    assert.deepEqual(validatePurchaseRequest({ purchaseToken: 'x'.repeat(20), productId: 'premium_monthly' }), {
      token: 'x'.repeat(20),
      productId: 'premium_monthly',
    });
    rejects(() => validatePurchaseRequest({ purchaseToken: 'short', productId: 'p' }), 'invalid-argument');
    rejects(() => validatePurchaseRequest({ purchaseToken: 'x'.repeat(20), productId: 'BAD ID' }), 'invalid-argument');
    assert.deepEqual(parseProductTiers('{"a":"premium","b":"gold"}'), { a: 'premium' });
    rejects(() => parseProductTiers('{not json'), 'failed-precondition');
  });

  it('the Play client never puts the token in error messages', async () => {
    const client = createPlayClient({
      packageName: 'com.deutschhelfer.app',
      getAccessToken: async () => 'access',
      fetchImpl: async () => ({ ok: false, status: 410 }),
    });
    await assert.rejects(client.getSubscription('secret-token-123'), (error) => {
      assert.equal(error.status, 410);
      assert.equal(error.message.includes('secret-token-123'), false);
      return true;
    });
  });

  it('the Play client calls the documented endpoint with a bearer token', async () => {
    const seen = [];
    const client = createPlayClient({
      packageName: 'com.deutschhelfer.app',
      getAccessToken: async () => 'access',
      fetchImpl: async (url, init) => {
        seen.push({ url, init });
        return { ok: true, json: async () => ({ subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE' }) };
      },
    });
    await client.getSubscription('tok/en');
    assert.equal(
      seen[0].url,
      'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.deutschhelfer.app/purchases/subscriptionsv2/tokens/tok%2Fen',
    );
    assert.equal(seen[0].init.headers.Authorization, 'Bearer access');
  });
});

describe('push notifications', () => {
  it('never put message text in a direct-message notification', () => {
    const payload = directMessageNotification('Ali Raza', 'alice_bob');
    assert.deepEqual(payload.notification, { title: 'Ali Raza', body: 'Sent you a message' });
    assert.deepEqual(payload.data, { type: 'dm', conversationId: 'alice_bob' });
    assert.equal(JSON.stringify(payload).includes('text'), false);
  });

  it('clean and shorten the sender name, with a neutral fallback', () => {
    assert.equal(directMessageNotification('', 'a_b').notification.title, 'Deutschhelfer');
    assert.equal(directMessageNotification(undefined, 'a_b').notification.title, 'Deutschhelfer');
    assert.equal(directMessageNotification('Ali\u0007\u0000', 'a_b').notification.title, 'Ali');
    const long = directMessageNotification('x'.repeat(80), 'a_b').notification.title;
    assert.equal(long.length, 40);
    assert.ok(long.endsWith('…'));
  });

  it('refuse odd ids instead of building a payload', () => {
    assert.equal(directMessageNotification('Ali', '../x'), null);
    assert.equal(directMessageNotification('Ali', ''), null);
    assert.equal(directMessageNotification('Ali', undefined), null);
    assert.equal(moderationNotification('pending', 'visible', 'g/1'), null);
  });

  it('describe only real moderation decisions', () => {
    assert.match(moderationNotification('pending', 'visible', 'g1').notification.body, /approved/);
    assert.match(moderationNotification('pending', 'removed', 'g1').notification.body, /did not approve/);
    assert.match(moderationNotification('visible', 'removed', 'g1').notification.body, /removed/);
    assert.deepEqual(moderationNotification('pending', 'visible', 'g1').data, { type: 'moderation', groupId: 'g1' });
    assert.equal(moderationNotification('visible', 'withdrawn', 'g1'), null);
    assert.equal(moderationNotification('removed', 'visible', 'g1'), null);
  });

  it('find the other participant only when the sender is one of two', () => {
    assert.equal(recipientOf(['alice', 'bob'], 'alice'), 'bob');
    assert.equal(recipientOf(['alice', 'bob'], 'bob'), 'alice');
    assert.equal(recipientOf(['alice', 'bob'], 'carol'), null);
    assert.equal(recipientOf(['alice', 'alice'], 'alice'), null);
    assert.equal(recipientOf(['alice'], 'alice'), null);
    assert.equal(recipientOf(undefined, 'alice'), null);
  });

  it('prune only tokens FCM reports as gone', () => {
    const tokens = ['t1', 't2', 't3', 't4', 't5'];
    const fail = (code) => ({ success: false, error: { code } });
    const responses = [
      { success: true },
      fail('messaging/registration-token-not-registered'),
      fail('messaging/server-unavailable'),
      fail('messaging/invalid-registration-token'),
      fail('messaging/invalid-argument'),
    ];
    assert.deepEqual(staleTokens(tokens, responses), ['t2', 't4']);
    assert.deepEqual(staleTokens(tokens, undefined), []);
  });

  it('accept only token-shaped device ids, and cap devices per user', () => {
    assert.equal(isDeviceToken('fcm-Token_1234567890:abcDEF'), true);
    assert.equal(isDeviceToken('short'), false);
    assert.equal(isDeviceToken('has/slash/1234567890123'), false);
    assert.equal(isDeviceToken(42), false);
    assert.equal(MAX_DEVICES_PER_USER, 10);
  });
});
