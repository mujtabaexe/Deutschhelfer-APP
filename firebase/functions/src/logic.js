// Pure decision logic for the trusted backend. No Firebase imports, so it is
// unit-tested directly (test/unit.test.js).

import { createHash } from 'node:crypto';

export class RequestError extends Error {
  /** @param {'invalid-argument'|'permission-denied'|'failed-precondition'|'unauthenticated'} code */
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

/** Roles the owner may grant through the app. 'owner' is granted only with
 * the local bootstrap script, never through a callable. */
export const GRANTABLE_ROLES = ['student', 'student-admin'];

const UID_PATTERN = /^[A-Za-z0-9]{1,128}$/;

/** Authorization shared by every privileged callable. */
export function requireCaller(auth, { role, verified = true } = {}) {
  if (!auth?.uid) throw new RequestError('unauthenticated', 'Sign in first.');
  if (verified && auth.token?.email_verified !== true) {
    throw new RequestError('permission-denied', 'Verify your email first.');
  }
  if (role) {
    const allowed = Array.isArray(role) ? role : [role];
    if (!allowed.includes(auth.token?.role)) {
      throw new RequestError('permission-denied', 'Not allowed.');
    }
  }
  return auth.uid;
}

export function validateRoleRequest(data, callerUid) {
  const uid = data?.uid;
  const role = data?.role;
  if (typeof uid !== 'string' || !UID_PATTERN.test(uid)) {
    throw new RequestError('invalid-argument', 'A valid user id is required.');
  }
  if (!GRANTABLE_ROLES.includes(role)) {
    throw new RequestError('invalid-argument', 'Unknown role.');
  }
  if (uid === callerUid) {
    throw new RequestError('permission-denied', 'You cannot change your own role.');
  }
  return { uid, role };
}

/** Returns new custom claims with the role applied and other claims kept. */
export function claimsWithRole(existing, role) {
  const claims = { ...(existing ?? {}) };
  if (role === 'student') delete claims.role;
  else claims.role = role;
  return claims;
}

export function claimsWithPremium(existing, premium) {
  const claims = { ...(existing ?? {}) };
  if (premium) claims.premium = true;
  else delete claims.premium;
  return claims;
}

export function validateUid(value) {
  if (typeof value !== 'string' || !UID_PATTERN.test(value)) {
    throw new RequestError('invalid-argument', 'A valid user id is required.');
  }
  return value;
}

/** Sensitive actions need a sign-in no older than this. */
export const RECENT_AUTH_SECONDS = 5 * 60;

export function requireRecentAuth(auth, nowMs = Date.now()) {
  const authTime = Number(auth?.token?.auth_time);
  if (!Number.isFinite(authTime) || nowMs / 1000 - authTime > RECENT_AUTH_SECONDS) {
    throw new RequestError('failed-precondition', 'Sign in again to continue.');
  }
}

/** Days deleted-account data is kept before purge (blueprint: 3 months). */
export const RETENTION_DAYS = 90;

export function purgeDate(now) {
  return new Date(now.getTime() + RETENTION_DAYS * 24 * 60 * 60 * 1000);
}

// ---------- Push notifications ----------

/** Devices notified per user. Bounds reads and sends even if a client
 * registers many device documents. */
export const MAX_DEVICES_PER_USER = 10;

const PUSH_ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const DEVICE_TOKEN_PATTERN = /^[A-Za-z0-9_:-]{20,512}$/;
const MAX_TITLE_LENGTH = 40;

/** Device tokens come from client-written document ids. */
export function isDeviceToken(value) {
  return typeof value === 'string' && DEVICE_TOKEN_PATTERN.test(value);
}

function title(name) {
  const clean = typeof name === 'string' ? name.replace(/[\u0000-\u001F\u007F-\u009F]/g, '').trim() : '';
  if (!clean) return 'Deutschhelfer';
  return clean.length > MAX_TITLE_LENGTH ? `${clean.slice(0, MAX_TITLE_LENGTH - 1)}…` : clean;
}

/** The other participant of a two-person conversation, or null. */
export function recipientOf(participants, senderId) {
  if (!Array.isArray(participants) || participants.length !== 2) return null;
  if (!participants.includes(senderId)) return null;
  const other = participants.find((id) => id !== senderId);
  return typeof other === 'string' && other ? other : null;
}

/**
 * A new direct message. The notification never carries the message text:
 * lock screens and notification history are visible to other people.
 */
export function directMessageNotification(senderName, conversationId) {
  if (!PUSH_ID_PATTERN.test(conversationId ?? '')) return null;
  return {
    notification: { title: title(senderName), body: 'Sent you a message' },
    data: { type: 'dm', conversationId },
    android: { priority: 'high', collapseKey: `dm_${conversationId}`, notification: { tag: `dm_${conversationId}` } },
  };
}

/** A moderator's decision on the recipient's own group message, or null when
 * the change is not one to tell them about. */
export function moderationNotification(beforeStatus, afterStatus, groupId) {
  if (!PUSH_ID_PATTERN.test(groupId ?? '')) return null;
  let body;
  if (beforeStatus === 'pending' && afterStatus === 'visible') {
    body = 'A moderator approved your message.';
  } else if (beforeStatus === 'pending' && afterStatus === 'removed') {
    body = 'A moderator did not approve your message.';
  } else if (beforeStatus === 'visible' && afterStatus === 'removed') {
    body = 'A moderator removed one of your messages.';
  } else {
    return null;
  }
  return {
    notification: { title: 'Deutschhelfer', body },
    data: { type: 'moderation', groupId },
    android: { notification: { tag: `moderation_${groupId}` } },
  };
}

const STALE_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/installation-id-not-registered',
]);

/** Tokens FCM reports as gone, to delete. Other failures (quota, outage,
 * a bad payload) keep the token. */
export function staleTokens(tokens, responses) {
  return tokens.filter((_, i) => {
    const response = responses?.[i];
    return response && !response.success && STALE_TOKEN_CODES.has(response.error?.code);
  });
}

// ---------- Subscriptions ----------

export function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

/** The value the app passes to Google Play as the obfuscated account id, so
 * a purchase token can be tied to exactly one Deutschhelfer account. */
export function accountHash(uid) {
  return sha256(`deutschhelfer:${uid}`);
}

export function validatePurchaseRequest(data) {
  const token = data?.purchaseToken;
  const productId = data?.productId;
  if (typeof token !== 'string' || token.length < 10 || token.length > 4096) {
    throw new RequestError('invalid-argument', 'A purchase token is required.');
  }
  if (typeof productId !== 'string' || !/^[a-z0-9._]{1,100}$/.test(productId)) {
    throw new RequestError('invalid-argument', 'A product id is required.');
  }
  return { token, productId };
}

/** Parses the PRODUCT_TIERS parameter, e.g. {"premium_monthly":"premium"}. */
export function parseProductTiers(json) {
  if (!json) return {};
  let parsed;
  try {
    parsed = JSON.parse(json);
  } catch {
    throw new RequestError('failed-precondition', 'PRODUCT_TIERS is not valid JSON.');
  }
  const tiers = {};
  for (const [productId, tier] of Object.entries(parsed ?? {})) {
    if (['premium', 'adFree'].includes(tier)) tiers[productId] = tier;
  }
  return tiers;
}

const ENTITLED_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  // Cancelled subscriptions stay entitled until the paid period ends.
  'SUBSCRIPTION_STATE_CANCELED',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
]);

/**
 * Maps a Google Play SubscriptionPurchaseV2 resource to an entitlement.
 * Unknown or malformed input never grants access.
 */
export function entitlementFromPlay(purchase, { now, tiers, uid }) {
  const state = purchase?.subscriptionState ?? 'SUBSCRIPTION_STATE_UNSPECIFIED';
  const items = Array.isArray(purchase?.lineItems) ? purchase.lineItems : [];
  let best = null;
  for (const item of items) {
    const expires = item?.expiryTime ? new Date(item.expiryTime) : null;
    if (!expires || Number.isNaN(expires.getTime())) continue;
    if (!best || expires > best.expires) best = { productId: item.productId, expires };
  }

  const tier = best ? tiers[best.productId] ?? null : null;
  const boundAccount = purchase?.externalAccountIdentifiers?.obfuscatedExternalAccountId;
  const accountMatches = boundAccount === accountHash(uid);
  const entitled =
    ENTITLED_STATES.has(state) &&
    best !== null &&
    best.expires > now &&
    tier !== null &&
    accountMatches;

  return {
    state,
    productId: best?.productId ?? null,
    tier,
    expiresAt: best?.expires ?? null,
    premium: entitled && tier === 'premium',
    adFree: entitled && (tier === 'premium' || tier === 'adFree'),
    accountMatches,
    needsAcknowledgement:
      purchase?.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING',
    testPurchase: Boolean(purchase?.testPurchase),
  };
}
