// Refuses to deploy the public pages while owner placeholders remain, so a
// half-finished privacy policy or deletion page never goes live. Runs as the
// hosting predeploy step in firebase.json, and with `npm run check:hosting`.

import { readdirSync, readFileSync } from 'node:fs';

const dir = new URL('../hosting/', import.meta.url);
const missing = [];
for (const name of readdirSync(dir).filter((file) => file.endsWith('.html'))) {
  const found = readFileSync(new URL(name, dir), 'utf8').match(/\{\{[A-Z_]+\}\}/g) ?? [];
  for (const placeholder of new Set(found)) missing.push(`${name}: ${placeholder}`);
}
if (missing.length > 0) {
  console.error('Fill in these placeholders before deploying the public pages:');
  for (const line of missing) console.error(`  ${line}`);
  process.exit(1);
}
console.log('Public pages are ready to deploy.');
