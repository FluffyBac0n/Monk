import test from 'node:test';
import assert from 'node:assert/strict';
import {validateReport, validateReview, mayReview} from '../src/report-model.js';
const report = {trailId: 'cyprus-e4', category: 'signpost', passability: 'difficult', description: 'Sign fallen across the trail', latitude: 34.89, longitude: 32.87, accuracyM: 8, locationSource: 'gps', observedAtMs: Date.now(), photoIds: ['photo_0'], contactEmail: ''};
test('validates trail reports and strips injected review/ownership fields', () => {
 const clean = validateReport({...report, status: 'resolved', reporterUid: 'other', admin: true});
 assert.equal(clean.trailId, 'cyprus-e4'); assert.equal(clean.status, undefined); assert.equal(clean.reporterUid, undefined);
 for (const bad of [{trailId:'../admins'}, {latitude:NaN}, {longitude:190}, {description:'x'.repeat(501)}, {photoIds:['a','b','c','d']}, {photoIds:['a','a']}, {contactEmail:'invalid'}]) assert.throws(() => validateReport({...report,...bad}));
});
test('review access requires verified assigned membership or admin', () => {
 assert.equal(mayReview({verified:true,trailIds:['cyprus-e4']},'crete-e4'),false);
 assert.equal(mayReview({verified:true,trailIds:['cyprus-e4']},'cyprus-e4'),true);
 assert.equal(mayReview({verified:false,admin:true},'cyprus-e4'),false);
 assert.equal(mayReview({verified:true,admin:true},'crete-e4'),true);
});
test('forwarded/resolved/duplicate outcomes require meaningful context', () => {
 assert.throws(() => validateReview({status:'forwarded',priority:'normal'},'abc'));
 assert.throws(() => validateReview({status:'resolved',priority:'normal'},'abc'));
 assert.throws(() => validateReview({status:'duplicate',priority:'normal',duplicateOf:'abc'},'abc'));
 assert.equal(validateReview({status:'forwarded',priority:'high',authority:'Trail authority',note:'Sent'},'abc').status,'forwarded');
});
