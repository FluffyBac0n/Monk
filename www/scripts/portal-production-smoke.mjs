#!/usr/bin/env node

/**
 * Destructive-but-self-cleaning smoke test for the real `eurotrex` Firebase
 * project. It creates two temporary Auth users and isolated Firestore records,
 * verifies the owner-to-admin publication flow, then removes everything it
 * created. Run only while signed in with the Firebase CLI.
 */

import crypto from 'node:crypto';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const currentDirectory = path.dirname(fileURLToPath(import.meta.url));

const projectId = 'eurotrex';
const apiKey = 'AIzaSyDxLgyIQfsdCy3RqnonbjnV2nc3S6O7Tgk';
const databaseRoot = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
const identityRoot = 'https://identitytoolkit.googleapis.com/v1';
const firebaseToolsRoot = path.resolve(currentDirectory, '../../node_modules/firebase-tools/lib');

const cliAuthModule = await import(pathToFileURL(path.join(firebaseToolsRoot, 'auth.js')));
const requireAuthModule = await import(pathToFileURL(path.join(firebaseToolsRoot, 'requireAuth.js')));
const apiModule = await import(pathToFileURL(path.join(firebaseToolsRoot, 'apiv2.js')));
const cliAuth = cliAuthModule.default || cliAuthModule;
const { requireAuth } = requireAuthModule.default || requireAuthModule;
const { getAccessToken } = apiModule.default || apiModule;

const suffix = `${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
const ownerEmail = `eurotrex-owner-smoke-${suffix}@example.com`;
const adminEmail = `eurotrex-admin-smoke-${suffix}@example.com`;
const password = `Et!${crypto.randomBytes(18).toString('base64url')}`;
const submissionId = `smoke-submission-${suffix}`;
const lodgingId = `smoke-lodging-${suffix}`;
const auditId = `smoke-audit-${suffix}`;

const cleanupDocuments = new Set();
const cleanupUsers = [];

function stringValue(value) {
  return { stringValue: value };
}

function numberValue(value) {
  return Number.isInteger(value)
    ? { integerValue: String(value) }
    : { doubleValue: value };
}

function booleanValue(value) {
  return { booleanValue: value };
}

function nullValue() {
  return { nullValue: null };
}

function documentName(documentPath) {
  return `projects/${projectId}/databases/(default)/documents/${documentPath}`;
}

async function requestJson(label, url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      'content-type': 'application/json',
      ...(options.headers || {}),
    },
  });
  const text = await response.text();
  let body = {};
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = { raw: text };
    }
  }
  if (!response.ok) {
    const error = new Error(`${label} failed with HTTP ${response.status}.`);
    error.status = response.status;
    error.body = body;
    throw error;
  }
  return body;
}

async function createUser(email) {
  const user = await requestJson(
    'Temporary Firebase user creation',
    `${identityRoot}/accounts:signUp?key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  cleanupUsers.push(user);
  return user;
}

async function deleteUser(user) {
  await requestJson(
    'Temporary Firebase user deletion',
    `${identityRoot}/accounts:delete?key=${encodeURIComponent(apiKey)}`,
    { method: 'POST', body: JSON.stringify({ idToken: user.idToken }) },
  );
}

async function firestoreCommit(idToken, writes) {
  return requestJson(
    'Firestore commit',
    `${databaseRoot}:commit?key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      headers: { authorization: `Bearer ${idToken}` },
      body: JSON.stringify({ writes }),
    },
  );
}

async function deleteTrustedDocument(documentPath, accessToken) {
  const response = await fetch(`${databaseRoot}/${documentPath}`, {
    method: 'DELETE',
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (!response.ok && response.status !== 404) {
    throw new Error(`Cleanup failed for ${documentPath} with HTTP ${response.status}.`);
  }
}

async function main() {
  const account = cliAuth.getGlobalDefaultAccount();
  if (!account) throw new Error('Sign in with the Firebase CLI before running this test.');
  await requireAuth({ project: projectId, user: account.user, tokens: account.tokens });
  const trustedAccessToken = await getAccessToken();

  const trail = await requestJson(
    'Public trail read',
    `${databaseRoot}/trails/cyprus-e4?key=${encodeURIComponent(apiKey)}`,
  );
  const stages = await requestJson(
    'Public stage read',
    `${databaseRoot}/trails/cyprus-e4/stages?pageSize=1&key=${encodeURIComponent(apiKey)}`,
  );
  if (!stages.documents?.length) throw new Error('No Cyprus E4 stage is available for the test.');

  const stage = stages.documents[0];
  const stageId = stage.name.split('/').pop();
  const stageName = stage.fields?.name?.stringValue || stageId;
  const stageSequence = Number(stage.fields?.sequence?.integerValue || stage.fields?.sequence?.doubleValue || 0);
  const trailName = trail.fields?.name?.stringValue || 'E4 — Cyprus';

  const anonymousSubmissions = await fetch(
    `${databaseRoot}/accommodationSubmissions?pageSize=1&key=${encodeURIComponent(apiKey)}`,
  );
  if (anonymousSubmissions.status !== 403) {
    throw new Error(`Anonymous submission access returned HTTP ${anonymousSubmissions.status}, expected 403.`);
  }

  const owner = await createUser(ownerEmail);
  const ownerProfilePath = `ownerProfiles/${owner.localId}`;
  cleanupDocuments.add(ownerProfilePath);
  await firestoreCommit(owner.idToken, [{
    update: {
      name: documentName(ownerProfilePath),
      fields: {
        email: stringValue(ownerEmail),
        businessName: stringValue('EuroTrex private smoke test'),
      },
    },
    updateTransforms: [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ],
    currentDocument: { exists: false },
  }]);

  const submissionPath = `accommodationSubmissions/${submissionId}`;
  cleanupDocuments.add(submissionPath);
  await firestoreCommit(owner.idToken, [{
    update: {
      name: documentName(submissionPath),
      fields: {
        trailId: stringValue('cyprus-e4'),
        trailName: stringValue(trailName),
        stageId: stringValue(stageId),
        stageName: stringValue(stageName),
        stageSequence: numberValue(stageSequence),
        name: stringValue('EuroTrex private smoke stay'),
        type: stringValue('Guesthouse'),
        village: stringValue('Test village'),
        address: stringValue('1 Test Way'),
        description: stringValue('Temporary record used to verify the private host portal workflow.'),
        phone: stringValue('+357 00000000'),
        email: stringValue(ownerEmail),
        website: stringValue('https://example.com'),
        whatsapp: stringValue(''),
        googleMapsUrl: stringValue(''),
        priceMinEur: numberValue(0),
        priceMaxEur: numberValue(10),
        distanceFromTrailKm: numberValue(0),
        capacityPeople: nullValue(),
        monthsOpen: stringValue(''),
        latitude: nullValue(),
        longitude: nullValue(),
        policyAgreement: booleanValue(true),
        ownerId: stringValue(owner.localId),
        ownerEmail: stringValue(ownerEmail),
        status: stringValue('pending'),
        reviewNote: stringValue(''),
      },
    },
    updateTransforms: [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ],
    currentDocument: { exists: false },
  }]);

  const ownerQuery = await requestJson(
    'Owner submission query',
    `${databaseRoot}:runQuery?key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      headers: { authorization: `Bearer ${owner.idToken}` },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'accommodationSubmissions' }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'ownerId' },
              op: 'EQUAL',
              value: stringValue(owner.localId),
            },
          },
        },
      }),
    },
  );
  if (!ownerQuery.some((row) => row.document?.name?.endsWith(`/${submissionId}`))) {
    throw new Error('The owner could not read the submission they created.');
  }

  let ownerApprovalDenied = false;
  try {
    await firestoreCommit(owner.idToken, [{
      update: {
        name: documentName(submissionPath),
        fields: { status: stringValue('approved') },
      },
      updateMask: { fieldPaths: ['status'] },
      currentDocument: { exists: true },
    }]);
  } catch (error) {
    ownerApprovalDenied = error.status === 403;
  }
  if (!ownerApprovalDenied) throw new Error('An owner was unexpectedly able to self-approve.');

  const admin = await createUser(adminEmail);
  const adminPath = `admins/${admin.localId}`;
  cleanupDocuments.add(adminPath);
  await requestJson(
    'Trusted administrator bootstrap',
    `${databaseRoot}/${adminPath}`,
    {
      method: 'PATCH',
      headers: { authorization: `Bearer ${trustedAccessToken}` },
      body: JSON.stringify({
        fields: {
          email: stringValue(adminEmail),
          role: stringValue('private-smoke-test'),
          createdAt: { timestampValue: new Date().toISOString() },
        },
      }),
    },
  );

  const lodgingPath = `trails/cyprus-e4/lodgings/${lodgingId}`;
  const auditPath = `accommodationAudit/${auditId}`;
  cleanupDocuments.add(lodgingPath);
  cleanupDocuments.add(auditPath);
  await firestoreCommit(admin.idToken, [
    {
      update: {
        name: documentName(lodgingPath),
        fields: {
          trailId: stringValue('cyprus-e4'),
          stageId: stringValue(stageId),
          stageName: stringValue(stageName),
          name: stringValue('EuroTrex private smoke stay'),
          sourceSubmissionId: stringValue(submissionId),
          ownerId: stringValue(owner.localId),
          priceMinEur: numberValue(0),
        },
      },
      currentDocument: { exists: false },
    },
    {
      update: {
        name: documentName(submissionPath),
        fields: {
          status: stringValue('approved'),
          publishedLodgingId: stringValue(lodgingId),
          publishedTrailId: stringValue('cyprus-e4'),
          reviewNote: stringValue('Synthetic private smoke test'),
          reviewedBy: stringValue(admin.localId),
        },
      },
      updateMask: {
        fieldPaths: [
          'status',
          'publishedLodgingId',
          'publishedTrailId',
          'reviewNote',
          'reviewedBy',
        ],
      },
      updateTransforms: [
        { fieldPath: 'reviewedAt', setToServerValue: 'REQUEST_TIME' },
        { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
      ],
      currentDocument: { exists: true },
    },
    {
      update: {
        name: documentName(auditPath),
        fields: {
          submissionId: stringValue(submissionId),
          lodgingId: stringValue(lodgingId),
          trailId: stringValue('cyprus-e4'),
          ownerId: stringValue(owner.localId),
          accommodationName: stringValue('EuroTrex private smoke stay'),
          action: stringValue('approved'),
          note: stringValue('Synthetic private smoke test'),
          actorId: stringValue(admin.localId),
          actorEmail: stringValue(adminEmail),
        },
      },
      updateTransforms: [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }],
      currentDocument: { exists: false },
    },
  ]);

  const published = await requestJson(
    'Public lodging read',
    `${databaseRoot}/${lodgingPath}?key=${encodeURIComponent(apiKey)}`,
  );
  if (published.fields?.priceMinEur?.integerValue !== '0') {
    throw new Error('The published zero-price value was not preserved.');
  }

  console.log(JSON.stringify({
    passed: true,
    checks: [
      'public trail and stage reads',
      'anonymous submission denial',
      'owner registration and profile creation',
      'owner submission creation and filtered query',
      'owner self-approval denial',
      'administrator approval batch and audit write',
      'public lodging read with zero-price preservation',
    ],
  }, null, 2));
}

async function cleanup() {
  const failures = [];
  try {
    const trustedAccessToken = await getAccessToken();
    for (const documentPath of [...cleanupDocuments].reverse()) {
      try {
        await deleteTrustedDocument(documentPath, trustedAccessToken);
      } catch (error) {
        failures.push(error.message);
      }
    }
  } catch (error) {
    failures.push(`Trusted cleanup authentication failed: ${error.message}`);
  }

  for (const user of cleanupUsers.reverse()) {
    try {
      await deleteUser(user);
    } catch (error) {
      failures.push(error.message);
    }
  }

  if (failures.length) {
    throw new Error(`Smoke-test cleanup was incomplete: ${failures.join(' ')}`);
  }
}

main()
  .then(cleanup)
  .catch(async (error) => {
    try {
      await cleanup();
    } catch (cleanupError) {
      console.error(cleanupError.message);
    }
    console.error(error.message);
    process.exitCode = 1;
  });
