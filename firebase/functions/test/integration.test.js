// Runs the real functions in the emulator. From firebase/functions:
//   npm run test:integration
// Uses the demo project only; no real data or billing.

import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { after, before, describe, it } from 'node:test';

import { deleteApp as deleteAdminApp, initializeApp as initAdmin } from 'firebase-admin/app';
import { getAuth as adminAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { deleteApp, initializeApp } from 'firebase/app';
import {
  connectAuthEmulator,
  getAuth,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import { connectFunctionsEmulator, getFunctions, httpsCallable } from 'firebase/functions';

import { purgeDueAccounts } from '../src/account.js';

const PROJECT = 'demo-deutschhelfer';
const admin = initAdmin({ projectId: PROJECT }, 'admin');
const db = getFirestore(admin);
const auth = adminAuth(admin);

const client = initializeApp({ projectId: PROJECT, apiKey: 'demo-key' }, 'client');
const clientAuth = getAuth(client);
connectAuthEmulator(clientAuth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099'}`, {
  disableWarnings: true,
});
const functions = getFunctions(client, 'asia-southeast1');
connectFunctionsEmulator(functions, '127.0.0.1', 5001);

const PASSWORD = 'test-password-123';

async function createUser(uid, claims) {
  await auth.createUser({ uid, email: `${uid}@example.test`, password: PASSWORD, emailVerified: true });
  if (claims) await auth.setCustomUserClaims(uid, claims);
}

async function signInAs(uid) {
  await signOut(clientAuth);
  await signInWithEmailAndPassword(clientAuth, `${uid}@example.test`, PASSWORD);
}

async function call(name, data) {
  return (await httpsCallable(functions, name)(data)).data;
}

async function expectCode(promise, code) {
  await assert.rejects(promise, (error) => {
    assert.equal(error.code, `functions/${code}`);
    return true;
  });
}

async function waitFor(check, label, timeoutMs = 15000) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    if (await check()) return;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  assert.fail(`Timed out waiting for ${label}`);
}

before(async () => {
  await createUser('owner', { role: 'owner' });
  await createUser('admin', { role: 'student-admin' });
  await createUser('alice');
  await createUser('bob');
  // Staff markers, as setUserRole and the owner script write them.
  await db.doc('staff/owner').set({ role: 'owner' });
  await db.doc('staff/admin').set({ role: 'student-admin' });
  await db.doc('groups/g1').set({
    name: 'Visa help',
    description: '',
    category: 'visa',
    createdBy: 'owner',
    createdAt: FieldValue.serverTimestamp(),
    isActive: true,
    memberCount: 0,
  });
});

after(async () => {
  await signOut(clientAuth);
  await deleteApp(client);
  await deleteAdminApp(admin);
});

describe('triggers', () => {
  it('keeps the member count in step with joins and leaves', async () => {
    const member = db.doc('groups/g1/members/alice');
    await member.set({ uid: 'alice', role: 'member', displayName: 'Alice', joinedAt: FieldValue.serverTimestamp() });
    await waitFor(async () => (await db.doc('groups/g1').get()).data().memberCount === 1, 'count 1');
    await member.delete();
    await waitFor(async () => (await db.doc('groups/g1').get()).data().memberCount === 0, 'count 0');
  });

  it('records moderation decisions in the audit log', async () => {
    const message = db.doc('groups/g1/messages/m1');
    await message.set({ senderId: 'bob', senderName: 'Bob', text: 'www.x.com', createdAt: new Date(), status: 'pending' });
    await message.update({ status: 'visible', moderatedBy: 'admin', moderatedAt: new Date() });
    await waitFor(async () => {
      const logs = await db.collection('auditLogs').where('action', '==', 'message.approve').get();
      return logs.docs.some((d) => d.data().actorId === 'admin' && d.data().targetId === 'g1/m1');
    }, 'approval audit');
  });

  it('syncs a renamed profile into memberships', async () => {
    await db.doc('users/bob').set({ displayName: 'Bob', createdAt: new Date(), updatedAt: new Date() });
    await db.doc('groups/g1/members/bob').set({ uid: 'bob', role: 'member', displayName: 'Bob', joinedAt: new Date() });
    await db.doc('users/bob').update({ displayName: 'Robert' });
    await waitFor(
      async () => (await db.doc('groups/g1/members/bob').get()).data()?.displayName === 'Robert',
      'name sync',
    );
  });
});

describe('setUserRole', () => {
  it('refuses students and staff', async () => {
    await signInAs('alice');
    await expectCode(call('setUserRole', { uid: 'bob', role: 'student-admin' }), 'permission-denied');
    await signInAs('admin');
    await expectCode(call('setUserRole', { uid: 'bob', role: 'student-admin' }), 'permission-denied');
  });

  it('lets the owner grant and remove student-admin, never owner', async () => {
    await signInAs('owner');
    await call('setUserRole', { uid: 'bob', role: 'student-admin' });
    assert.equal((await auth.getUser('bob')).customClaims.role, 'student-admin');
    assert.equal((await db.doc('staff/bob').get()).data().role, 'student-admin');
    await call('setUserRole', { uid: 'bob', role: 'student' });
    assert.equal((await auth.getUser('bob')).customClaims?.role, undefined);
    assert.equal((await db.doc('staff/bob').get()).exists, false);
    await expectCode(call('setUserRole', { uid: 'bob', role: 'owner' }), 'invalid-argument');
    await expectCode(call('setUserRole', { uid: 'owner', role: 'student' }), 'permission-denied');
  });
});

describe('liftSuspension', () => {
  it('only staff lift suspensions, and it is audited', async () => {
    await db.doc('accountRestrictions/bob').set({
      status: 'suspended', reason: 'spam', updatedBy: 'admin', updatedAt: new Date(),
    });
    await signInAs('alice');
    await expectCode(call('liftSuspension', { uid: 'bob' }), 'permission-denied');
    await signInAs('admin');
    await call('liftSuspension', { uid: 'bob' });
    assert.equal((await db.doc('accountRestrictions/bob').get()).exists, false);
    const logs = await db.collection('auditLogs').where('action', '==', 'account.unsuspend').get();
    assert.ok(logs.docs.some((d) => d.data().actorId === 'admin'));
    await expectCode(call('liftSuspension', { uid: 'bob' }), 'failed-precondition');
  });

  it('a suspended staff member cannot use staff functions', async () => {
    await db.doc('accountRestrictions/bob').set({
      status: 'suspended', reason: 'spam', updatedBy: 'owner', updatedAt: new Date(),
    });
    await db.doc('accountRestrictions/admin').set({
      status: 'suspended', reason: 'abuse', updatedBy: 'owner', updatedAt: new Date(),
    });
    await signInAs('admin');
    await expectCode(call('liftSuspension', { uid: 'bob' }), 'permission-denied');
    await db.doc('accountRestrictions/admin').delete();
    await db.doc('accountRestrictions/bob').delete();
  });

  it('a demoted student-admin with an old token cannot lift', async () => {
    // Claims still say student-admin, but setUserRole removed the marker.
    await createUser('admin4', { role: 'student-admin' });
    await db.doc('accountRestrictions/bob').set({
      status: 'suspended', reason: 'spam', updatedBy: 'owner', updatedAt: new Date(),
    });
    await signInAs('admin4');
    await expectCode(call('liftSuspension', { uid: 'bob' }), 'permission-denied');
    assert.equal((await db.doc('accountRestrictions/bob').get()).exists, true);
    await db.doc('accountRestrictions/bob').delete();
  });

  it('student-admins cannot lift a staff suspension; the owner can', async () => {
    await createUser('admin3', { role: 'student-admin' });
    await db.doc('staff/admin3').set({ role: 'student-admin' });
    await db.doc('accountRestrictions/admin3').set({
      status: 'suspended', reason: 'abuse', updatedBy: 'owner', updatedAt: new Date(),
    });
    await signInAs('admin');
    await expectCode(call('liftSuspension', { uid: 'admin3' }), 'permission-denied');
    assert.equal((await db.doc('accountRestrictions/admin3').get()).exists, true);
    await signInAs('owner');
    await call('liftSuspension', { uid: 'admin3' });
    assert.equal((await db.doc('accountRestrictions/admin3').get()).exists, false);
  });
});

describe('push devices', () => {
  const device = (token) => ({ token, platform: 'android', updatedAt: new Date() });

  it('a token belongs to the account that registered it last', async () => {
    const token = 'fcm-Token_1234567890:shared';
    // Back to back, so the triggers may run in either order.
    await db.doc(`users/alice/devices/${token}`).set(device(token));
    await new Promise((resolve) => setTimeout(resolve, 5));
    await db.doc(`users/bob/devices/${token}`).set(device(token));
    await waitFor(
      async () => !(await db.doc(`users/alice/devices/${token}`).get()).exists,
      'shared token removed from the previous account',
    );
    // Let any late trigger finish, then check the newer one survived.
    await new Promise((resolve) => setTimeout(resolve, 1500));
    assert.equal((await db.doc(`users/bob/devices/${token}`).get()).exists, true);
    assert.equal((await db.doc(`users/alice/devices/${token}`).get()).exists, false);
  });

  it('extra devices are trimmed to the newest ten', async () => {
    for (let i = 0; i < 13; i++) {
      const token = `fcm-Token_1234567890:many${String(i).padStart(2, '0')}`;
      await db.doc(`users/dave/devices/${token}`).set({
        token, platform: 'android', updatedAt: new Date(Date.UTC(2026, 0, 1, 0, 0, i)),
      });
    }
    await waitFor(async () => (await db.collection('users/dave/devices').get()).size === 10, 'ten devices');
    const left = (await db.collection('users/dave/devices').get()).docs.map((d) => d.id);
    assert.equal(left.includes('fcm-Token_1234567890:many00'), false);
    assert.equal(left.includes('fcm-Token_1234567890:many12'), true);
  });
});

describe('push triggers', () => {
  it('a direct message and a moderation decision run cleanly with push off', async () => {
    // FCM has no emulator, so PUSH_ENABLED=false here. This checks the
    // triggers load and do not fail the writes that start them.
    await db.doc('conversations/alice_bob').set({
      participants: ['alice', 'bob'], groupId: 'g1', createdAt: new Date(), updatedAt: new Date(),
    });
    await db.doc('users/bob/devices/fcm-Token_1234567890:abcDEF').set({
      token: 'fcm-Token_1234567890:abcDEF', platform: 'android', updatedAt: new Date(),
    });
    await db.doc('conversations/alice_bob/directMessages/m1').set({
      senderId: 'alice', text: 'Hello', createdAt: new Date(),
    });
    await db.doc('groups/g1/messages/p1').set({
      senderId: 'bob', senderName: 'Bob', text: 'www.example.com', createdAt: new Date(), status: 'pending',
    });
    await db.doc('groups/g1/messages/p1').update({ status: 'visible', moderatedBy: 'admin', moderatedAt: new Date() });
    await waitFor(async () => {
      const logs = await db.collection('auditLogs').where('targetId', '==', 'g1/p1').get();
      return !logs.empty;
    }, 'moderation audit');
    // Push is off, so the device is untouched.
    assert.equal((await db.doc('users/bob/devices/fcm-Token_1234567890:abcDEF').get()).exists, true);
  });
});

describe('deleteMyAccount', () => {
  it('anonymizes, removes memberships, disables the login and queues a purge', async () => {
    await createUser('carol');
    await db.doc('users/carol').set({ displayName: 'Carol K', createdAt: new Date(), updatedAt: new Date() });
    await db.doc('groups/g1/members/carol').set({ uid: 'carol', role: 'member', displayName: 'Carol K', joinedAt: new Date() });
    await db.doc('groups/g1/messages/c1').set({ senderId: 'carol', senderName: 'Carol K', text: 'Hi', createdAt: new Date(), status: 'visible' });
    await db.doc('users/carol/devices/fcm-Token_1234567890:carol').set({
      token: 'fcm-Token_1234567890:carol', platform: 'android', updatedAt: new Date(),
    });
    await signInAs('carol');
    await call('deleteMyAccount', {});

    assert.equal((await db.doc('users/carol').get()).data().displayName, 'Deleted user');
    assert.equal((await db.doc('groups/g1/members/carol').get()).exists, false);
    assert.equal((await db.doc('accountRestrictions/carol').get()).data().status, 'deleted');
    assert.equal((await auth.getUser('carol')).disabled, true);
    assert.ok((await db.doc('deletionQueue/carol').get()).data().purgeAfter);
    assert.equal((await db.doc('groups/g1/messages/c1').get()).data().senderName, 'Deleted user');
    assert.equal((await db.collection('users/carol/devices').get()).size, 0);
  });

  it('the purge erases what is left after the retention period', async () => {
    // carol was deleted by the previous test. She also filed a report and
    // had a purchase token on file.
    await db.doc('reports/carol_user_bob').set({ reporterId: 'carol', targetUserId: 'bob', status: 'open' });
    await db.doc('purchaseTokens/hash-carol').set({ uid: 'carol', token: 't', productId: 'p' });

    // Not due yet: nothing happens.
    assert.equal(await purgeDueAccounts({ db, auth, now: new Date() }), 0);
    assert.equal((await db.doc('users/carol').get()).exists, true);

    const later = new Date(Date.now() + 91 * 24 * 60 * 60 * 1000);
    assert.equal(await purgeDueAccounts({ db, auth, now: later }), 1);
    await assert.rejects(auth.getUser('carol'), (error) => error.code === 'auth/user-not-found');
    for (const path of ['users/carol', 'accountRestrictions/carol', 'deletionQueue/carol',
      'reports/carol_user_bob', 'purchaseTokens/hash-carol']) {
      assert.equal((await db.doc(path).get()).exists, false, path);
    }
    // Shared conversation history stays, without the name.
    assert.equal((await db.doc('groups/g1/messages/c1').get()).data().senderName, 'Deleted user');
    const purged = await db.collection('auditLogs')
      .where('action', '==', 'account.purged').where('targetId', '==', 'carol').get();
    assert.equal(purged.size, 1);
    // Running again is harmless.
    assert.equal(await purgeDueAccounts({ db, auth, now: later }), 0);
  });

  it('unverified accounts can delete themselves too', async () => {
    await auth.createUser({ uid: 'erin', email: 'erin@example.test', password: PASSWORD, emailVerified: false });
    await signInAs('erin');
    await call('deleteMyAccount', {});
    assert.equal((await auth.getUser('erin')).disabled, true);
  });

  it('requires sign-in', async () => {
    await signOut(clientAuth);
    await expectCode(call('deleteMyAccount', {}), 'unauthenticated');
  });
});

describe('delete-account script (web deletion requests)', () => {
  const run = (args, env = process.env) =>
    promisify(execFile)(process.execPath, ['scripts/delete-account.mjs', '--project', PROJECT, ...args], {
      cwd: new URL('..', import.meta.url),
      env,
    });
  const exitCode = async (promise) => {
    try {
      await promise;
      return 0;
    } catch (error) {
      return error.code;
    }
  };

  it('a first run only shows the account; --confirm deletes; --purge-now erases', async () => {
    await createUser('dave');
    await db.doc('users/dave').set({ displayName: 'Dave', createdAt: new Date(), updatedAt: new Date() });
    await db.doc('groups/g1/members/dave').set({ uid: 'dave', role: 'member', displayName: 'Dave', joinedAt: new Date() });

    const dry = await run(['--email', 'dave@example.test']).catch((error) => error);
    assert.equal(dry.code, 3);
    assert.match(dry.stdout, /Account dave \(d\*\*\*@example\.test\)/);
    assert.equal((await auth.getUser('dave')).disabled, false);
    assert.equal((await db.doc('groups/g1/members/dave').get()).exists, true);

    const { stdout } = await run(['--email', 'dave@example.test', '--confirm', 'dave', '--purge-now']);
    assert.match(stdout, /Account erased/);
    await assert.rejects(auth.getUser('dave'), (error) => error.code === 'auth/user-not-found');
    assert.equal((await db.doc('groups/g1/members/dave').get()).exists, false);
    assert.equal((await db.doc('users/dave').get()).exists, false);
    const logged = await db.collection('auditLogs')
      .where('action', '==', 'account.delete_requested').where('targetId', '==', 'dave').get();
    assert.equal(logged.docs[0].data().actorId, 'owner-deletion-script');
  });

  it('an unknown address changes nothing and is not echoed', async () => {
    const { stdout } = await run(['--email', 'nobody@example.test']);
    assert.match(stdout, /No account matches/);
    assert.doesNotMatch(stdout, /nobody/);
  });

  it('an unknown or malformed uid writes nothing (review F-05)', async () => {
    assert.equal(await exitCode(run(['--uid', 'ghost', '--confirm', 'ghost'])), 1);
    assert.equal((await db.doc('deletionQueue/ghost').get()).exists, false);
    assert.equal((await db.doc('users/ghost').get()).exists, false);
    assert.equal(await exitCode(run(['--uid', 'x/blocked/y', '--confirm', 'x/blocked/y'])), 1);
    assert.equal((await db.doc('users/x/blocked/y').get()).exists, false);
  });

  it('refuses unsafe argument combinations', async () => {
    assert.equal(await exitCode(run([])), 2);
    assert.equal(await exitCode(run(['--email', 'a@example.test', '--uid', 'alice'])), 2);
    assert.equal(await exitCode(run(['--email', 'a@example.test', '--purge-now', 'false'])), 2);
    const halfEmulated = { ...process.env, FIREBASE_AUTH_EMULATOR_HOST: '' };
    assert.equal(await exitCode(run(['--email', 'a@example.test'], halfEmulated)), 2);
  });
});

describe('purge resilience', () => {
  it('one failing account does not block the rest (review F-04)', async () => {
    const past = new Date(Date.now() - 1000);
    // A malformed id is refused by assertUid every time.
    await db.doc('deletionQueue/bad.id').set({ requestedAt: past, purgeAfter: new Date(past.getTime() - 1000) });
    await createUser('fred');
    await db.doc('users/fred').set({ displayName: 'Fred', createdAt: new Date(), updatedAt: new Date() });
    await db.doc('deletionQueue/fred').set({ requestedAt: past, purgeAfter: past });

    assert.equal(await purgeDueAccounts({ db, auth, now: new Date() }), 1);
    await assert.rejects(auth.getUser('fred'), (error) => error.code === 'auth/user-not-found');
    const bad = (await db.doc('deletionQueue/bad.id').get()).data();
    assert.equal(bad.attempts, 1);
    assert.ok(bad.lastErrorCode);
    await db.doc('deletionQueue/bad.id').delete();
  });

  it('the purge removes free-text reasons from audit entries about the account (review F-06)', async () => {
    await createUser('gina');
    await db.collection('auditLogs').add({
      actorId: 'admin', action: 'account.suspend', targetType: 'user', targetId: 'gina',
      details: { reason: 'Free text about Gina' }, createdAt: new Date(),
    });
    await db.doc('deletionQueue/gina').set({ requestedAt: new Date(), purgeAfter: new Date(Date.now() - 1000) });
    await purgeDueAccounts({ db, auth, now: new Date() });
    const entries = await db.collection('auditLogs').where('targetId', '==', 'gina').get();
    const suspend = entries.docs.map((d) => d.data()).find((d) => d.action === 'account.suspend');
    assert.deepEqual(suspend.details, { redacted: true });
  });
});

describe('verifyPurchase', () => {
  it('refuses until the Play integration is configured', async () => {
    await signInAs('alice');
    await expectCode(
      call('verifyPurchase', { purchaseToken: 'x'.repeat(30), productId: 'premium_monthly' }),
      'failed-precondition',
    );
  });

  it('validates input before anything else', async () => {
    await signInAs('alice');
    await expectCode(call('verifyPurchase', { purchaseToken: 'short', productId: 'p' }), 'invalid-argument');
  });

  it('requires sign-in', async () => {
    await signOut(clientAuth);
    await expectCode(
      call('verifyPurchase', { purchaseToken: 'x'.repeat(30), productId: 'premium_monthly' }),
      'unauthenticated',
    );
  });
});
