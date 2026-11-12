export const normaliseSearch=(value:string)=>value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^\p{L}\p{N}]+/gu,' ').trim();

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

export function matchesFuzzySearch(text:string,query:string) {
  const terms=normaliseSearch(query).split(/\s+/).filter(Boolean);
  if(!terms.length)return true;
  const words=text.split(' ');
  return terms.every(term=>words.some(word=>word.includes(term) || closeWord(term,word)));
}
