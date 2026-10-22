export const esc = value => String(value ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function suffix(index) { let text=''; for(let n=index+1;n>0;n=Math.floor((n-1)/26))text=String.fromCharCode(65+(n-1)%26)+text;return text; }
export function status(row){return row?.completed_runs>0?'Vollständig bearbeitet':row?.started_at?'Begonnen':'Noch nicht begonnen';}
export function summary(rows){return {unstarted:rows.filter(r=>!r.started_at&&!r.completed_runs).length,started:rows.filter(r=>r.started_at&&!r.completed_runs).length,complete:rows.filter(r=>r.completed_runs>0).length,runs:rows.reduce((n,r)=>n+(r.completed_runs||0),0),repeats:rows.reduce((n,r)=>n+Math.max(0,(r.completed_runs||0)-1),0)};}
