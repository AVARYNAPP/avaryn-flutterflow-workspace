import {esc,icon} from './components.js';
import {taskToday,shiftTaskDay} from './task-timing.js';

// One task form for demo and connected mode; only option sources/field IDs differ.
export function renderTaskForm(state,{id,horseOptions,assigneeName,assigneeOptions,locations=[]}){
 const today=taskToday(state),day=state.selectedDay||today;
 const when=state.route==='stable'?'none':state.route==='tasks'||state.route==='planning'?(day===today?'today':day===shiftTaskDay(today,1)?'tomorrow':'custom'):'today';
 return `<form id="${id}" data-task-form data-today="${today}">
 <label class="form-field">Wat moet er gebeuren?<input name="title" required maxlength="180" placeholder="Bijvoorbeeld Looppad vegen"></label>
 <label class="form-field">Paard, optioneel<select name="horseId">${horseOptions}</select></label>
 <label class="form-field">Wanneer<select name="when">${[['none','Geen datum'],['today','Vandaag'],['tomorrow','Morgen'],['custom','Kies datum']].map(([value,label])=>`<option value="${value}"${value===when?' selected':''}>${label}</option>`).join('')}</select></label>
 <label class="form-field" data-task-date${when==='custom'?'':' hidden'}>Datum<input name="date" type="date" value="${day}"${when==='custom'?' required':' disabled'}></label>
 <p class="horse-muted" data-task-general${when==='none'?'':' hidden'}>Blijft bij Algemene taken staan tot de taak is afgerond.</p>
 <div data-task-clock${when==='none'?' hidden':''}><label class="task-time-toggle"><input name="addTime" type="checkbox"${when==='none'?' disabled':''}> Tijd toevoegen <span class="horse-muted">(optioneel)</span></label>
 <label class="form-field" data-task-time hidden>Tijd<input name="time" type="time" disabled></label></div>
 <label class="form-field">Waar<input name="location" list="task-locations" required maxlength="160" placeholder="Bijvoorbeeld Weide 6 of Binnenbak"></label>
 <datalist id="task-locations">${[...new Set(locations.filter(Boolean))].map(name=>`<option value="${esc(name)}"></option>`).join('')}</datalist>
 <label class="form-field">Verantwoordelijke<select name="${assigneeName}" required>${assigneeOptions}</select></label>
 <label class="form-field">Instructie<textarea name="note" required placeholder="Wat is handig om te weten voor deze taak?"></textarea></label>
 <footer class="modal-footer"><button type="button" class="button-secondary" data-action="close-modal">Annuleren</button><button type="submit" class="button-primary">${icon('check',17)} Taak opslaan</button></footer></form>`;
}
export function updateTaskTiming(target){
 const form=target.closest?.('[data-task-form]');if(!form||!['when','addTime'].includes(target.name))return false;
 const when=form.elements.when.value,dated=when!=='none',custom=when==='custom',toggle=form.elements.addTime,time=form.elements.time,date=form.elements.date;
 if(!dated){toggle.checked=false;time.value='';}
 form.querySelector('[data-task-date]').hidden=!custom;date.disabled=!custom;date.required=custom;
 form.querySelector('[data-task-general]').hidden=dated;
 form.querySelector('[data-task-clock]').hidden=!dated;toggle.disabled=!dated;
 const timed=dated&&toggle.checked;form.querySelector('[data-task-time]').hidden=!timed;time.disabled=!timed;time.required=timed;
 if(!timed)time.value='';
 return true;
}
