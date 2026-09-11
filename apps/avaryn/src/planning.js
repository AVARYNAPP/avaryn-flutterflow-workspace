import {browserDay} from './browser-clock.js';
import {taskDayLabel,taskToday,taskOrder} from './task-timing.js';
import {canPlan} from './horse-access.js';
const TODAY = browserDay();
const WEEKDAYS = ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'];
const closed = new Set(['completed', 'done', 'cancelled']);

function date(value) {
  const source = typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : TODAY;
  const parsed = new Date(`${source}T12:00:00Z`);
  return Number.isNaN(parsed.valueOf()) ? new Date(`${TODAY}T12:00:00Z`) : parsed;
}
function key(value) { return value.toISOString().slice(0, 10); }
function shift(value, days) { const result = new Date(value); result.setUTCDate(result.getUTCDate() + days); return result; }
function format(value, options) { return value.toLocaleDateString('nl-NL', { timeZone: 'UTC', ...options }); }
function monday(value) { return shift(value, -((value.getUTCDay() + 6) % 7)); }
function itemsFor(items, day) { return items.filter(item => item.date === key(day)); }
function dateTitle(day, period) {
  if (period === 'month') return format(day, { month: 'long', year: 'numeric' });
  if (period === 'week') {
    const first = monday(day), last = shift(first, 6);
    if (first.getUTCMonth() === last.getUTCMonth()) return `${first.getUTCDate()} – ${format(last, { day: 'numeric', month: 'long' })}`;
    return `${format(first, { day: 'numeric', month: 'short' })} – ${format(last, { day: 'numeric', month: 'short' })}`;
  }
  return format(day, { weekday: 'long', day: 'numeric', month: 'long' });
}
function eventList(items, ctx, compact = false) {
  return items.map(activity => ctx.activityCard(activity, { showHorse: true, compact, showNote: true })).join('');
}
function emptyDay(ctx, allowCreate) {
  return `<div class="planning-empty"><span class="planning-empty-icon">${ctx.icon('calendar', 26)}</span><h3>Ruimte in de agenda</h3><p>Plan een training, afspraak of verzorgingsmoment.</p>${allowCreate?`<button class="planning-text-action" data-action="new-activity">${ctx.icon('plus', 18)} Activiteit plannen</button>`:''}</div>`;
}
function weekAgenda(day, items, ctx, today=TODAY) {
  const first = monday(day);
  return `<div class="planning-week">${Array.from({ length: 7 }, (_, index) => {
    const current = shift(first, index), dayItems = itemsFor(items, current);
    return `<section class="planning-week-day${key(current) === today ? ' is-today' : ''}" aria-label="${ctx.esc(format(current, { weekday: 'long', day: 'numeric', month: 'long' }))}"><div class="planning-week-date"><span>${format(current, { weekday: 'short' }).replace('.', '')}</span><strong>${current.getUTCDate()}</strong>${key(current) === today ? '<small>Vandaag</small>' : ''}</div><div class="planning-week-events">${dayItems.length ? eventList(dayItems, ctx, true) : '<p class="planning-free-day">Geen afspraken</p>'}</div></section>`;
  }).join('')}</div>`;
}
function monthAgenda(day, items, ctx, allowCreate, today=TODAY) {
  const firstOfMonth = new Date(Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), 1, 12));
  const first = monday(firstOfMonth);
  const lastOfMonth = new Date(Date.UTC(day.getUTCFullYear(), day.getUTCMonth() + 1, 0, 12));
  const count = Math.ceil((((firstOfMonth.getUTCDay() + 6) % 7) + lastOfMonth.getUTCDate()) / 7) * 7;
  const selected = itemsFor(items, day);
  return `<div class="planning-month"><div class="planning-month-weekdays" aria-hidden="true">${WEEKDAYS.map(name => `<span>${name}</span>`).join('')}</div><div class="planning-month-grid">${Array.from({ length: count }, (_, index) => {
    const current = shift(first, index), dayKey = key(current), dayItems = itemsFor(items, current);
    const outside = current.getUTCMonth() !== day.getUTCMonth();
    const summary = dayItems.map(activity => `${activity.time || ''} ${activity.title || activity.type} · ${ctx.horse(activity.horseId)?.name || ''}`.trim()).join(', ');
    return `<button class="planning-month-day${outside ? ' is-outside' : ''}${dayKey === key(day) ? ' is-selected' : ''}${dayKey === today ? ' is-today' : ''}" data-action="select-day" data-day="${dayKey}" aria-pressed="${dayKey === key(day)}" aria-label="${ctx.esc(`${format(current, { weekday: 'long', day: 'numeric', month: 'long' })}. ${dayItems.length} ${dayItems.length === 1 ? 'activiteit' : 'activiteiten'}${summary ? `: ${summary}` : ''}`)}"><span class="planning-month-number">${current.getUTCDate()}</span><span class="planning-month-events">${dayItems.slice(0, 2).map(activity => `<span>${ctx.esc(activity.time || '')} ${ctx.esc(ctx.horse(activity.horseId)?.name || activity.title || activity.type)}</span>`).join('')}${dayItems.length > 2 ? `<span>+ ${dayItems.length - 2} meer</span>` : ''}</span><span class="planning-month-dots" aria-hidden="true">${dayItems.slice(0, 3).map(activity => `<i${closed.has(activity.status) ? ' class="is-closed"' : ''}></i>`).join('')}</span></button>`;
  }).join('')}</div></div><section class="planning-selected-day"><div class="planning-list-heading"><h2>${ctx.esc(format(day, { weekday: 'long', day: 'numeric', month: 'long' }))}</h2><span>${selected.length} ${selected.length === 1 ? 'activiteit' : 'activiteiten'}</span></div><div class="planning-day-events">${selected.length ? eventList(selected, ctx) : emptyDay(ctx, allowCreate)}</div></section>`;
}

export function renderPlanning(state, ctx) {
  const day = date(state.selectedDay);
  const allowCreate=canPlan(state);
  const period = ['today', 'week', 'month'].includes(state.period) ? state.period : 'today';
  const inHorse = state.route === 'horse-planning';
  const items = (state.activities || []).filter(activity => !inHorse || activity.horseId === state.horseId)
    .slice().sort((a, b) => `${a.date} ${a.time || '99:99'}`.localeCompare(`${b.date} ${b.time || '99:99'}`));
  const tasks=(state.tasks||[]).filter(t=>t.date===key(day)&&(!inHorse||t.horseId===state.horseId)&&!closed.has(t.status)).sort(taskOrder);
  const visible = period === 'today' ? itemsFor(items, day) : items.filter(activity => {
    const value = date(activity.date);
    return period === 'week' ? value >= monday(day) && value < shift(monday(day), 7) : value.getUTCMonth() === day.getUTCMonth() && value.getUTCFullYear() === day.getUTCFullYear();
  });
  return `<section class="planning-view${inHorse ? ' planning-view--horse' : ''}"><header class="planning-heading"><div><h1>${inHorse ? 'Planning' : 'Jouw planning'}</h1><p>${inHorse ? 'Training, verzorging en afspraken.' : 'Alle paarden. Eén helder overzicht.'}</p></div>${allowCreate?`<button class="planning-primary" data-action="new-activity" aria-label="Activiteit plannen">${ctx.icon('plus', 20)}<span>Plannen</span></button>`:''}</header><div class="planning-period" role="group" aria-label="Agendaweergave">${[['today', 'Vandaag'], ['week', 'Week'], ['month', 'Maand']].map(([value, label]) => `<button data-action="period" data-period="${value}" aria-pressed="${period === value}"${period === value ? ' class="is-active"' : ''}>${label}</button>`).join('')}</div><div class="planning-datebar${period === 'today' ? ' is-today-view' : ''}"><button${period === 'today' ? ' hidden' : ''} class="planning-date-step" data-action="shift-date" data-direction="-1" aria-label="${period === 'week' ? 'Vorige week' : period === 'month' ? 'Vorige maand' : 'Vorige dag'}">${ctx.icon('chevron-left', 20)}</button><div><h2>${ctx.esc(dateTitle(day, period))}</h2><span>${visible.length} ${visible.length === 1 ? 'activiteit' : 'activiteiten'}</span></div><button${period === 'today' ? ' hidden' : ''} class="planning-date-step" data-action="shift-date" data-direction="1" aria-label="${period === 'week' ? 'Volgende week' : period === 'month' ? 'Volgende maand' : 'Volgende dag'}">${ctx.icon('chevron-right', 20)}</button></div>${period === 'month' ? monthAgenda(day, items, ctx, allowCreate, state.today||TODAY) : period === 'week' ? weekAgenda(day, items, ctx, state.today||TODAY) : `<div class="planning-day-events">${visible.length ? eventList(visible, ctx) : emptyDay(ctx, allowCreate)}</div>`}${tasks.length?`<section class="section"><div class="section-heading"><h2>Taken · ${ctx.esc(taskDayLabel(key(day),taskToday(state)))}</h2><button class="text-link" data-action="navigate" data-route="tasks">Alle taken</button></div><div class="tasks-list">${tasks.map(t=>ctx.taskCard(t)).join('')}</div></section>`:''}</section>`;
}
