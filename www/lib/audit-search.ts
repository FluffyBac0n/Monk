import {normaliseSearch} from './fuzzy-search';
export {matchesFuzzySearch as matchesAuditSearch} from './fuzzy-search';
import type {EraEvent} from './era';

/** Search the stored event fields plus readable local and ISO timestamp variants. */
export function auditSearchText(event:EraEvent) {
  const values:string[]=[];
  function collect(value:unknown) {
    if(typeof value==='string' || typeof value==='number')values.push(String(value));
    else if(Array.isArray(value))value.forEach(collect);
    else if(value && typeof value==='object' && !('toDate' in value))Object.values(value).forEach(collect);
  }
  collect(event);
  const date=event.createdAt?.toDate();
  if(date && Number.isFinite(date.getTime())) {
    const y=date.getFullYear(),m=date.getMonth()+1,d=date.getDate();
    const pad=(n:number)=>String(n).padStart(2,'0');
    values.push(date.toLocaleString(),date.toISOString(),String(date.getTime()),String(Math.floor(date.getTime()/1000)),
      `${y}-${pad(m)}-${pad(d)}`,`${d}/${m}/${y}`,`${pad(d)}/${pad(m)}/${y}`,`${m}/${d}/${y}`,
      date.toLocaleDateString('en-GB',{day:'numeric',month:'long',year:'numeric'}),date.toLocaleDateString('en-GB',{month:'short'}),
      `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`);
  }
  return normaliseSearch(values.join(' '));
}
