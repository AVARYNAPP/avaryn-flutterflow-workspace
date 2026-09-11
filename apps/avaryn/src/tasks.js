import {canCreateTask} from './horse-access.js';
import {taskToday,taskDayLabel,taskOrder,shiftTaskDay} from './task-timing.js';
const terminal=new Set(['completed','done','cancelled']);
export function renderTasks(state,ctx){
 const today=taskToday(state),day=state.selectedDay||today;
 const tasks=(state.tasks||[]).filter(t=>(!t.date||t.date===day)&&(state.route!=='horse-tasks'||t.horseId===state.horseId)).sort(taskOrder);
 const open=tasks.filter(t=>!terminal.has(t.status)),complete=tasks.filter(t=>terminal.has(t.status)),done=complete.filter(t=>t.status!=='cancelled').length;
 const cards=rows=>rows.map(t=>ctx.taskCard(t,{showInstruction:true,showHorse:true,showAssignee:true,showAction:true})).join('');
 const section=(label,rows)=>rows.length?`<section class="section task-group"><div class="section-heading"><h2>${ctx.esc(label)} <span class="section-count">${rows.length}</span></h2></div><div class="tasks-list">${cards(rows)}</div></section>`:'';
 const activeStable=state.backend?.organizations?.find(o=>o.id===state.backend.organizationId)?.name;
 const introduction=state.backend?.connected&&state.route!=='horse-tasks'?(activeStable?`Je eigen taken uit alle stallen, plus het werk dat je mag zien bij ${activeStable}.`:'Je eigen taken uit alle stallen.'):'Gepland voor een dag of klaar om op te pakken.';
 return `<section class="tasks-view"><header class="tasks-heading"><div class="tasks-heading-main"><h1>Taken</h1>${canCreateTask(state)?`<button class="tasks-primary" data-action="new-task">${ctx.icon('plus',18)}<span>Taak toevoegen</span></button>`:''}</div><p>${ctx.esc(introduction)}</p></header>
 <div class="task-day-picker"><label class="form-field">Taken voor<input type="date" value="${day}" data-task-day></label><div class="task-day-shortcuts"><button class="button-secondary" data-action="select-day" data-day="${today}" aria-pressed="${day===today}">Vandaag</button><button class="button-secondary" data-action="select-day" data-day="${shiftTaskDay(today,1)}" aria-pressed="${day===shiftTaskDay(today,1)}">Morgen</button></div></div>
 <div class="tasks-overview"><div><div class="tasks-progress-meta"><span class="tasks-progress-label">${ctx.esc(taskDayLabel(day,today))} & algemene taken</span><span class="tasks-count" aria-label="${open.length} open taken">${open.length}<span>open</span></span></div><strong>${done} van ${tasks.length} ${tasks.length===1?'taak':'taken'} afgerond</strong></div><div class="tasks-progress" role="progressbar" aria-label="Afgeronde taken" aria-valuemin="0" aria-valuemax="${Math.max(tasks.length,1)}" aria-valuenow="${done}"><span style="width:${tasks.length?Math.round(done/tasks.length*100):0}%"></span></div></div>
 ${section(taskDayLabel(day,today),open.filter(t=>t.date))}${section('Algemene taken',open.filter(t=>!t.date))}
 ${open.length?'':`<div class="tasks-all-done"><span>${ctx.icon('check',26)}</span><h2>${tasks.length?'Alles voor nu gedaan':'Geen taken voor deze dag'}</h2><p>Kies een andere dag of voeg een taak toe.</p></div>`}
 ${complete.length?`<details class="tasks-completed"${open.length?'':' open'}><summary><span>${ctx.icon('check',18)} ${complete.some(t=>t.status==='cancelled')?'Afgesloten':'Afgerond'} <small>${complete.length}</small></span>${ctx.icon('chevron-down',18)}</summary><div class="tasks-list tasks-list--completed">${cards(complete)}</div></details>`:''}</section>`;
}
