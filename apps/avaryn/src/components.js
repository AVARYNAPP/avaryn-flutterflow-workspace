import {taskToday,taskWhenLabel} from './task-timing.js';
export const esc = value => String(value ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const paths = {
  menu:'<path d="M4 6h16M4 12h16M4 18h16"/>',
  camera:'<path d="M8 5l2-2h4l2 2h4a2 2 0 0 1 2 2v12H2V7a2 2 0 0 1 2-2h4Z"/><circle cx="12" cy="12" r="4"/>',
  shield:'<path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6l8-3Z"/><path d="m8 12 3 3 5-6"/>',
  document:'<path d="M6 2h8l5 5v15H6V2Zm8 0v6h5M9 12h7m-7 4h7"/>',
  target:'<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/>',
  store:'<path d="M4 10v11h16V10M2 10l2-7h16l2 7M2 10c0 3 5 3 5 0 0 3 5 3 5 0 0 3 5 3 5 0 0 3 5 3 5 0M9 21v-7h6v7"/>',
  book:'<path d="M12 5v16M12 5C8 2 4 3 2 4v15c4-2 7-1 10 2 3-3 6-4 10-2V4c-2-1-6-2-10 1Z"/>',
  mail:'<rect x="2" y="4" width="20" height="16" rx="3"/><path d="m2 6 10 7L22 6"/>',
  sparkles:'<path d="m12 3 2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5L12 3ZM20 2v4m-2-2h4"/>',
  help:'<circle cx="12" cy="12" r="9"/><path d="M9 9a3 3 0 1 1 5 2c-2 1-2 1-2 3m0 3v1"/>',
  chart:'<path d="M4 3v18h18M8 16l4-6 4 3 5-8"/>',
  briefcase:'<rect x="3" y="7" width="18" height="14" rx="2"/><path d="M8 7V3h8v4M3 12c6 4 12 4 18 0"/>',
  'credit-card':'<rect x="2" y="4" width="20" height="16" rx="3"/><path d="M2 9h20M6 15h4"/>',

  today:'<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 3v4m10-4v4M3 10h18m-13 5 3 3 5-5"/>',
  calendar:'<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 3v4m10-4v4M3 10h18m4 4h2m4 0h2m-8 4h2"/>',
  horse:'<path d="M4 4h4v8a4 4 0 0 0 8 0V4h4v8a8 8 0 0 1-16 0V4Z"/><path d="M6 7h.01M6 12h.01M18 7h.01M18 12h.01M8 17h.01M16 17h.01"/>',
  arena:'<rect x="2" y="5" width="20" height="14" rx="4"/><rect x="5" y="8" width="14" height="8" rx="2"/><path d="M7 5V3m10 2V3M7 21v-2m10 2v-2"/>',
  pasture:'<path d="M3 20h18M3 13c4-4 8-4 12 0m-6 1c4-4 8-4 12-1M6 16v4m6-4v4m6-4v4M6 17h12"/><circle cx="17" cy="6" r="2.5"/>',
  fence:'<path d="M4 21V6l2-3 2 3v15M16 21V6l2-3 2 3v15M8 9h8M8 17h8M4 9H2m20 0h-2M4 17H2m20 0h-2"/>',
  box:'<rect x="3" y="4" width="18" height="17" rx="1.5"/><path d="M3 10h18M7 4v6m5-6v6m5-6v6M6 13h12v8M6 13l12 8m0-8L6 21"/>',
  walker:'<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="2"/><path d="M12 3.5V10m8.5 2H14m-2 8.5V14M3.5 12H10M6 5.8 3 6l.3-3"/>',
  wash:'<path d="M5 21V7a4 4 0 0 1 8 0v1M10 11h8l-1-3h-6l-1 3Zm2 4v1m4-1v1m-2 3v1m-4-1v1m8-1v1"/>',
  locker:'<rect x="4" y="3" width="16" height="18" rx="1.5"/><path d="M12 3v18M7 7h2m6 0h2m-7 5v3m4-3v3"/>',
  roles:'<circle cx="10" cy="7" r="3"/><path d="M3 21v-3a7 7 0 0 1 12-4.9M16 8h5m-2.5-2.5v5M15 18l2 2 4-5"/>',
  stable:'<path d="M3 10 6 5l6-3 6 3 3 5v11H3V10ZM3 10h18M9 21v-8h6v8M9 13l6 8m0-8-6 8"/><path d="M10 6h4v3h-4Z"/>',
  check:'<path d="m5 12 4 4L19 6"/>',
  tasks:'<rect x="5" y="4" width="15" height="17" rx="3"/><path d="M9 3h6v4H9V3Zm0 9 2 2 4-4m-6 8h6"/>',
  feed:'<path d="M3 14h18l-2 6H5l-2-6Zm3-7 3 4m3-8v8m6-4-3 4"/>',
  users:'<circle cx="9" cy="8" r="3"/><path d="M3 21v-3a6 6 0 0 1 12 0v3m2-16a3 3 0 0 1 0 6m2 10v-3a5 5 0 0 0-3-4"/>',
  sun:'<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1 1m12 12 1 1M5 19l1-1M18 6l1-1"/>',
  sunrise:'<path d="M2 18h20M4 21h16M6 18a6 6 0 0 1 12 0M12 3v4m-8 4 3 2m13-2-3 2M9 6l3-3 3 3"/>',
  moon:'<path d="M20 14A8 8 0 0 1 10 4a8.5 8.5 0 1 0 10 10Z"/>',
  plus:'<path d="M12 5v14M5 12h14"/>',
  'chevron-right':'<path d="m9 5 7 7-7 7"/>',
  'chevron-left':'<path d="m15 5-7 7 7 7"/>',
  'chevron-down':'<path d="m5 9 7 7 7-7"/>',
  'arrow-right':'<path d="M4 12h16m-6-6 6 6-6 6"/>',
  'arrow-left':'<path d="M20 12H4m6-6-6 6 6 6"/>',
  'arrow-up-right':'<path d="M6 18 18 6M6 6h12v12"/>',
  clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  location:'<path d="M19 10c0 6-7 11-7 11S5 16 5 10a7 7 0 0 1 14 0Z"/><circle cx="12" cy="10" r="2"/>',
  edit:'<path d="m14 5 5 5M4 20l4-1L20 7a3 3 0 0 0-4-4L4 15v5Z"/>',
  close:'<path d="m6 6 12 12M6 18 18 6"/>',
  settings:'<path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="3"/><circle cx="15" cy="17" r="3"/>',
  heart:'<path d="M20 5c-3-3-7-1-8 2-1-3-5-5-8-2-5 5 8 15 8 15S25 10 20 5Z"/>',
  leaf:'<path d="M20 3c0 11-2 17-10 17-5 0-7-5-4-9C10 6 17 8 20 3ZM4 22l11-11"/>',
  info:'<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10v1"/>',
  more:'<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
  trophy:'<path d="M7 3h10v7a5 5 0 0 1-10 0V3ZM7 5H3v3a4 4 0 0 0 4 4m10-7h4v3a4 4 0 0 1-4 4m-5 3v6m-5 0h10"/>'
};
paths.stall = paths.box;
paths.paddock = paths.fence;
export function icon(name,size=20){return `<svg class="icon" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] || paths.calendar}</svg>`;}
const initials=value=>{const parts=String(value).split(' ').filter(Boolean);return [parts[0]?.[0],parts.length>1?parts.at(-1)?.[0]:''].join('').toUpperCase();};
export function createContext(state){
  const horse=id=>state.horses.find(h=>h.id===id);
  const activityCard=(a,options={})=>{
    const h=horse(a.horseId); const done=['done','completed'].includes(a.status);
    return `<button class="event-card ${done?'is-done':''}" data-action="open-activity" data-id="${esc(a.id)}" aria-label="${esc(a.time+' · '+(h?.name||'Stal')+' · '+a.title)}"><span class="event-time">${esc(a.time)}<small>${esc(a.end)}</small></span>${options.showHorse===false?'':`<img class="event-photo" src="${esc(h?.image||'assets/orion.png')}" alt="" loading="lazy">`}<span class="event-main"><span class="event-kind">${esc(a.type)}<span class="mini-status ${done?'done':''}">${done?'Afgerond':'Gepland'}</span></span><strong>${esc(h?.name||'Stal')} <span class="soft-dot">·</span> ${esc(a.title)}</strong><span class="event-context">${[a.location,a.person].filter(value=>String(value||'').trim()).map(esc).join(' <span>·</span> ')}</span></span><span class="card-arrow">${icon('chevron-right',17)}</span></button>`;
  };
  const taskCard=(t,options={})=>{
    const h=horse(t.horseId); const done=['done','completed'].includes(t.status);
    return `<button class="task-card ${done?'is-done':''}" data-action="open-task" data-id="${esc(t.id)}" aria-label="${esc([t.title,taskWhenLabel(t,taskToday(state)),t.organizationName,t.location].filter(Boolean).join(' · '))}"><span class="task-marker ${done?'checked':''}">${done?icon('check',15):''}</span><span class="task-main"><span class="task-meta">${[taskWhenLabel(t,taskToday(state)),t.organizationName,t.location,h?.name].filter(Boolean).map(esc).join(' <span>·</span> ')}</span><strong>${esc(t.title)}</strong>${options.showInstruction?`<span class="task-instruction">${esc(t.note)}</span>`:''}<span class="task-assignee"><span class="tiny-avatar">${esc(initials(t.assignee||''))}</span>${esc(t.assignee)}${done?'<span class="text-success">Afgerond</span>':''}</span></span><span class="card-arrow">${icon('chevron-right',17)}</span></button>`;
  };
  return {icon,esc,horse,activityCard,taskCard};
}
