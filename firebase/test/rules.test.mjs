// Firestore Security Rules tests. Run from firebase/ with `npm test`, which
// starts the Firestore emulator for a demo project. No real data is touched.

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';

const PROJECT = 'demo-deutschhelfer';
let env;

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080').split(':');
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host,
      port: Number(port),
    },
  });
});

after(async () => {
  await env?.cleanup();
});

// ---------- Actors ----------

const as = (uid, claims = {}) =>
  env.authenticatedContext(uid, { email_verified: true, ...claims }).firestore();
const alice = () => as('alice'); // member of g1
const bob = () => as('bob'); // member of g1
const carol = () => as('carol'); // verified, not a member of anything
const mod = () => as('mod', { role: 'student-admin' }); // moderator of g1
const otherAdmin = () => as('admin2', { role: 'student-admin' }); // not a moderator of g1
const owner = () => as('owner', { role: 'owner' });
const unverified = () => as('newbie', { email_verified: false });
const anon = () => env.unauthenticatedContext().firestore();

// ---------- Seed data ----------

async function seed(fn) {
  await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (db) => {
    const now = serverTimestamp();
    for (const [id, name] of [
      ['alice', 'Alice'],
      ['bob', 'Bob'],
      ['carol', 'Carol'],
      ['mod', 'Mod'],
      ['admin2', 'Admin Two'],
      ['owner', 'Owner'],
      ['newbie', 'Newbie'],
    ]) {
      await setDoc(doc(db, 'users', id), {
        displayName: name, createdAt: now, updatedAt: now, rulesVersion: 1, rulesAcceptedAt: now,
      });
    }
    // Staff markers, as setUserRole and the owner script write them.
    await setDoc(doc(db, 'staff/mod'), { role: 'student-admin' });
    await setDoc(doc(db, 'staff/admin2'), { role: 'student-admin' });
    await setDoc(doc(db, 'staff/owner'), { role: 'owner' });
    await setDoc(doc(db, 'groups/g1'), {
      name: 'Visa help',
      description: 'Questions about student visas',
      category: 'visa',
      createdBy: 'owner',
      createdAt: now,
      isActive: true,
      memberCount: 3,
    });
    await setDoc(doc(db, 'groups/closed'), {
      name: 'Archived',
      description: '',
      category: 'general',
      createdBy: 'owner',
      createdAt: now,
      isActive: false,
      memberCount: 0,
    });
    await setDoc(doc(db, 'groups/full'), {
      name: 'Full group',
      description: '',
      category: 'general',
      createdBy: 'owner',
      createdAt: now,
      isActive: true,
      memberCount: 2000,
    });
    const member = (uid, name, role = 'member') => ({ uid, role, displayName: name, joinedAt: now });
    await setDoc(doc(db, 'groups/g1/members/alice'), member('alice', 'Alice'));
    await setDoc(doc(db, 'groups/g1/members/bob'), member('bob', 'Bob'));
    await setDoc(doc(db, 'groups/g1/members/mod'), member('mod', 'Mod', 'moderator'));
    await setDoc(doc(db, 'groups/g1/members/newbie'), member('newbie', 'Newbie'));
    await setDoc(doc(db, 'groups/g1/messages/visible1'), {
      senderId: 'bob', senderName: 'Bob', text: 'Hello all', createdAt: now, status: 'visible',
    });
    await setDoc(doc(db, 'groups/g1/messages/pending1'), {
      senderId: 'bob', senderName: 'Bob', text: 'See https://scam.example.com', createdAt: now, status: 'pending',
    });
    await setDoc(doc(db, 'groups/g1/messages/modmsg'), {
      senderId: 'mod', senderName: 'Mod', text: 'My link www.daad.de', createdAt: now, status: 'pending',
    });
    await setDoc(doc(db, 'conversations/alice_bob'), {
      participants: ['alice', 'bob'], groupId: 'g1', createdAt: now, updatedAt: now,
    });
    await setDoc(doc(db, 'conversations/alice_bob/directMessages/dm1'), {
      senderId: 'bob', text: 'Private hello', createdAt: now,
    });
    await setDoc(doc(db, 'premiumContent/ielts-writing-plan'), { blocks: [] });
    await setDoc(doc(db, 'subscriptions/alice'), { tier: 'premium', status: 'expired' });
    await setDoc(doc(db, 'auditLogs/log1'), { action: 'seed' });
  });
});

// ---------- Helpers ----------

/** Posts a group message the way the app does: message plus rate-limit doc. */
function postBatch(db, uid, groupId, fields) {
  const batch = writeBatch(db);
  const ref = doc(collection(db, `groups/${groupId}/messages`));
  batch.set(doc(db, 'rateLimits', uid), { lastPostAt: serverTimestamp(), lastMessageId: ref.id });
  batch.set(ref, {
    senderId: uid,
    createdAt: serverTimestamp(),
    ...fields,
  });
  return batch.commit();
}

function dmBatch(db, uid, conversationId, text) {
  const batch = writeBatch(db);
  const ref = doc(collection(db, `conversations/${conversationId}/directMessages`));
  batch.set(doc(db, 'rateLimits', uid), { lastPostAt: serverTimestamp(), lastMessageId: ref.id });
  batch.set(ref, {
    senderId: uid, text, createdAt: serverTimestamp(),
  });
  batch.update(doc(db, 'conversations', conversationId), {
    updatedAt: serverTimestamp(),
    lastMessage: { senderId: uid, text: text.slice(0, 120) },
  });
  return batch.commit();
}

async function suspend(uid) {
  await seed((db) =>
    setDoc(doc(db, 'accountRestrictions', uid), {
      status: 'suspended', reason: 'test', updatedBy: 'owner', updatedAt: serverTimestamp(),
    }),
  );
}

const report = (fields) => ({
  reporterId: 'alice',
  targetType: 'groupMessage',
  targetId: 'visible1',
  targetUserId: 'bob',
  groupId: 'g1',
  conversationId: null,
  reason: 'spam',
  details: '',
  excerpt: 'Hello all',
  createdAt: serverTimestamp(),
  status: 'open',
  ...fields,
});

// ---------- Tests ----------

describe('profiles', () => {
  const profile = (extra = {}) => ({
    displayName: 'Dana', createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...extra,
  });

  it('a user creates their own profile', async () => {
    await assertSucceeds(setDoc(doc(as('dana'), 'users/dana'), profile()));
  });

  it('unverified users can create a profile at sign-up', async () => {
    await assertSucceeds(
      setDoc(doc(as('dana', { email_verified: false }), 'users/dana'), profile()),
    );
  });

  it('cannot grant themselves a role through the profile', async () => {
    await assertFails(setDoc(doc(as('dana'), 'users/dana'), profile({ role: 'owner' })));
    await assertFails(updateDoc(doc(alice(), 'users/alice'), { role: 'owner' }));
    await assertFails(updateDoc(doc(alice(), 'users/alice'), { accountStatus: 'active' }));
  });

  it('cannot create or edit another user profile', async () => {
    await assertFails(setDoc(doc(as('dana'), 'users/erin'), profile()));
    await assertFails(
      updateDoc(doc(alice(), 'users/bob'), { displayName: 'Hacked', updatedAt: serverTimestamp() }),
    );
  });

  it('rejects client-chosen timestamps and invalid names', async () => {
    await assertFails(setDoc(doc(as('dana'), 'users/dana'), profile({ createdAt: new Date(0) })));
    for (const name of ['D', 'x'.repeat(41), 'visit www.spam.example', '<b>bold</b>', ' Padded ']) {
      await assertFails(
        setDoc(doc(as('dana'), 'users/dana'), profile({ displayName: name })),
        `name ${name}`,
      );
    }
  });

  it('renames at most once an hour', async () => {
    await assertFails(
      updateDoc(doc(alice(), 'users/alice'), { displayName: 'Alice K', updatedAt: serverTimestamp() }),
    );
    await seed((db) => updateDoc(doc(db, 'users/alice'), { updatedAt: new Date(Date.now() - 2 * 3600 * 1000) }));
    await assertSucceeds(
      updateDoc(doc(alice(), 'users/alice'), { displayName: 'Alice K', updatedAt: serverTimestamp() }),
    );
  });

  it('the sign-up fallback name can be replaced at once', async () => {
    await seed((db) => updateDoc(doc(db, 'users/alice'), { displayName: 'Student' }));
    await assertSucceeds(
      updateDoc(doc(alice(), 'users/alice'), { displayName: 'Alice K', updatedAt: serverTimestamp() }),
    );
  });

  it('suspended users cannot rename themselves', async () => {
    await suspend('alice');
    await assertFails(
      updateDoc(doc(alice(), 'users/alice'), { displayName: 'Alice K', updatedAt: serverTimestamp() }),
    );
  });

  it('accepts the community rules at sign-up, with the server time', async () => {
    await assertSucceeds(
      setDoc(doc(as('dana'), 'users/dana'), profile({ rulesVersion: 1, rulesAcceptedAt: serverTimestamp() })),
    );
  });

  it('rejects a partial, backdated or out-of-range rules acceptance', async () => {
    for (const extra of [
      { rulesVersion: 1 },
      { rulesAcceptedAt: serverTimestamp() },
      { rulesVersion: 1, rulesAcceptedAt: new Date(0) },
      { rulesVersion: 0, rulesAcceptedAt: serverTimestamp() },
      { rulesVersion: 2, rulesAcceptedAt: serverTimestamp() },
      { rulesVersion: 100, rulesAcceptedAt: serverTimestamp() },
      { rulesVersion: '1', rulesAcceptedAt: serverTimestamp() },
    ]) {
      await assertFails(setDoc(doc(as('dana'), 'users/dana'), profile(extra)), JSON.stringify(extra));
    }
  });

  it('accepts the rules later without the rename limit, but never downgrades', async () => {
    await seed((db) => setDoc(doc(db, 'users/dana'), {
      displayName: 'Dana', createdAt: new Date(), updatedAt: new Date(),
    }));
    await assertSucceeds(updateDoc(doc(as('dana'), 'users/dana'), {
      rulesVersion: 1, rulesAcceptedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(alice(), 'users/alice'), {
      rulesVersion: 0, rulesAcceptedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(alice(), 'users/alice'), {
      rulesAcceptedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
    // Review F-02: future versions cannot be accepted in advance.
    await assertFails(updateDoc(doc(as('dana'), 'users/dana'), {
      rulesVersion: 2, rulesAcceptedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
  });

  it('the fallback name exception works once, not as a second rename (review F-07)', async () => {
    await seed((db) => updateDoc(doc(db, 'users/alice'), { displayName: 'Student', updatedAt: new Date() }));
    await assertFails(
      updateDoc(doc(alice(), 'users/alice'), { displayName: 'Alice K', updatedAt: serverTimestamp() }),
    );
  });

  it('restricted accounts cannot add blocks (review F-12)', async () => {
    await suspend('alice');
    await assertFails(setDoc(doc(alice(), 'users/alice/blocked/bob'), { createdAt: serverTimestamp() }));
  });

  it('profiles are readable only when signed in', async () => {
    await assertSucceeds(getDoc(doc(carol(), 'users/alice')));
    await assertFails(getDoc(doc(anon(), 'users/alice')));
  });

  it('the user directory cannot be listed', async () => {
    await assertFails(getDocs(collection(carol(), 'users')));
  });

  it('nobody deletes profiles from the client', async () => {
    await assertFails(deleteDoc(doc(alice(), 'users/alice')));
  });
});

describe('account restrictions', () => {
  const suspension = (by) => ({
    status: 'suspended', reason: 'Spam links', updatedBy: by, updatedAt: serverTimestamp(),
  });

  it('students cannot suspend anyone', async () => {
    await assertFails(setDoc(doc(alice(), 'accountRestrictions/bob'), suspension('alice')));
  });

  it('staff can suspend others; lifting goes through the audited backend', async () => {
    await assertSucceeds(setDoc(doc(mod(), 'accountRestrictions/bob'), suspension('mod')));
    await assertFails(deleteDoc(doc(mod(), 'accountRestrictions/bob')));
    await assertFails(deleteDoc(doc(owner(), 'accountRestrictions/bob')));
  });

  it('a deleted account cannot be turned back into a suspension', async () => {
    await seed((db) =>
      setDoc(doc(db, 'accountRestrictions/bob'), {
        status: 'deleted', reason: 'user request', updatedBy: 'system', updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(setDoc(doc(owner(), 'accountRestrictions/bob'), suspension('owner')));
  });

  it('staff cannot restrict themselves, forge the actor, or mark deletion', async () => {
    await assertFails(setDoc(doc(mod(), 'accountRestrictions/mod'), suspension('mod')));
    await assertFails(setDoc(doc(mod(), 'accountRestrictions/bob'), suspension('owner')));
    await assertFails(
      setDoc(doc(owner(), 'accountRestrictions/bob'), { ...suspension('owner'), status: 'deleted' }),
    );
  });

  it('users see only their own restriction', async () => {
    await suspend('alice');
    await assertSucceeds(getDoc(doc(alice(), 'accountRestrictions/alice')));
    await assertFails(getDoc(doc(bob(), 'accountRestrictions/alice')));
  });

  it('student-admins cannot suspend staff, and nobody suspends the owner', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'staff/mod'), { role: 'student-admin' });
      await setDoc(doc(db, 'staff/admin2'), { role: 'student-admin' });
      await setDoc(doc(db, 'staff/owner'), { role: 'owner' });
    });
    await assertFails(setDoc(doc(mod(), 'accountRestrictions/owner'), suspension('mod')));
    await assertFails(setDoc(doc(mod(), 'accountRestrictions/admin2'), suspension('mod')));
    await assertSucceeds(setDoc(doc(owner(), 'accountRestrictions/admin2'), suspension('owner')));
  });

  it('a suspended moderator loses moderation powers', async () => {
    await suspend('mod');
    await assertFails(
      updateDoc(doc(mod(), 'groups/g1/messages/pending1'), {
        status: 'visible', moderatedBy: 'mod', moderatedAt: serverTimestamp(),
      }),
    );
    await assertFails(setDoc(doc(mod(), 'accountRestrictions/bob'), suspension('mod')));
    await seed((db) => setDoc(doc(db, 'reports/r1'), { ...report(), createdAt: new Date() }));
    await assertFails(getDoc(doc(mod(), 'reports/r1')));
  });

  it('staff list suspended accounts; students cannot', async () => {
    await suspend('bob');
    const suspended = (db) =>
      getDocs(
        query(
          collection(db, 'accountRestrictions'),
          where('status', '==', 'suspended'),
          orderBy('updatedAt', 'desc'),
          limit(50),
        ),
      );
    await assertSucceeds(suspended(mod()));
    await assertSucceeds(suspended(owner()));
    await assertFails(suspended(alice()));
  });

  it('a suspended user cannot lift their own suspension', async () => {
    await suspend('alice');
    await assertFails(deleteDoc(doc(alice(), 'accountRestrictions/alice')));
  });
});

describe('groups', () => {
  const group = (extra = {}) => ({
    name: 'IELTS prep',
    description: 'Practice together',
    category: 'ielts',
    createdBy: 'owner',
    createdAt: serverTimestamp(),
    isActive: true,
    memberCount: 0,
    ...extra,
  });

  it('only the owner creates groups', async () => {
    await assertSucceeds(setDoc(doc(owner(), 'groups/g2'), group()));
    await assertFails(setDoc(doc(alice(), 'groups/g3'), group({ createdBy: 'alice' })));
    await assertFails(setDoc(doc(mod(), 'groups/g3'), group({ createdBy: 'mod' })));
  });

  it('new groups must have valid fields', async () => {
    await assertFails(setDoc(doc(owner(), 'groups/g2'), group({ name: 'ab' })));
    await assertFails(setDoc(doc(owner(), 'groups/g2'), group({ name: 'x'.repeat(61) })));
    await assertFails(setDoc(doc(owner(), 'groups/g2'), group({ description: 'x'.repeat(501) })));
    await assertFails(setDoc(doc(owner(), 'groups/g2'), group({ category: 'dating' })));
    await assertFails(setDoc(doc(owner(), 'groups/g2'), group({ isActive: false })));
    await assertFails(setDoc(doc(owner(), 'groups/g2'), group({ createdBy: 'alice' })));
    await assertFails(setDoc(doc(owner(), 'groups/g2'), group({ pinned: true })));
    await assertFails(setDoc(doc(owner(), 'groups/g2'), group({ createdAt: new Date(0) })));
  });

  it('group names are trimmed, without markup or links', async () => {
    await assertFails(setDoc(doc(owner(), 'groups/g2'), group({ name: ' IELTS prep ' })));
    await assertFails(setDoc(doc(owner(), 'groups/g2'), group({ name: '<b>IELTS</b>' })));
    await assertFails(setDoc(doc(owner(), 'groups/g2'), group({ name: 'Join example.com' })));
    await assertSucceeds(setDoc(doc(owner(), 'groups/g2'), group({ name: 'IELTS 7.0 club' })));
  });

  it('the id "new" is reserved for the app route', async () => {
    await assertFails(setDoc(doc(owner(), 'groups/new'), group()));
  });

  it('the member count cannot be set or changed by clients', async () => {
    await assertFails(setDoc(doc(owner(), 'groups/g2'), group({ memberCount: 5 })));
    await assertFails(updateDoc(doc(owner(), 'groups/g1'), { memberCount: 1 }));
    await assertFails(updateDoc(doc(alice(), 'groups/g1'), { memberCount: 0 }));
  });

  it('groups are visible to signed-in users, including unverified', async () => {
    await assertSucceeds(getDoc(doc(unverified(), 'groups/g1')));
    await assertFails(getDoc(doc(anon(), 'groups/g1')));
  });
});

describe('membership', () => {
  const join = (uid, name, extra = {}) => ({
    uid, role: 'member', displayName: name, joinedAt: serverTimestamp(), ...extra,
  });

  it('a verified student joins an open group', async () => {
    await assertSucceeds(setDoc(doc(carol(), 'groups/g1/members/carol'), join('carol', 'Carol')));
  });

  it('cannot join unverified, suspended, as a moderator, or with a forged name', async () => {
    await assertFails(
      setDoc(doc(as('newbie2', { email_verified: false }), 'groups/g1/members/newbie2'), join('newbie2', 'X')),
    );
    await suspend('carol');
    await assertFails(setDoc(doc(carol(), 'groups/g1/members/carol'), join('carol', 'Carol')));
  });

  it('cannot self-promote or impersonate', async () => {
    await assertFails(
      setDoc(doc(carol(), 'groups/g1/members/carol'), join('carol', 'Carol', { role: 'moderator' })),
    );
    await assertFails(setDoc(doc(carol(), 'groups/g1/members/carol'), join('carol', 'Owner')));
    await assertFails(setDoc(doc(carol(), 'groups/g1/members/dave'), join('dave', 'Carol')));
    await assertFails(updateDoc(doc(alice(), 'groups/g1/members/alice'), { role: 'moderator' }));
  });

  it('cannot join inactive or full groups', async () => {
    await assertFails(setDoc(doc(carol(), 'groups/closed/members/carol'), join('carol', 'Carol')));
    await assertFails(setDoc(doc(carol(), 'groups/full/members/carol'), join('carol', 'Carol')));
  });

  it('member lists are visible to members only', async () => {
    await assertSucceeds(getDocs(collection(alice(), 'groups/g1/members')));
    await assertFails(getDocs(collection(carol(), 'groups/g1/members')));
    await assertSucceeds(getDoc(doc(carol(), 'groups/g1/members/carol')));
  });

  it('members leave; moderators remove members but not moderators', async () => {
    await assertSucceeds(deleteDoc(doc(alice(), 'groups/g1/members/alice')));
    await assertSucceeds(deleteDoc(doc(mod(), 'groups/g1/members/bob')));
    await assertFails(deleteDoc(doc(bob(), 'groups/g1/members/newbie')));
    await seed((db) =>
      setDoc(doc(db, 'groups/g1/members/mod2'), {
        uid: 'mod2', role: 'moderator', displayName: 'M2', joinedAt: serverTimestamp(),
      }),
    );
    await assertFails(deleteDoc(doc(mod(), 'groups/g1/members/mod2')));
  });

  it('users list their own memberships across groups, nobody else’s', async () => {
    await assertSucceeds(
      getDocs(query(collectionGroup(alice(), 'members'), where('uid', '==', 'alice'))),
    );
    await assertFails(
      getDocs(query(collectionGroup(alice(), 'members'), where('uid', '==', 'bob'))),
    );
    await assertFails(getDocs(collectionGroup(alice(), 'members')));
  });

  it('only the owner appoints moderators', async () => {
    await assertSucceeds(updateDoc(doc(owner(), 'groups/g1/members/alice'), { role: 'moderator' }));
    await assertFails(updateDoc(doc(mod(), 'groups/g1/members/bob'), { role: 'moderator' }));
  });
});

describe('group messages', () => {
  it('members post plain messages as visible', async () => {
    await assertSucceeds(postBatch(alice(), 'alice', 'g1', { senderName: 'Alice', text: 'Hi', status: 'visible' }));
  });

  it('links must go to moderation; a client cannot skip it', async () => {
    await assertSucceeds(
      postBatch(alice(), 'alice', 'g1', { senderName: 'Alice', text: 'see www.daad.de', status: 'pending' }),
    );
    for (const text of [
      'https://evil.example',
      'go to WWW.EVIL.COM now',
      'cheap-visas.pk/offer',
      'line1\nhttp://x.y',
      'join discord.gg/abc',
      'visit evil.ru today',
      'shorturl.at/xyz',
      'example\uFF0Ecom',
    ]) {
      await assertFails(
        postBatch(bob(), 'bob', 'g1', { senderName: 'Bob', text, status: 'visible' }),
        text,
      );
    }
  });

  it('plain messages cannot be marked pending either', async () => {
    await assertFails(postBatch(alice(), 'alice', 'g1', { senderName: 'Alice', text: 'Hi', status: 'pending' }));
  });

  it('non-members, unverified and suspended users cannot post', async () => {
    await assertFails(postBatch(carol(), 'carol', 'g1', { senderName: 'Carol', text: 'Hi', status: 'visible' }));
    await assertFails(postBatch(unverified(), 'newbie', 'g1', { senderName: 'Newbie', text: 'Hi', status: 'visible' }));
    await suspend('alice');
    await assertFails(postBatch(alice(), 'alice', 'g1', { senderName: 'Alice', text: 'Hi', status: 'visible' }));
  });

  it('rejects forged senders, names, empty and over-long text', async () => {
    await assertFails(
      postBatch(alice(), 'alice', 'g1', { senderId: 'bob', senderName: 'Bob', text: 'Hi', status: 'visible' }),
    );
    await assertFails(postBatch(alice(), 'alice', 'g1', { senderName: 'Owner', text: 'Hi', status: 'visible' }));
    await assertFails(postBatch(alice(), 'alice', 'g1', { senderName: 'Alice', text: '   ', status: 'visible' }));
    await assertFails(
      postBatch(alice(), 'alice', 'g1', { senderName: 'Alice', text: 'a'.repeat(2001), status: 'visible' }),
    );
  });

  it('rejects posts without the rate-limit document', async () => {
    await assertFails(
      setDoc(doc(collection(alice(), 'groups/g1/messages')), {
        senderId: 'alice', senderName: 'Alice', text: 'Hi', createdAt: serverTimestamp(), status: 'visible',
      }),
    );
  });

  it('one rate-limit write cannot cover several messages', async () => {
    const db = alice();
    const batch = writeBatch(db);
    const first = doc(collection(db, 'groups/g1/messages'));
    const second = doc(collection(db, 'groups/g1/messages'));
    batch.set(doc(db, 'rateLimits/alice'), { lastPostAt: serverTimestamp(), lastMessageId: first.id });
    for (const ref of [first, second]) {
      batch.set(ref, {
        senderId: 'alice', senderName: 'Alice', text: 'spam', createdAt: serverTimestamp(), status: 'visible',
      });
    }
    await assertFails(batch.commit());
  });

  it('rate-limits bursts to one message per second', async () => {
    await assertSucceeds(postBatch(alice(), 'alice', 'g1', { senderName: 'Alice', text: 'one', status: 'visible' }));
    await assertFails(postBatch(alice(), 'alice', 'g1', { senderName: 'Alice', text: 'two', status: 'visible' }));
  });

  it('members read visible messages; others see nothing', async () => {
    const visible = query(
      collection(alice(), 'groups/g1/messages'),
      where('status', '==', 'visible'),
      orderBy('createdAt', 'desc'),
      limit(30),
    );
    await assertSucceeds(getDocs(visible));
    await assertFails(getDocs(collection(alice(), 'groups/g1/messages')));
    await assertFails(getDoc(doc(alice(), 'groups/g1/messages/pending1')));
    await assertFails(
      getDocs(query(collection(carol(), 'groups/g1/messages'), where('status', '==', 'visible'))),
    );
  });

  it('senders see their own pending messages', async () => {
    await assertSucceeds(getDoc(doc(bob(), 'groups/g1/messages/pending1')));
    await assertSucceeds(
      getDocs(query(collection(bob(), 'groups/g1/messages'), where('senderId', '==', 'bob'))),
    );
  });

  it('group moderators approve pending links', async () => {
    await assertSucceeds(getDoc(doc(mod(), 'groups/g1/messages/pending1')));
    await assertSucceeds(
      updateDoc(doc(mod(), 'groups/g1/messages/pending1'), {
        status: 'visible', moderatedBy: 'mod', moderatedAt: serverTimestamp(),
      }),
    );
  });

  it('nobody else can approve, and moderators cannot approve their own', async () => {
    const approve = (by) => ({ status: 'visible', moderatedBy: by, moderatedAt: serverTimestamp() });
    await assertFails(updateDoc(doc(alice(), 'groups/g1/messages/pending1'), approve('alice')));
    await assertFails(updateDoc(doc(bob(), 'groups/g1/messages/pending1'), approve('bob')));
    await assertFails(updateDoc(doc(otherAdmin(), 'groups/g1/messages/pending1'), approve('admin2')));
    await assertFails(updateDoc(doc(mod(), 'groups/g1/messages/modmsg'), approve('mod')));
    await assertFails(updateDoc(doc(mod(), 'groups/g1/messages/pending1'), approve('owner')));
  });

  it('moderators cannot rewrite message text', async () => {
    await assertFails(
      updateDoc(doc(mod(), 'groups/g1/messages/visible1'), {
        text: 'edited', moderatedBy: 'mod', moderatedAt: serverTimestamp(),
      }),
    );
  });

  it('senders withdraw but cannot edit', async () => {
    await assertSucceeds(updateDoc(doc(bob(), 'groups/g1/messages/visible1'), { status: 'withdrawn' }));
    await assertFails(updateDoc(doc(bob(), 'groups/g1/messages/pending1'), { text: 'clean now' }));
    await assertFails(deleteDoc(doc(bob(), 'groups/g1/messages/pending1')));
  });

  it('the owner reviews pending links across groups; students cannot', async () => {
    const pending = (db) =>
      query(collectionGroup(db, 'messages'), where('status', '==', 'pending'), orderBy('createdAt'));
    await assertSucceeds(getDocs(pending(owner())));
    await assertFails(getDocs(pending(alice())));
    await assertFails(getDocs(pending(mod())));
  });
});

describe('direct messages', () => {
  const conversation = (participants, groupId = 'g1') => ({
    participants, groupId, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });

  it('group-mates start a conversation', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'conversations/alice_mod'), conversation(['alice', 'mod'])));
  });

  it('cannot message non-members, mismatch ids, or include strangers', async () => {
    await assertFails(setDoc(doc(alice(), 'conversations/alice_carol'), conversation(['alice', 'carol'])));
    await assertFails(setDoc(doc(alice(), 'conversations/x'), conversation(['alice', 'mod'])));
    await assertFails(setDoc(doc(alice(), 'conversations/mod_alice'), conversation(['mod', 'alice'])));
    await assertFails(setDoc(doc(carol(), 'conversations/bob_mod'), conversation(['bob', 'mod'])));
  });

  it('blocking prevents new conversations and messages', async () => {
    await assertSucceeds(
      setDoc(doc(bob(), 'users/bob/blocked/alice'), { createdAt: serverTimestamp() }),
    );
    await assertFails(dmBatch(alice(), 'alice', 'alice_bob', 'hello?'));
    await seed((db) =>
      setDoc(doc(db, 'users/mod/blocked/alice'), { createdAt: serverTimestamp() }),
    );
    await assertFails(setDoc(doc(alice(), 'conversations/alice_mod'), conversation(['alice', 'mod'])));
  });

  it('participants exchange messages', async () => {
    await assertSucceeds(dmBatch(alice(), 'alice', 'alice_bob', 'Hi Bob'));
    await assertSucceeds(getDocs(collection(bob(), 'conversations/alice_bob/directMessages')));
    await assertSucceeds(
      getDocs(query(collection(alice(), 'conversations'), where('participants', 'array-contains', 'alice'))),
    );
  });

  it('third parties, staff and the owner cannot read private messages', async () => {
    for (const db of [carol(), mod(), owner()]) {
      await assertFails(getDoc(doc(db, 'conversations/alice_bob')));
      await assertFails(getDocs(collection(db, 'conversations/alice_bob/directMessages')));
      await assertFails(getDocs(collectionGroup(db, 'directMessages')));
    }
  });

  it('users can check for their own missing conversation only', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'conversations/alice_mod')));
    await assertFails(getDoc(doc(alice(), 'conversations/bob_mod')));
    await assertFails(getDoc(doc(carol(), 'conversations/alice_bob')));
  });

  it('cannot forge the sender or the summary', async () => {
    const db = alice();
    const batch = writeBatch(db);
    const forged = doc(collection(db, 'conversations/alice_bob/directMessages'));
    batch.set(doc(db, 'rateLimits/alice'), { lastPostAt: serverTimestamp(), lastMessageId: forged.id });
    batch.set(forged, {
      senderId: 'bob', text: 'I owe you', createdAt: serverTimestamp(),
    });
    await assertFails(batch.commit());
    await assertFails(
      updateDoc(doc(alice(), 'conversations/alice_bob'), {
        updatedAt: serverTimestamp(), lastMessage: { senderId: 'bob', text: 'fake' },
      }),
    );
    await assertFails(updateDoc(doc(alice(), 'conversations/alice_bob'), { participants: ['alice', 'carol'] }));
  });

  it('a blocked user cannot push text into the inbox summary', async () => {
    await seed((db) => setDoc(doc(db, 'users/bob/blocked/alice'), { createdAt: serverTimestamp() }));
    const db = alice();
    const batch = writeBatch(db);
    batch.set(doc(db, 'rateLimits/alice'), { lastPostAt: serverTimestamp(), lastMessageId: 'x' });
    batch.update(doc(db, 'conversations/alice_bob'), {
      updatedAt: serverTimestamp(), lastMessage: { senderId: 'alice', text: 'still here' },
    });
    await assertFails(batch.commit());
  });

  it('summary updates must ride with a rate-limited message', async () => {
    await assertFails(
      updateDoc(doc(alice(), 'conversations/alice_bob'), {
        updatedAt: serverTimestamp(), lastMessage: { senderId: 'alice', text: 'no message' },
      }),
    );
  });

  it('suspended users cannot send direct messages', async () => {
    await suspend('alice');
    await assertFails(dmBatch(alice(), 'alice', 'alice_bob', 'Hi'));
  });

  it('users cannot block themselves or manage others’ block lists', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice/blocked/alice'), { createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(alice(), 'users/bob/blocked/carol'), { createdAt: serverTimestamp() }));
    await assertFails(getDocs(collection(alice(), 'users/bob/blocked')));
  });
});

describe('reports', () => {
  it('members report a message they can see, quoting it exactly', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'reports/alice_groupMessage_visible1'), report()));
  });

  it('rejects fabricated quotes, wrong ids, self-reports and non-members', async () => {
    await assertFails(
      setDoc(doc(alice(), 'reports/alice_groupMessage_visible1'), report({ excerpt: 'Bob said a slur' })),
    );
    await assertFails(setDoc(doc(alice(), 'reports/anything'), report()));
    await assertFails(
      setDoc(doc(bob(), 'reports/bob_groupMessage_visible1'), report({ reporterId: 'bob' })),
    );
    await assertFails(
      setDoc(doc(carol(), 'reports/carol_groupMessage_visible1'), report({ reporterId: 'carol' })),
    );
  });

  it('cannot confirm the text of a message the reporter cannot see', async () => {
    await assertFails(
      setDoc(
        doc(alice(), 'reports/alice_groupMessage_pending1'),
        report({ targetId: 'pending1', excerpt: 'See https://scam.example.com' }),
      ),
    );
  });

  it('suspended users cannot file reports', async () => {
    await suspend('alice');
    await assertFails(setDoc(doc(alice(), 'reports/alice_groupMessage_visible1'), report()));
  });

  it('a report cannot be filed twice or edited by the reporter', async () => {
    const ref = (db) => doc(db, 'reports/alice_groupMessage_visible1');
    await assertSucceeds(setDoc(ref(alice()), report()));
    await assertFails(setDoc(ref(alice()), report({ reason: 'scam' })));
    await assertFails(updateDoc(ref(alice()), { status: 'dismissed' }));
  });

  it('participants report direct messages; outsiders cannot', async () => {
    const dmReport = (reporter) =>
      report({
        reporterId: reporter,
        targetType: 'directMessage',
        targetId: 'dm1',
        groupId: null,
        conversationId: 'alice_bob',
        excerpt: 'Private hello',
      });
    await assertSucceeds(setDoc(doc(alice(), 'reports/alice_directMessage_dm1'), dmReport('alice')));
    await assertFails(setDoc(doc(carol(), 'reports/carol_directMessage_dm1'), dmReport('carol')));
  });

  it('only staff read and resolve reports', async () => {
    await seed((db) => setDoc(doc(db, 'reports/r1'), { ...report(), createdAt: new Date() }));
    await assertFails(getDoc(doc(alice(), 'reports/r1')));
    await assertSucceeds(getDoc(doc(mod(), 'reports/r1')));
    const resolve = (by) => ({
      status: 'actioned', resolvedBy: by, resolvedAt: serverTimestamp(), resolution: 'Suspended sender',
    });
    await assertFails(updateDoc(doc(alice(), 'reports/r1'), resolve('alice')));
    await assertSucceeds(updateDoc(doc(mod(), 'reports/r1'), resolve('mod')));
  });
});

describe('premium and billing', () => {
  it('premium content requires a verified premium claim', async () => {
    const article = (db) => getDoc(doc(db, 'premiumContent/ielts-writing-plan'));
    await assertFails(article(alice()));
    await assertSucceeds(article(as('payer', { premium: true })));
    await assertFails(article(as('payer', { premium: true, email_verified: false })));
    await assertFails(article(as('payer', { premium: 'true' })));
  });

  it('clients cannot forge subscriptions or premium content', async () => {
    await assertFails(
      setDoc(doc(alice(), 'subscriptions/alice'), { tier: 'premium', status: 'active' }),
    );
    await assertFails(updateDoc(doc(alice(), 'subscriptions/alice'), { status: 'active' }));
    await assertFails(setDoc(doc(owner(), 'premiumContent/new'), { blocks: [] }));
  });

  it('users read only their own subscription', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'subscriptions/alice')));
    await assertFails(getDoc(doc(bob(), 'subscriptions/alice')));
  });
});

describe('audit logs and defaults', () => {
  it('only the owner reads audit logs, and nobody writes them', async () => {
    await assertSucceeds(getDoc(doc(owner(), 'auditLogs/log1')));
    await assertFails(getDoc(doc(mod(), 'auditLogs/log1')));
    await assertFails(setDoc(doc(owner(), 'auditLogs/new'), { action: 'fake' }));
  });

  it('staff markers are server-only', async () => {
    await assertFails(setDoc(doc(alice(), 'staff/alice'), { role: 'owner' }));
    await assertFails(getDoc(doc(owner(), 'staff/owner')));
  });

  it('unknown collections are denied', async () => {
    await assertFails(setDoc(doc(owner(), 'anything/else'), { x: 1 }));
    await assertFails(getDoc(doc(owner(), 'anything/else')));
  });
});

describe('push devices', () => {
  const TOKEN = 'fcm-Token_1234567890:abcDEF';
  const device = (extra = {}) => ({
    token: TOKEN, platform: 'android', updatedAt: serverTimestamp(), ...extra,
  });

  it('a user registers, refreshes and removes their own device', async () => {
    await assertSucceeds(setDoc(doc(alice(), `users/alice/devices/${TOKEN}`), device()));
    await assertSucceeds(setDoc(doc(alice(), `users/alice/devices/${TOKEN}`), device()));
    await assertSucceeds(getDoc(doc(alice(), `users/alice/devices/${TOKEN}`)));
    await assertSucceeds(deleteDoc(doc(alice(), `users/alice/devices/${TOKEN}`)));
  });

  it('nobody else reads, adds or removes a user\'s devices', async () => {
    await seed((db) => setDoc(doc(db, `users/alice/devices/${TOKEN}`), device()));
    for (const other of [bob(), owner(), mod()]) {
      await assertFails(getDoc(doc(other, `users/alice/devices/${TOKEN}`)));
      await assertFails(getDocs(collection(other, 'users/alice/devices')));
      await assertFails(deleteDoc(doc(other, `users/alice/devices/${TOKEN}`)));
      await assertFails(setDoc(doc(other, `users/alice/devices/other-token-1234567890`),
        device({ token: 'other-token-1234567890' })));
    }
    await assertFails(getDoc(doc(anon(), `users/alice/devices/${TOKEN}`)));
  });

  it('the document must describe exactly the token in its id', async () => {
    const ref = doc(alice(), `users/alice/devices/${TOKEN}`);
    await assertFails(setDoc(ref, device({ token: 'another-token-1234567890' })));
    await assertFails(setDoc(ref, device({ platform: 'ios' })));
    await assertFails(setDoc(ref, device({ updatedAt: new Date(0) })));
    await assertFails(setDoc(ref, device({ uid: 'bob' })));
    await assertFails(setDoc(doc(alice(), 'users/alice/devices/short'), device({ token: 'short' })));
    await assertFails(
      setDoc(doc(alice(), 'users/alice/devices/bad token with spaces!!'),
        device({ token: 'bad token with spaces!!' })),
    );
  });
});

describe('demoted staff', () => {
  // A student-admin claim in a token issued before demotion, with the staff
  // marker already removed by setUserRole.
  const exAdmin = () => as('exadmin', { role: 'student-admin' });

  it('lose moderation, suspension and report access at once', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users/exadmin'), {
        displayName: 'Ex Admin', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      });
      await setDoc(doc(db, 'groups/g1/members/exadmin'), {
        uid: 'exadmin', role: 'moderator', displayName: 'Ex Admin', joinedAt: serverTimestamp(),
      });
      await setDoc(doc(db, 'reports/r1'), { ...report(), createdAt: new Date() });
    });
    await assertFails(
      updateDoc(doc(exAdmin(), 'groups/g1/messages/pending1'), {
        status: 'visible', moderatedBy: 'exadmin', moderatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(doc(exAdmin(), 'accountRestrictions/bob'), {
        status: 'suspended', reason: 'x', updatedBy: 'exadmin', updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(getDoc(doc(exAdmin(), 'reports/r1')));
    // The same request with the marker in place succeeds.
    await seed((db) => setDoc(doc(db, 'staff/exadmin'), { role: 'student-admin' }));
    await assertSucceeds(getDoc(doc(exAdmin(), 'reports/r1')));
  });
});

describe('push devices of restricted or unverified accounts', () => {
  const TOKEN = 'fcm-Token_1234567890:restricted';
  const device = { token: TOKEN, platform: 'android', updatedAt: serverTimestamp() };

  it('cannot be registered', async () => {
    await suspend('alice');
    await assertFails(setDoc(doc(alice(), `users/alice/devices/${TOKEN}`), device));
    await assertFails(setDoc(doc(unverified(), `users/newbie/devices/${TOKEN}`), device));
  });
});

describe('community rules acceptance', () => {
  // Verified, but never accepted the rules (for example an interrupted
  // sign-up whose fallback profile was created by the app).
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users/carol'), {
        displayName: 'Carol', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      });
      await setDoc(doc(db, 'users/bob'), {
        displayName: 'Bob', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      });
    });
  });

  it('is required to join a group', async () => {
    await assertFails(setDoc(doc(carol(), 'groups/g1/members/carol'), {
      uid: 'carol', role: 'member', displayName: 'Carol', joinedAt: serverTimestamp(),
    }));
    await seed((db) => updateDoc(doc(db, 'users/carol'), { rulesVersion: 1, rulesAcceptedAt: new Date() }));
    await assertSucceeds(setDoc(doc(carol(), 'groups/g1/members/carol'), {
      uid: 'carol', role: 'member', displayName: 'Carol', joinedAt: serverTimestamp(),
    }));
  });

  it('is required to post in a group, even for an existing member', async () => {
    const post = (id) => {
      const db = bob();
      const batch = writeBatch(db);
      batch.set(doc(db, `groups/g1/messages/${id}`), {
        senderId: 'bob', senderName: 'Bob', text: 'hello', createdAt: serverTimestamp(), status: 'visible',
      });
      batch.set(doc(db, 'rateLimits/bob'), { lastPostAt: serverTimestamp(), lastMessageId: id });
      return batch.commit();
    };
    await assertFails(post('m-norules'));
    await seed((db) => updateDoc(doc(db, 'users/bob'), { rulesVersion: 1, rulesAcceptedAt: new Date() }));
    await assertSucceeds(post('m-rules'));
  });

  it('the owner cannot add a member who has not accepted (review F-11)', async () => {
    await assertFails(setDoc(doc(owner(), 'groups/g1/members/carol'), {
      uid: 'carol', role: 'member', displayName: 'Carol', joinedAt: serverTimestamp(),
    }));
  });

  it('is required to send a direct message or inbox summary (review F-01)', async () => {
    // bob is in the seeded alice_bob conversation but has not accepted.
    const db = bob();
    const batch = writeBatch(db);
    batch.set(doc(db, 'conversations/alice_bob/directMessages/dm-norules'), {
      senderId: 'bob', text: 'hi', createdAt: serverTimestamp(),
    });
    batch.set(doc(db, 'rateLimits/bob'), { lastPostAt: serverTimestamp(), lastMessageId: 'dm-norules' });
    batch.update(doc(db, 'conversations/alice_bob'), {
      updatedAt: serverTimestamp(), lastMessage: { senderId: 'bob', text: 'hi' },
    });
    await assertFails(batch.commit());

    await seed((s) => updateDoc(doc(s, 'users/bob'), { rulesVersion: 1, rulesAcceptedAt: new Date() }));
    const db2 = bob();
    const ok = writeBatch(db2);
    ok.set(doc(db2, 'conversations/alice_bob/directMessages/dm-rules'), {
      senderId: 'bob', text: 'hi', createdAt: serverTimestamp(),
    });
    ok.set(doc(db2, 'rateLimits/bob'), { lastPostAt: serverTimestamp(), lastMessageId: 'dm-rules' });
    ok.update(doc(db2, 'conversations/alice_bob'), {
      updatedAt: serverTimestamp(), lastMessage: { senderId: 'bob', text: 'hi' },
    });
    await assertSucceeds(ok.commit());
  });

  it('is required of both people to start a direct conversation', async () => {
    const conversation = {
      participants: ['bob', 'mod'], groupId: 'g1', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    };
    await assertFails(setDoc(doc(bob(), 'conversations/bob_mod'), conversation));
    // Review F-01: an accepted member cannot open one with someone who has not.
    await assertFails(setDoc(doc(mod(), 'conversations/bob_mod'), conversation));
    await seed((db) => updateDoc(doc(db, 'users/bob'), { rulesVersion: 1, rulesAcceptedAt: new Date() }));
    await assertSucceeds(setDoc(doc(mod(), 'conversations/bob_mod'), conversation));
  });
});
