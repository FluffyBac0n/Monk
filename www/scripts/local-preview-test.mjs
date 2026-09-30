import assert from 'node:assert/strict';
import { isLocalHttpPreview } from '../lib/local-preview.ts';

for (const origin of ['http://localhost:3000', 'http://127.0.0.1:3000', 'http://[::1]:3000']) {
  assert.equal(isLocalHttpPreview(origin), true, origin);
}
for (const origin of [
  'https://localhost:3000',
  'https://127.0.0.1:3000',
  'https://[::1]:3000',
  'https://eurotrex.andreasmic332452.chatgpt.site',
  'http://eurotrex.andreasmic332452.chatgpt.site',
  'http://localhost.example.com',
  'http://localhost@external.example',
]) {
  assert.equal(isLocalHttpPreview(origin), false, origin);
}
console.log('PASS: HTTP loopback exception; HTTPS and non-loopback protection retained.');
