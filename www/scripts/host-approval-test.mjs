import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import ts from 'typescript';

// Exercise the actual client operation against the local Firestore rules.
if (!process.env.FIRESTORE_EMULATOR_HOST)
  throw new Error(
    'Run with FIRESTORE_EMULATOR_HOST=127.0.0.1:8080; production is never used.'
  );
const require = createRequire(
  new URL('../../functions/package.json', import.meta.url)
);
const {
  initializeTestEnvironment,
  assertFails,
} = require('@firebase/rules-unit-testing');
const firestore = require('firebase/firestore');
const { doc, setDoc, getDoc, getDocs, collection, updateDoc, serverTimestamp } =
  firestore;
const env = await initializeTestEnvironment({
  projectId: 'demo-eurotrex',
  firestore: {
    rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
  },
});
const source = ts.transpileModule(
  readFileSync(new URL('../lib/accommodations.ts', import.meta.url), 'utf8'),
  {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022,
    },
  }
).outputText;
const actor = {
  uid: 'host-approval-admin',
  email: 'host-approval-admin@example.com',
};
const client = (id, verified = true) =>
  env
    .authenticatedContext(id, {
      email: `${id}@example.com`,
      email_verified: verified,
    })
    .firestore();
function library(db) {
  const exports = {};
  new Function('exports', 'require', source)(exports, (path) =>
    path === 'firebase/firestore'
      ? firestore
      : path === './firebase'
        ? { db }
        : {}
  );
  return exports;
}
try {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [path, value] of Object.entries({
      'admins/host-approval-admin': {},
      'ownerProfiles/host-approval-owner': {
        email: 'host-approval-owner@example.com',
        businessName: 'Approval test host',
        accessStatus: 'pending',
      },
      'ownerProfiles/host-approval-disabled': {
        email: 'host-approval-disabled@example.com',
        businessName: 'Disabled host',
        accessStatus: 'disabled',
      },
      'ownerProfiles/legacy-owner': {
        email: 'legacy-owner@example.com',
        businessName: 'Legacy company',
      },
      'accommodationSubmissions/legacy-listing': { ownerId: 'legacy-owner' },
      'accommodationSubmissions/pending-listing': {
        ownerId: 'host-approval-individual',
      },
    }))
      await setDoc(doc(db, path), value);
  });
  const admin = client(actor.uid),
    owner = client('host-approval-owner');
  const individual = 'host-approval-individual';
  await library(client(individual, false)).registerOwnerProfile(
    { uid: individual, email: `${individual}@example.com` },
    { firstName: 'Alex', lastName: 'Walker' }
  );
  const individualProfile = (
    await getDoc(doc(admin, `ownerProfiles/${individual}`))
  ).data();
  assert.equal(individualProfile.firstName, 'Alex');
  assert.equal(individualProfile.lastName, 'Walker');
  assert.equal(individualProfile.businessName, '');
  assert.equal(individualProfile.accessStatus, 'pending');
  await assertFails(
    getDoc(doc(client(individual, false), `ownerProfiles/${individual}`))
  );
  await assertFails(
    getDoc(doc(client(individual), 'accommodationSubmissions/pending-listing'))
  );
  await assertFails(getDocs(collection(client(individual), 'ownerProfiles')));
  await assertFails(
    updateDoc(doc(client(individual), `ownerProfiles/${individual}`), {
      accessStatus: 'active',
    })
  );
  await assertFails(
    updateDoc(doc(client(individual), `ownerProfiles/${individual}`), {
      premium: true,
    })
  );
  const business = 'host-approval-business';
  await library(client(business, false)).registerOwnerProfile(
    { uid: business, email: `${business}@example.com` },
    { firstName: 'Sam', lastName: 'Host', businessName: 'Trail Guesthouse' }
  );
  assert.equal(
    (await getDoc(doc(admin, `ownerProfiles/${business}`))).data().businessName,
    'Trail Guesthouse'
  );
  assert.equal(
    (
      await getDoc(
        doc(client('legacy-owner'), 'accommodationSubmissions/legacy-listing')
      )
    ).exists(),
    true,
    'legacy active profiles remain usable'
  );
  await assertFails(
    getDoc(doc(client(individual), 'accommodationSubmissions/legacy-listing'))
  );
  const badId = 'host-approval-bad';
  const bad = client(badId, false);
  const baseProfile = {
    email: `${badId}@example.com`,
    firstName: 'Valid',
    lastName: 'Name',
    businessName: '',
    accessStatus: 'pending',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
  for (const change of [
    { firstName: '' },
    { lastName: '' },
    { firstName: 'x'.repeat(81) },
    { businessName: 'x'.repeat(161) },
    { accessStatus: 'active' },
    { email: 'forged@example.com' },
    { admin: true },
    { verified: true },
  ])
    await assertFails(
      setDoc(doc(bad, `ownerProfiles/${badId}`), { ...baseProfile, ...change })
    );
  const { lastName: unusedLastName, ...partialName } = baseProfile;
  await assertFails(setDoc(doc(bad, `ownerProfiles/${badId}`), partialName));
  await assertFails(
    setDoc(doc(bad, 'ownerProfiles/another-owner'), baseProfile)
  );
  await assert.rejects(
    library(bad).registerOwnerProfile(
      { uid: badId, email: baseProfile.email },
      { firstName: ' ', lastName: 'Name' }
    ),
    /first name/
  );
  await assertFails(getDocs(collection(owner, 'ownerProfiles')));
  await assertFails(
    updateDoc(doc(owner, 'ownerProfiles/host-approval-owner'), {
      accessStatus: 'active',
    })
  );
  await assertFails(
    library(owner).approveOwnerProfile(
      { uid: 'host-approval-owner', email: 'host-approval-owner@example.com' },
      'host-approval-owner'
    )
  );
  await assertFails(
    library(client(actor.uid, false)).approveOwnerProfile(
      actor,
      'host-approval-owner'
    )
  );
  const before = (await getDocs(collection(admin, 'accommodationAudit'))).size;
  await assertFails(
    library(admin).approveOwnerProfile(
      { ...actor, email: 'incorrect-actor@example.com' },
      'host-approval-owner'
    )
  );
  assert.equal(
    (await getDoc(doc(admin, 'ownerProfiles/host-approval-owner'))).data()
      .accessStatus,
    'pending',
    'audit failure must roll back approval'
  );
  await library(admin).approveOwnerProfile(actor, 'host-approval-owner');
  const profile = (
    await getDoc(doc(admin, 'ownerProfiles/host-approval-owner'))
  ).data();
  assert.equal(profile.accessStatus, 'active');
  assert.equal(profile.email, 'host-approval-owner@example.com');
  assert.equal(profile.businessName, 'Approval test host');
  const audit = await getDocs(collection(admin, 'accommodationAudit'));
  assert.equal(audit.size, before + 1);
  const event = audit.docs
    .map((d) => d.data())
    .find((d) => d.ownerId === 'host-approval-owner');
  assert.equal(event.actorId, actor.uid);
  assert.match(event.note, /Host account approved/);
  assert.equal(
    (await getDoc(doc(owner, 'ownerProfiles/host-approval-owner'))).data()
      .accessStatus,
    'active'
  );
  await assert.rejects(
    library(admin).approveOwnerProfile(actor, 'host-approval-owner'),
    /no longer awaiting approval/
  );
  await assert.rejects(
    library(admin).approveOwnerProfile(actor, 'host-approval-disabled'),
    /no longer awaiting approval/
  );
  await assert.rejects(
    library(admin).approveOwnerProfile(actor, 'missing-host'),
    /no longer exists/
  );
  assert.equal(
    (await getDocs(collection(admin, 'accommodationAudit'))).size,
    before + 1
  );
  assert.equal(
    (await getDoc(doc(admin, 'admins/host-approval-owner'))).exists(),
    false
  );
  assert.equal(
    (
      await getDoc(doc(admin, 'trailReportAccess/host-approval-owner'))
    ).exists(),
    false
  );
  console.log(
    'PASS: individual and business registration, legacy profile access, private personal names, malformed/forged profile denial, pending/verified gating, admin approval, atomic audit, self-approval denial, stale/disabled/deleted account protection and no additional role grants.'
  );
} finally {
  await env.cleanup();
}
