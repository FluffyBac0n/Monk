// Run after deploying reviewTrailReport. Defaults to a count-only dry run.
import {authenticatedRequest, allPages, databaseName} from './firestore-backup-lib.mjs';
import {officialTrailIssue} from '../functions/src/report-model.js';
const project = process.argv[process.argv.indexOf('--project') + 1];
if (!process.argv.includes('--project') || !project) throw new Error('Pass --project <project-id>.');
const apply = process.argv.includes('--apply');
const root = `https://firestore.googleapis.com/v1/${databaseName(project)}/documents`;
const request = await authenticatedRequest(project);
const [reports, notices] = await Promise.all([
  allPages(request, `${root}/trailReports`, 'documents', {pageSize:1000}),
  allPages(request, `${root}/trailIssues`, 'documents', {pageSize:1000}),
]);
const byId = new Map(reports.map(doc => [doc.name.split('/').at(-1), doc]));
const existing = new Set(notices.map(doc => doc.name.split('/').at(-1)));
const safeKeys = ['trailId','category','description','passability','latitude','longitude','status','uploadState'];
let published = 0, removed = 0;
for (const id of new Set([...byId.keys(), ...existing])) {
  const source = byId.get(id);
  const report = Object.fromEntries(safeKeys.map(key => {
    const value = source?.fields?.[key];
    return [key, value?.stringValue ?? (value?.doubleValue != null ? Number(value.doubleValue) : value?.integerValue != null ? Number(value.integerValue) : null)];
  }));
  const issue = officialTrailIssue(report);
  if (!issue && !existing.has(id)) continue;
  const name = `${databaseName(project)}/documents/trailIssues/${id}`;
  const write = issue ? {update:{name, fields:Object.fromEntries([
    ...Object.keys(issue).map(key => [key, source.fields[key]]),
    ['updatedAt', source.fields.updatedAt],
  ])}} : {delete:name};
  if (apply) await request(`${root}:commit`, {method:'POST',body:JSON.stringify({writes:[
    {verify:`${databaseName(project)}/documents/trailReports/${id}`, currentDocument:source ? {updateTime:source.updateTime} : {exists:false}}, write,
  ]})});
  if (issue) published++; else removed++;
}
console.log(JSON.stringify({project, applied:apply, activeIssues:published, removedIssues:removed}));
