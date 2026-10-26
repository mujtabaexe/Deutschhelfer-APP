// One-time owner bootstrap. Run locally by the project owner only:
//
//   cd firebase
//   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\secure\deutschhelfer-admin.json"   (PowerShell)
//   node scripts/set-owner.mjs --project deutschhelfer-prod --email owner@example.com
//
// The service-account key must never be committed or shared. Delete the key
// from Google Cloud after use, or use `gcloud auth application-default login`.
// Against the emulator, set FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 instead.

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((pairs, value, index, all) => {
    if (value.startsWith('--')) pairs.push([value.slice(2), all[index + 1]]);
    return pairs;
  }, []),
);

if (!args.project || !args.email) {
  console.error('Usage: node scripts/set-owner.mjs --project <id> --email <owner email>');
  process.exit(2);
}

initializeApp({ projectId: args.project });
const auth = getAuth();
const user = await auth.getUserByEmail(args.email);
if (!user.emailVerified) {
  console.error('The owner account must verify its email first.');
  process.exit(1);
}
await auth.setCustomUserClaims(user.uid, { ...(user.customClaims ?? {}), role: 'owner' });
// Staff marker: lets the rules stop anyone from suspending the owner.
await getFirestore().doc(`staff/${user.uid}`).set({ role: 'owner', updatedAt: FieldValue.serverTimestamp() });
await getFirestore().collection('auditLogs').add({
  actorId: 'bootstrap-script',
  action: 'role.set',
  targetType: 'user',
  targetId: user.uid,
  details: { role: 'owner' },
  createdAt: FieldValue.serverTimestamp(),
});
console.log(`Owner role set for uid ${user.uid}. They must sign out and in again.`);
