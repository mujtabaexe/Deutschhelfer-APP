// Deletes an account on request, for people who ask through the web
// deletion page or by email instead of using the app. Run locally by the
// project owner only:
//
//   cd firebase/functions
//   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\secure\deutschhelfer-admin.json"   (PowerShell)
//   node scripts/delete-account.mjs --project deutschhelfer-prod --email student@example.com
//
// Before running it, confirm the request really comes from the account's
// owner: email a one-time code to the account's address and act only on a
// reply that contains it. A "From" header alone can be forged.
//
// The first run changes nothing. It shows the account id and a masked email
// address, then asks you to run again with `--confirm <account id>`. That
// does what the in-app "Delete account" does: anonymizes and disables the
// account now and queues the rest for the 90-day purge. Add `--purge-now` to
// erase everything at once.
//
// Works on the free Spark plan: it uses the Admin SDK from this computer, not
// Cloud Functions. Never commit or share the service-account key. Against the
// emulators, set BOTH FIREBASE_AUTH_EMULATOR_HOST and FIRESTORE_EMULATOR_HOST.

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

import { assertUid, deleteAccountNow, purgeAccount } from '../src/account.js';

const USAGE =
  'Usage: node scripts/delete-account.mjs --project <id> (--email <address> | --uid <uid>) ' +
  '[--confirm <uid>] [--purge-now]';
const FLAGS = new Set(['purge-now']);
const VALUES = new Set(['project', 'email', 'uid', 'confirm']);

function fail(message, code = 2) {
  console.error(message);
  process.exit(code);
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const name = argv[i].replace(/^--/, '');
    if (!argv[i].startsWith('--')) throw new Error(`Unexpected argument: ${argv[i]}`);
    if (FLAGS.has(name)) {
      args[name] = true;
    } else if (VALUES.has(name)) {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith('--')) throw new Error(`--${name} needs a value`);
      args[name] = value;
      i += 1;
    } else {
      throw new Error(`Unknown option --${name}`);
    }
  }
  if (!args.project) throw new Error('--project is required');
  if (Boolean(args.email) === Boolean(args.uid)) throw new Error('Give exactly one of --email or --uid');
  return args;
}

function masked(email) {
  if (!email) return '(no email)';
  const [name, domain] = email.split('@');
  return `${name.slice(0, 1)}***@${domain ?? ''}`;
}

let args;
try {
  args = parseArgs(process.argv.slice(2));
} catch (error) {
  fail(`${error.message}\n${USAGE}`);
}

// Half-configured emulator settings would send Auth or Firestore calls to the
// real project while the other half goes to the emulator.
if (Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST) !== Boolean(process.env.FIRESTORE_EMULATOR_HOST)) {
  fail('Set both FIREBASE_AUTH_EMULATOR_HOST and FIRESTORE_EMULATOR_HOST, or neither.');
}

initializeApp({ projectId: args.project });
const auth = getAuth();
const db = getFirestore();

let user;
try {
  if (args.uid) assertUid(args.uid);
  user = args.uid ? await auth.getUser(args.uid) : await auth.getUserByEmail(args.email);
} catch (error) {
  if (error?.code !== 'auth/user-not-found' && error?.message !== 'Invalid account id.') throw error;
  // Nothing was written. Do not print the address.
  console.log('No account matches. Nothing was changed.');
  process.exit(args.uid ? 1 : 0);
}

if (args.confirm !== user.uid) {
  console.log(`Account ${user.uid} (${masked(user.email)}).`);
  console.log(`Nothing was changed. To delete it, run again with --confirm ${user.uid}`);
  process.exit(3);
}

await deleteAccountNow({ db, auth, uid: user.uid, actorId: 'owner-deletion-script' });
if (args['purge-now']) await purgeAccount({ db, auth, uid: user.uid });
console.log(args['purge-now'] ? 'Account erased.' : 'Account deleted; the rest is purged after 90 days.');
