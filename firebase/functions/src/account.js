// Account deletion, shared by the deleteMyAccount callable, the daily purge
// and scripts/delete-account.mjs (for requests from the web deletion page).
//
// Callers authorize first: these functions trust the uid they are given.

import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { purgeDate } from './logic.js';

export const DELETED_NAME = 'Deleted user';

// Firebase Auth uids from email sign-up. Anything else (slashes, dots) could
// address other documents, so it is refused before any write.
const UID_PATTERN = /^[A-Za-z0-9]{1,128}$/;

export function assertUid(uid) {
  if (typeof uid !== 'string' || !UID_PATTERN.test(uid)) {
    throw new Error('Invalid account id.');
  }
}

/**
 * Step 1, at the user's request: removes or anonymizes personal data now,
 * disables the login and queues the rest for the purge. Safe to repeat.
 */
export async function deleteAccountNow({ db, auth, uid, actorId, now = new Date() }) {
  assertUid(uid);
  await db.doc(`accountRestrictions/${uid}`).set({
    status: 'deleted',
    reason: 'Deleted by the user',
    updatedBy: actorId,
    updatedAt: FieldValue.serverTimestamp(),
  });

  const writer = db.bulkWriter();
  // Replaces the whole profile, including the rules acceptance.
  writer.set(db.doc(`users/${uid}`), {
    displayName: DELETED_NAME,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  const memberships = await db.collectionGroup('members').where('uid', '==', uid).get();
  for (const doc of memberships.docs) writer.delete(doc.ref);
  // Past group messages keep their text for context but lose the name.
  const sent = await db.collectionGroup('messages').where('senderId', '==', uid).get();
  for (const doc of sent.docs) writer.update(doc.ref, { senderName: DELETED_NAME });
  const blocked = await db.collection(`users/${uid}/blocked`).get();
  for (const doc of blocked.docs) writer.delete(doc.ref);
  writer.delete(db.doc(`rateLimits/${uid}`));
  writer.set(db.doc(`deletionQueue/${uid}`), {
    requestedAt: Timestamp.fromDate(now),
    purgeAfter: Timestamp.fromDate(purgeDate(now)),
  });
  await writer.close();
  // Paged, so any number of device documents is removed.
  await db.recursiveDelete(db.collection(`users/${uid}/devices`));

  try {
    await auth.updateUser(uid, { disabled: true });
    await auth.revokeRefreshTokens(uid);
  } catch (error) {
    // Already purged by an earlier run.
    if (error?.code !== 'auth/user-not-found') throw error;
  }
  await audit(db, actorId, 'account.delete_requested', uid);
}

/** Step 2, after the retention period: erases what is left. */
export async function purgeAccount({ db, auth, uid }) {
  assertUid(uid);
  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') throw error;
  }
  const writer = db.bulkWriter();
  for (const path of [
    `users/${uid}`,
    `subscriptions/${uid}`,
    `accountRestrictions/${uid}`,
    `staff/${uid}`,
    `rateLimits/${uid}`,
    `deletionQueue/${uid}`,
  ]) {
    writer.delete(db.doc(path));
  }
  const tokens = await db.collection('purchaseTokens').where('uid', '==', uid).get();
  for (const doc of tokens.docs) writer.delete(doc.ref);
  const filed = await db.collection('reports').where('reporterId', '==', uid).get();
  for (const doc of filed.docs) writer.delete(doc.ref);
  await writer.close();
  // Devices and blocks created between the request and the purge.
  await db.recursiveDelete(db.collection(`users/${uid}/devices`));
  await db.recursiveDelete(db.collection(`users/${uid}/blocked`));
  // Audit entries about this account keep the action and the pseudonymous
  // id, but lose free text such as a suspension reason, which staff may
  // have written about the person.
  const logs = await db.collection('auditLogs').where('targetId', '==', uid).get();
  const redactor = db.bulkWriter();
  for (const doc of logs.docs) {
    if (Object.keys(doc.data().details ?? {}).length > 0) {
      redactor.update(doc.ref, { details: { redacted: true } });
    }
  }
  await redactor.close();
  await audit(db, 'system', 'account.purged', uid);
}

/** Purges accounts whose retention period has ended, at most [limit]. */
export async function purgeDueAccounts({ db, auth, now = new Date(), limit = 200 }) {
  const due = await db
    .collection('deletionQueue')
    .where('purgeAfter', '<=', Timestamp.fromDate(now))
    .limit(limit)
    .get();
  let purged = 0;
  for (const doc of due.docs) {
    // One failing account must not block everyone queued after it.
    try {
      await purgeAccount({ db, auth, uid: doc.id });
      purged += 1;
    } catch (error) {
      await doc.ref
        .update({
          attempts: FieldValue.increment(1),
          lastErrorCode: String(error?.code ?? error?.name ?? 'unknown').slice(0, 80),
        })
        .catch(() => {});
    }
  }
  return purged;
}

function audit(db, actorId, action, uid) {
  return db.collection('auditLogs').add({
    actorId,
    action,
    targetType: 'user',
    targetId: uid,
    details: {},
    createdAt: FieldValue.serverTimestamp(),
  });
}
