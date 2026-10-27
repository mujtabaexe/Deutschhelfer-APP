// Deutschhelfer trusted backend (Cloud Functions, 2nd gen).
//
// Security notes:
// - The Admin SDK bypasses Firestore Rules. Every callable re-checks the
//   caller's identity, verification and role before acting.
// - Logs never contain message text, emails or purchase tokens.
// - maxInstances caps concurrency as a cost control.
//
// Deploying requires the Blaze plan. Everything here runs in the emulator.

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getMessaging } from 'firebase-admin/messaging';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { setGlobalOptions } from 'firebase-functions/v2';
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
  onDocumentWritten,
} from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onMessagePublished } from 'firebase-functions/v2/pubsub';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { defineBoolean, defineString } from 'firebase-functions/params';
import * as logger from 'firebase-functions/logger';

import {
  MAX_DEVICES_PER_USER,
  RequestError,
  claimsWithPremium,
  claimsWithRole,
  directMessageNotification,
  entitlementFromPlay,
  isDeviceToken,
  moderationNotification,
  parseProductTiers,
  recipientOf,
  requireCaller,
  requireRecentAuth,
  sha256,
  staleTokens,
  validatePurchaseRequest,
  validateRoleRequest,
  validateUid,
} from './src/logic.js';
import { deleteAccountNow, purgeDueAccounts } from './src/account.js';
import { createPlayClient, defaultAccessToken } from './src/play.js';

initializeApp();
const db = getFirestore();

// Region is provisional (open question): keep it next to the Firestore
// database location chosen by the owner.
const REGION = 'asia-southeast1';
setGlobalOptions({ region: REGION, maxInstances: 10 });

const ENFORCE_APP_CHECK = defineBoolean('ENFORCE_APP_CHECK', { default: true });
const PLAY_PACKAGE_NAME = defineString('PLAY_PACKAGE_NAME', { default: '' });
const PRODUCT_TIERS = defineString('PRODUCT_TIERS', { default: '{}' });
// FCM has no emulator; .env.local turns sending off for local runs.
const PUSH_ENABLED = defineBoolean('PUSH_ENABLED', { default: true });

// ---------- Helpers ----------

/** Wraps a callable: App Check, error mapping, no leaking internals. */
function callable(handler) {
  return onCall(async (request) => {
    if (ENFORCE_APP_CHECK.value() && !request.app) {
      throw new HttpsError('failed-precondition', 'App verification failed.');
    }
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof RequestError) throw new HttpsError(error.code, error.message);
      logger.error('Callable failed', { name: error?.name, status: error?.status });
      throw new HttpsError('internal', 'Something went wrong.');
    }
  });
}

/** Staff powers lapse while the staff account itself is restricted. */
async function assertNotRestricted(uid) {
  if ((await db.doc(`accountRestrictions/${uid}`).get()).exists) {
    throw new HttpsError('permission-denied', 'Not allowed.');
  }
}

function audit(actorId, action, targetType, targetId, details = {}) {
  return db.collection('auditLogs').add({
    actorId,
    action,
    targetType,
    targetId,
    details,
    createdAt: FieldValue.serverTimestamp(),
  });
}

// ---------- Member counts ----------

// Triggers can be delivered more than once, so each event is applied once
// through a marker document. Give `processedEvents.expireAt` a TTL policy.
function countOnce(eventId, groupId, delta) {
  const marker = db.doc(`processedEvents/${eventId}`);
  return db.runTransaction(async (tx) => {
    if ((await tx.get(marker)).exists) return;
    tx.set(marker, {
      expireAt: Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });
    tx.update(db.doc(`groups/${groupId}`), { memberCount: FieldValue.increment(delta) });
  });
}

export const onMemberCreated = onDocumentCreated('groups/{groupId}/members/{uid}', (event) =>
  countOnce(event.id, event.params.groupId, 1),
);

export const onMemberDeleted = onDocumentDeleted('groups/{groupId}/members/{uid}', (event) =>
  countOnce(event.id, event.params.groupId, -1),
);

// ---------- Audit trail ----------

export const onGroupMessageModerated = onDocumentUpdated(
  'groups/{groupId}/messages/{messageId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (before.status === after.status || !after.moderatedBy) return;
    if (after.status !== 'visible' && after.status !== 'removed') return;
    await audit(
      after.moderatedBy,
      after.status === 'visible' ? 'message.approve' : 'message.remove',
      'groupMessage',
      `${event.params.groupId}/${event.params.messageId}`,
      { senderId: after.senderId },
    );
    if (!(await db.doc(`accountRestrictions/${after.senderId}`).get()).exists) {
      await notify(
        after.senderId,
        moderationNotification(before.status, after.status, event.params.groupId),
      );
    }
  },
);

export const onRestrictionWritten = onDocumentWritten('accountRestrictions/{uid}', async (event) => {
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (after?.status !== 'suspended' || !after.updatedBy) return;
  const before = event.data.before.exists ? event.data.before.data() : null;
  if (before?.status === 'suspended' && before.reason === after.reason) return;
  await audit(after.updatedBy, 'account.suspend', 'user', event.params.uid, {
    reason: after.reason,
  });
});

export const onReportResolved = onDocumentUpdated('reports/{reportId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status !== 'open' || after.status === 'open' || !after.resolvedBy) return;
  await audit(after.resolvedBy, `report.${after.status}`, 'report', event.params.reportId, {
    targetUserId: after.targetUserId,
  });
});

// ---------- Push notifications ----------

/**
 * Sends to the user's most recently registered devices and deletes tokens
 * FCM reports as gone. Never throws: a failed notification must not fail
 * the write that caused it. Logs carry counts only.
 */
async function notify(uid, payload) {
  if (!PUSH_ENABLED.value() || !payload || typeof uid !== 'string' || !uid) return;
  try {
    const devices = await db
      .collection(`users/${uid}/devices`)
      .orderBy('updatedAt', 'desc')
      .limit(MAX_DEVICES_PER_USER)
      .get();
    const tokens = devices.docs.map((doc) => doc.id).filter(isDeviceToken);
    if (tokens.length === 0) return;
    const result = await getMessaging().sendEachForMulticast({ ...payload, tokens });
    const stale = staleTokens(tokens, result.responses);
    await Promise.all(stale.map((token) => db.doc(`users/${uid}/devices/${token}`).delete()));
    logger.info('Push sent', {
      sent: result.successCount,
      failed: result.failureCount,
      pruned: stale.length,
    });
  } catch (error) {
    logger.warn('Push failed', { name: error?.name, code: error?.code });
  }
}

/**
 * A token belongs to one device, so it belongs to the account that
 * registered it last. This removes it from any other account (a shared
 * phone whose previous user never signed out in the app) and trims the
 * user's devices to the newest ten.
 */
export const onDeviceRegistered = onDocumentCreated('users/{uid}/devices/{token}', async (event) => {
  const { uid, token } = event.params;
  const [sameToken, devices] = await Promise.all([
    db.collectionGroup('devices').where('token', '==', token).get(),
    // Bounded read. Each registration removes up to 20 extras, so even a
    // flood of documents shrinks back to ten.
    db.collection(`users/${uid}/devices`)
      .orderBy('updatedAt', 'desc')
      .limit(MAX_DEVICES_PER_USER + 20)
      .get(),
  ]);
  // Triggers can run late or out of order, so the newest registration wins
  // by its stored time, not by which trigger runs last. Ties keep the
  // larger uid, so two triggers never delete each other's document.
  const mine = event.data.data();
  const rank = (data, owner) => [data?.updatedAt?.toMillis?.() ?? 0, owner];
  const newer = ([t1, u1], [t2, u2]) => t1 > t2 || (t1 === t2 && u1 > u2);
  const writer = db.bulkWriter();
  writer.onWriteError(() => false);
  for (const doc of sameToken.docs) {
    const owner = doc.ref.parent.parent?.id;
    if (!owner || owner === uid) continue;
    const loser = newer(rank(mine, uid), rank(doc.data(), owner)) ? doc.ref : event.data.ref;
    writer.delete(loser).catch(() => {});
  }
  for (const doc of devices.docs.slice(MAX_DEVICES_PER_USER)) {
    writer.delete(doc.ref).catch(() => {});
  }
  await writer.close();
});

export const onDirectMessageCreated = onDocumentCreated(
  'conversations/{conversationId}/directMessages/{messageId}',
  async (event) => {
    if (!PUSH_ENABLED.value()) return;
    const senderId = event.data?.data()?.senderId;
    const conversation = await db.doc(`conversations/${event.params.conversationId}`).get();
    const recipient = recipientOf(conversation.data()?.participants, senderId);
    if (!recipient) return;
    // The rules already stop blocked senders; this also covers a block made
    // between the write and this trigger.
    const [sender, blocked, restriction] = await Promise.all([
      db.doc(`users/${senderId}`).get(),
      db.doc(`users/${recipient}/blocked/${senderId}`).get(),
      db.doc(`accountRestrictions/${recipient}`).get(),
    ]);
    if (blocked.exists || restriction.exists) return;
    await notify(
      recipient,
      directMessageNotification(sender.data()?.displayName, event.params.conversationId),
    );
  },
);

// ---------- Profile name sync ----------

export const onProfileUpdated = onDocumentUpdated('users/{uid}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.displayName === after.displayName) return;
  const memberships = await db
    .collectionGroup('members')
    .where('uid', '==', event.params.uid)
    .get();
  const writer = db.bulkWriter();
  // A membership deleted meanwhile (e.g. account deletion) is not an error.
  writer.onWriteError(() => false);
  for (const doc of memberships.docs) {
    writer.update(doc.ref, { displayName: after.displayName }).catch(() => {});
  }
  await writer.close();
});

// ---------- Roles ----------

/** Owner only. Grants or removes the student-admin role. */
export const setUserRole = callable(async (request) => {
  const callerUid = requireCaller(request.auth, { role: 'owner' });
  await assertNotRestricted(callerUid);
  const { uid, role } = validateRoleRequest(request.data, callerUid);
  const user = await getAuth().getUser(uid);
  if (user.customClaims?.role === 'owner') {
    throw new HttpsError('permission-denied', 'The owner role cannot be changed here.');
  }
  await getAuth().setCustomUserClaims(uid, claimsWithRole(user.customClaims, role));
  // The staff marker lets the rules protect staff from student-admins.
  if (role === 'student') {
    await db.doc(`staff/${uid}`).delete();
    // Demotion takes effect now, not when the old token expires.
    await getAuth().revokeRefreshTokens(uid);
  } else {
    await db.doc(`staff/${uid}`).set({ role, updatedAt: FieldValue.serverTimestamp() });
  }
  await audit(callerUid, 'role.set', 'user', uid, { role });
  return { ok: true };
});

// ---------- Suspensions ----------

/** Staff only. Lifts a suspension and records who did it. */
export const liftSuspension = callable(async (request) => {
  const callerUid = requireCaller(request.auth, { role: ['owner', 'student-admin'] });
  await assertNotRestricted(callerUid);
  const uid = validateUid(request.data?.uid);
  if (uid === callerUid) throw new HttpsError('permission-denied', 'Not allowed.');
  if (request.auth.token.role !== 'owner') {
    // The claim can outlive a demotion by up to an hour; the marker cannot.
    const marker = await db.doc(`staff/${callerUid}`).get();
    if (marker.data()?.role !== 'student-admin') {
      throw new HttpsError('permission-denied', 'Not allowed.');
    }
    // Mirrors the suspend rule: student-admins act on students only, so
    // they cannot undo the owner's suspension of another staff member.
    if ((await db.doc(`staff/${uid}`).get()).exists) {
      throw new HttpsError('permission-denied', 'Not allowed.');
    }
  }
  const ref = db.doc(`accountRestrictions/${uid}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.data()?.status !== 'suspended') {
      throw new HttpsError('failed-precondition', 'This account is not suspended.');
    }
    tx.delete(ref);
  });
  await audit(callerUid, 'account.unsuspend', 'user', uid);
  return { ok: true };
});

// ---------- Account deletion ----------

/**
 * The signed-in user deletes their own account. Personal data is removed
 * or anonymized now; remaining records are purged after the retention period.
 * Verification is not required, so unverified accounts can also be deleted.
 */
export const deleteMyAccount = callable(async (request) => {
  const uid = requireCaller(request.auth, { verified: false });
  // A stolen or stale token must not be enough to delete an account.
  requireRecentAuth(request.auth);
  await deleteAccountNow({ db, auth: getAuth(), uid, actorId: uid });
  return { ok: true };
});

/** Daily: permanently removes accounts past the retention period. */
export const purgeDeletedAccounts = onSchedule('every day 03:00', async () => {
  const purged = await purgeDueAccounts({ db, auth: getAuth() });
  logger.info('Purge finished', { purged });
});

// ---------- Subscriptions (Phase 6 integration boundary) ----------

function playClient() {
  const packageName = PLAY_PACKAGE_NAME.value();
  if (!packageName) {
    throw new HttpsError('failed-precondition', 'Subscriptions are not configured yet.');
  }
  return createPlayClient({ packageName, getAccessToken: defaultAccessToken });
}

async function applyEntitlement(uid, purchaseToken, purchase) {
  const tiers = parseProductTiers(PRODUCT_TIERS.value());
  const entitlement = entitlementFromPlay(purchase, { now: new Date(), tiers, uid });
  // Nothing is written for a purchase bound to a different account, so a
  // leaked token cannot be claimed away from its buyer.
  if (!entitlement.accountMatches) return entitlement;

  const tokenRef = db.doc(`purchaseTokens/${sha256(purchaseToken)}`);
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(tokenRef);
    if (existing.exists && existing.data().uid !== uid) {
      throw new HttpsError('permission-denied', 'This purchase belongs to another account.');
    }
    tx.set(
      tokenRef,
      { uid, token: purchaseToken, productId: entitlement.productId, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
  });

  await db.doc(`subscriptions/${uid}`).set({
    tier: entitlement.tier,
    status: entitlement.premium || entitlement.adFree ? 'active' : 'inactive',
    playState: entitlement.state,
    productId: entitlement.productId,
    expiresAt: entitlement.expiresAt ? Timestamp.fromDate(entitlement.expiresAt) : null,
    testPurchase: entitlement.testPurchase,
    updatedAt: FieldValue.serverTimestamp(),
  });

  const user = await getAuth().getUser(uid);
  await getAuth().setCustomUserClaims(uid, claimsWithPremium(user.customClaims, entitlement.premium));
  return entitlement;
}

/**
 * Verifies a Google Play purchase server-side and grants the entitlement.
 * The client never sets premium status itself.
 */
export const verifyPurchase = callable(async (request) => {
  const uid = requireCaller(request.auth);
  const { token, productId } = validatePurchaseRequest(request.data);
  const play = playClient();

  // A purchase token may unlock exactly one account.
  const tokenRef = db.doc(`purchaseTokens/${sha256(token)}`);
  const existing = await tokenRef.get();
  if (existing.exists && existing.data().uid !== uid) {
    throw new HttpsError('permission-denied', 'This purchase belongs to another account.');
  }

  const purchase = await play.getSubscription(token);
  const entitlement = await applyEntitlement(uid, token, purchase);
  if (!entitlement.accountMatches) {
    throw new HttpsError('permission-denied', 'This purchase belongs to another account.');
  }
  if (entitlement.needsAcknowledgement && (entitlement.premium || entitlement.adFree)) {
    await play.acknowledge(productId, token);
  }
  await audit(uid, 'subscription.verified', 'user', uid, {
    tier: entitlement.tier,
    state: entitlement.state,
  });
  return {
    premium: entitlement.premium,
    adFree: entitlement.adFree,
    expiresAt: entitlement.expiresAt?.toISOString() ?? null,
  };
});

/** Real-time developer notifications from Google Play (Pub/Sub topic). */
export const onPlayNotification = onMessagePublished('play-rtdn', async (event) => {
  const token = event.data.message.json?.subscriptionNotification?.purchaseToken;
  if (typeof token !== 'string') return;
  const mapping = await db.doc(`purchaseTokens/${sha256(token)}`).get();
  const uid = mapping.data()?.uid;
  if (!uid) return; // Not verified by our app yet; the client will call verifyPurchase.
  const purchase = await playClient().getSubscription(token);
  await applyEntitlement(uid, token, purchase);
});

/** Daily safety net: re-checks subscriptions that are due to expire. */
export const reconcileSubscriptions = onSchedule('every day 04:00', async () => {
  if (!PLAY_PACKAGE_NAME.value()) return;
  const soon = Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000));
  const due = await db
    .collection('subscriptions')
    .where('status', '==', 'active')
    .where('expiresAt', '<=', soon)
    .limit(500)
    .get();
  const play = playClient();
  for (const doc of due.docs) {
    const tokens = await db.collection('purchaseTokens').where('uid', '==', doc.id).limit(1).get();
    const token = tokens.docs[0]?.data().token;
    if (!token) continue;
    try {
      await applyEntitlement(doc.id, token, await play.getSubscription(token));
    } catch (error) {
      logger.warn('Reconcile failed for one subscription', { status: error?.status });
    }
  }
});
