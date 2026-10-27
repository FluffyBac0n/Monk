import type {EraEvent} from './era';

const normalise=(value:string)=>value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^\p{L}\p{N}]+/gu,' ').trim();

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
  return normalise(values.join(' '));
}

// Bounded Damerau-Levenshtein distance: tolerate name/action typos, never fuzzy-match numbers.
function closeWord(a:string,b:string) {
  const limit=a.length>=8?2:1;
  if(a.length<4 || Math.abs(a.length-b.length)>limit || /\d/u.test(a+b))return false;
  let previous=Array.from({length:b.length+1},(_,i)=>i),older=previous;
  for(let i=1;i<=a.length;i++) {
    const row=[i];
    for(let j=1;j<=b.length;j++) {
      row[j]=Math.min(row[j-1]+1,previous[j]+1,previous[j-1]+(a[i-1]===b[j-1]?0:1));
      if(i>1 && j>1 && a[i-1]===b[j-2] && a[i-2]===b[j-1])row[j]=Math.min(row[j],older[j-2]+1);
    }
    older=previous;previous=row;
  }
  return previous[b.length]<=limit;
}

export function matchesAuditSearch(text:string,query:string) {
  const terms=normalise(query).split(/\s+/).filter(Boolean);
  if(!terms.length)return true;
  const words=text.split(' ');
  return terms.every(term=>words.some(word=>word.includes(term) || closeWord(term,word)));
}
