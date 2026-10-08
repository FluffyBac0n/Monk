import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import ts from '../www/node_modules/typescript/lib/typescript.js';
// Exercise the actual pure export functions, without initializing browser Firebase.
const source = readFileSync(new URL('../www/lib/trail-reports.ts', import.meta.url), 'utf8');
const pure = "const reportCategories = {signpost:'Signpost'};\n" + source.slice(source.indexOf('export const reportMapUrl'));
const code = ts.transpileModule(pure, {compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const exports = await import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`);
const report = {id:'export-test',trailId:'cyprus-e4',category:'signpost',description:'Βράχος <script>alert(1)</script>',latitude:34.89,longitude:32.87,passability:'difficult',priority:'high',observedAtMs:Date.UTC(2026,9,7),contactEmail:'private@example.com',note:'CONFIDENTIAL'};
test('forwarding exports escape text and omit private contact/review fields', () => {
 const text=exports.forwardingText(report,'Cyprus E4');
 assert.ok(text.includes('34.89, 32.87')); assert.ok(!text.includes(report.contactEmail)); assert.ok(!text.includes(report.note));
 const html=exports.reportPrintHtml(report,'Cyprus E4',[]);
 assert.ok(html.includes('&lt;script&gt;')); assert.ok(!html.includes('<script>'));
 assert.ok(!html.includes(report.contactEmail));
 const email=exports.reportEmail(report,'Cyprus E4',['data:image/jpeg;base64,/9j/2Q==']);
 assert.ok(email.includes('X-Unsent: 1')); assert.ok(email.includes('Content-Disposition: attachment; filename="trail-photo-1.jpg"'));
 const body=email.split('Content-Transfer-Encoding: base64\r\n\r\n')[1].split('\r\n--')[0].replaceAll('\r\n','');
 assert.equal(Buffer.from(body,'base64').toString('utf8'),text);
});
