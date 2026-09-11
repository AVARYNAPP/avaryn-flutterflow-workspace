import { esc, icon } from './components.js';
import { getPersona, getVisibleState, visibleHorseIds, canManageFacilities as canManage, canBookFacilities as canPlan } from './horse-access.js';
import { FACILITY_DAY, initFacilities, createEmptyFacilities, createFacilityFixtures, validDay, validTime, overlaps, maximumArenaOccupancy } from './facility-data.js';

const labels = { requested: 'Aangevraagd', approved: 'Goedgekeurd', rejected: 'Afgewezen', cancelled: 'Geannuleerd' };
const placeLabels = { available: 'Beschikbaar', occupied: 'Bezet', maintenance: 'Onderhoud', reserved: 'Gereserveerd' };
const terminal = new Set(['rejected', 'cancelled']);
const facilities = state => state.facilities?.schema === 1 ? state.facilities : state.backend?.connected === true ? createEmptyFacilities() : createFacilityFixtures();
const todayOf = state => state.backend?.connected === true && validDay(state.today) ? state.today : FACILITY_DAY;
const dayOf = state => validDay(state.facilityDate) ? state.facilityDate : todayOf(state);
const dateLabel = day => new Date(`${day}T12:00:00Z`).toLocaleDateString('nl-NL', { timeZone: 'UTC', weekday: 'long', day: 'numeric', month: 'long' });
const byTime = (a, b) => `${a.date} ${a.start}`.localeCompare(`${b.date} ${b.start}`);
const own = (state, row) => Boolean(getPersona(state).id) && row.requesterId === getPersona(state).id;
const canCancel = (state, row) => state.backend?.p2?.connected ? row.canCancel===true : !terminal.has(row.status) && (canManage(state) || own(state, row));
const resource = (state, id) => facilities(state).resources.find(row => row.id === id && row.kind === 'arena');

// Pending requests do not consume capacity. Every approval checks the current
// approved reservations again; no client form can choose its own final status.
export function arenaReservationError(state, draft) {
  const place = resource(state, draft.resourceId);
  if (!place) return 'Kies een bestaande rijbak.';
  if (place.status !== 'available') return `${place.name} is niet beschikbaar voor nieuwe reserveringen.`;
  if (!validDay(draft.date) || !validTime(draft.start) || !validTime(draft.end)) return 'Vul een geldige datum en begin- en eindtijd in.';
  if (draft.end <= draft.start) return 'Kies een eindtijd na de begintijd.';
  if (!Number.isInteger(draft.participants) || draft.participants < 1 || draft.participants > place.capacity) return `Kies 1 tot en met ${place.capacity} deelnemers voor ${place.name}.`;
  if (draft.horseId && !visibleHorseIds(state).includes(draft.horseId)) return 'Dit paard staat niet in jouw toegankelijke overzicht. Kies een ander paard of reserveer zonder paard.';
  if (draft.exclusive && !String(draft.note || '').trim()) return 'Leg uit waarom je de hele rijbak voor jezelf wilt gebruiken.';
  const approved = (facilities(state).arenaBookings || []).filter(row => row.id !== draft.id && row.status === 'approved');
  const samePlace = approved.filter(row => row.resourceId === place.id && overlaps(row, draft));
  if (samePlace.some(row => row.exclusive) || (draft.exclusive && samePlace.length)) return 'Deze periode overlapt met een bestaande reservering. Kies een ander tijdvak; een hele rijbak kan alleen worden goedgekeurd als die vrij is.';
  if (maximumArenaOccupancy([...samePlace, { ...draft, status: 'approved' }], place.capacity) > place.capacity) return 'Er zijn in dit tijdvak niet genoeg plaatsen vrij. Kies minder deelnemers of een andere tijd.';
  if (draft.horseId && approved.some(row => row.horseId === draft.horseId && overlaps(row, draft))) return 'Dit paard staat op dat moment al in een rijbak ingepland. Kies een ander tijdstip.';
  return '';
}

function visibleRows(state) {
  const view = getVisibleState(state), ids = new Set(view.horses.map(horse => horse.id));
  return (facilities(state).arenaBookings || []).filter(row => {
    if (canManage(state) || own(state, row)) return true;
    return row.status === 'approved';
  }).map(row => {
    const privateAccess = canManage(state) || own(state, row);
    const horse = row.horseId && view.horses.find(item => item.id === row.horseId);
    const identityVisible = privateAccess || (row.horseId && ids.has(row.horseId));
    return { ...row, horse, identityVisible, privateAccess,
      requesterName: identityVisible ? row.requesterName : '',
      horseId: horse?.id || null,
      activity: identityVisible ? row.activity : '',
      note: privateAccess ? row.note : '', decisionNote: privateAccess ? row.decisionNote : '',
    };
  });
}
function occupancy(state, row) {
  const place = resource(state, row.resourceId);
  if (!place || row.status !== 'approved') return 0;
  const simultaneous = (facilities(state).arenaBookings || []).filter(item => item.resourceId === row.resourceId && item.status === 'approved' && overlaps(item, row)).map(item => ({ ...item, start: item.start > row.start ? item.start : row.start, end: item.end < row.end ? item.end : row.end }));
  return maximumArenaOccupancy(simultaneous, place.capacity);
}
function status(row) { return `<span class="arena-status arena-status--${esc(row.status)}">${esc(labels[row.status] || '')}</span>`; }
function horseStamp(row) {
  return row.horse ? `<button class="arena-horse" data-action="navigate" data-route="horse-overview" data-horse="${esc(row.horse.id)}"><img src="${esc(row.horse.image)}" alt=""><span>${esc(row.horse.name)}</span>${icon('chevron-right', 14)}</button>` : '';
}
function actionButtons(state, row) {
  return `<div class="arena-row-actions">${(state.backend?.p2?.connected?row.canDecide===true:canManage(state)) && row.status === 'requested' ? `<button class="arena-approve" data-action="arena-review" data-id="${esc(row.id)}" data-decision="approved">${icon('check', 16)} Goedkeuren</button><button class="arena-text-button" data-action="arena-review" data-id="${esc(row.id)}" data-decision="rejected">Afwijzen</button>` : ''}${canCancel(state, row) ? `<button class="arena-text-button" data-action="arena-cancel" data-id="${esc(row.id)}">Annuleren</button>` : ''}</div>`;
}
function bookingCard(state, row, showArena = false) {
  const place = resource(state, row.resourceId);
  if (!place) return '';
  const label = row.identityVisible ? row.activity || 'Training' : row.exclusive ? 'Hele rijbak gereserveerd' : 'Gedeelde reservering';
  const load = occupancy(state, row);
  return `<article class="arena-booking${row.exclusive ? ' arena-booking--exclusive' : ''}"><header><div><span class="arena-time">${esc(row.start)} <span>–</span> ${esc(row.end)}</span>${showArena ? `<p>${esc(place.name)} · ${esc(dateLabel(row.date))}</p>` : ''}</div>${status(row)}</header><div class="arena-booking-main"><div><h3>${esc(label)}</h3>${row.requesterName ? `<p>${esc(row.requesterName)}${row.exclusive ? ' · hele rijbak' : ''}</p>` : ''}</div>${horseStamp(row)}</div>${row.status === 'approved' ? `<div class="arena-occupancy"><span class="arena-capacity-bar" aria-hidden="true"><i style="width:${Math.min(100, load / place.capacity * 100)}%"></i></span><span>${row.exclusive ? 'Hele rijbak gereserveerd' : `${load} van ${place.capacity} plekken bezet`}</span></div>` : row.status === 'requested' ? '<p class="arena-waiting">De plek is pas gereserveerd na goedkeuring.</p>' : ''}${row.note ? `<p class="arena-note">${icon('info', 15)}<span>${esc(row.note)}</span></p>` : ''}${row.decisionNote ? `<p class="arena-decision"><strong>Reactie stalmanager</strong><span>${esc(row.decisionNote)}</span></p>` : ''}${actionButtons(state, row)}</article>`;
}
function datebar(state) {
  const day = dayOf(state);
  return `<div class="fac-datebar arena-datebar"><button data-action="arena-shift-day" data-direction="-1" aria-label="Vorige dag">${icon('chevron-left', 18)}</button><button class="fac-date-label" data-action="arena-date" aria-label="Datum kiezen: ${esc(dateLabel(day))}">${icon('calendar', 17)}<span>${day === todayOf(state) ? 'Vandaag' : esc(dateLabel(day))}<small>${day === todayOf(state) ? esc(dateLabel(day)) : 'Datum kiezen'}</small></span></button><button data-action="arena-shift-day" data-direction="1" aria-label="Volgende dag">${icon('chevron-right', 18)}</button></div>`;
}
export function renderArenaPlanning(state, ctx) {
  const places = facilities(state).resources.filter(row => row.kind === 'arena'), day = dayOf(state);
  const rows = visibleRows(state), pending = rows.filter(row => row.status === 'requested').sort(byTime);
  const history = rows.filter(row => terminal.has(row.status)).sort(byTime);
  const reservable = canPlan(state) && places.some(place => place.status === 'available');
  return `<section class="fac-view arena-view"><header class="fac-heading"><div><p class="fac-eyebrow">${ctx.esc(state.stableName || 'Jouw stal')}</p><h1>Rijbakplanning</h1><p>Ruimte voor jouw training, samen of even alleen.</p></div>${reservable ? `<button class="fac-primary" data-action="arena-reserve">${ctx.icon('plus', 18)} Reserveren</button>` : ''}</header>${datebar(state)}${pending.length ? `<section class="arena-requests"><div class="arena-section-heading"><div><p class="fac-eyebrow">Even afstemmen</p><h2>${canManage(state) ? 'Aanvragen rijbak' : 'Jouw aanvragen'}</h2></div><span class="arena-count">${pending.length}</span></div><div class="arena-request-list">${pending.map(row => bookingCard(state, row, true)).join('')}</div></section>` : ''}<div class="arena-grid">${places.map(place => {
    const bookings = rows.filter(row => row.resourceId === place.id && row.date === day && row.status === 'approved').sort(byTime);
    return `<section class="arena-place"><header><span class="arena-place-icon">${ctx.icon('arena', 28)}</span><div><h2>${esc(place.name)}</h2><p>${esc(place.type || 'Rijbak')} · max. ${place.capacity} ruiters</p></div><span class="arena-place-status">${esc(place.status !== 'available' ? placeLabels[place.status] || 'Niet beschikbaar' : bookings.length ? 'Ingepland' : 'Beschikbaar')}</span></header>${place.description ? `<p class="arena-place-note">${esc(place.description)}</p>` : ''}<div class="arena-place-body">${bookings.length ? bookings.map(row => bookingCard(state, row)).join('') : `<div class="arena-free"><span>${icon(place.status === 'available' ? 'sun' : 'settings', 25)}</span><h3>${place.status === 'available' ? 'Ruimte om te rijden' : esc(placeLabels[place.status] || 'Niet beschikbaar')}</h3><p>${place.status === 'available' ? `Nog geen reserveringen voor deze dag. ${place.capacity} plekken beschikbaar.` : 'Nieuwe reserveringen zijn op dit moment niet mogelijk.'}</p></div>`}</div><footer>${canPlan(state) && place.status === 'available' ? `<button class="fac-link" data-action="arena-reserve" data-resource="${esc(place.id)}">${icon('plus', 16)} Tijd inplannen</button>` : ''}${canManage(state) ? `<button class="fac-quiet" data-action="fac-edit-resource" data-resource="${esc(place.id)}">Naam en capaciteit</button>` : ''}</footer></section>`;
  }).join('')}</div>${!places.length ? `<div class="fac-empty"><span>${ctx.icon('arena', 27)}</span><div><h2>Nog geen rijbak ingesteld</h2><p>${canManage(state) ? 'Voeg de rijbakken en hun capaciteit toe bij de faciliteiten.' : 'De stalmanager kan hier de rijbakken van jouw stal beschikbaar maken.'}</p>${canManage(state) ? '<button class="fac-link" data-action="fac-config">Rijbakken instellen</button>' : ''}</div></div>` : ''}${history.length ? `<details class="arena-history"><summary>Eerdere reserveringen <span>${history.length}</span>${icon('chevron-down', 17)}</summary><div>${history.map(row => bookingCard(state, row, true)).join('')}</div></details>` : ''}</section>`;
}
export function renderArenaSummary(state, ctx) {
  const rows = visibleRows(state), today = rows.filter(row => row.status === 'approved' && row.date === todayOf(state)).sort(byTime);
  const pending = rows.filter(row => row.status === 'requested');
  const count = facilities(state).resources.filter(place => place.kind === 'arena').length;
  if (!count && !pending.length) return '';
  return `<section class="arena-summary"><header><span class="arena-place-icon">${ctx.icon('arena', 23)}</span><div><p class="fac-eyebrow">Samen in de rijbak</p><h2>Ruimte voor training ${state.backend?.connected===true&&!state.backend?.p2?.connected?'<span class="mini-status">Prototype</span>':''}</h2></div></header>${pending.length ? `<button class="arena-pending-link" data-action="arena-open"><span>${icon('clock', 16)}</span><span>${pending.length === 1 ? '1 rijbakaanvraag wacht' : `${pending.length} rijbakaanvragen wachten`} op goedkeuring</span>${icon('chevron-right', 14)}</button>` : ''}${today.slice(0, 2).map(row => `<div class="arena-summary-row"><span class="arena-time">${esc(row.start)}</span><div><strong>${esc(resource(state, row.resourceId)?.name || '')}</strong><p>${row.horse ? esc(row.horse.name) : row.identityVisible ? esc(row.requesterName) : 'Gereserveerd'}${row.activity ? ` · ${esc(row.activity)}` : ''}</p></div></div>`).join('')}${!today.length ? '<p class="fac-muted">Nog geen trainingen in de rijbak gepland vandaag.</p>' : ''}<button class="fac-link" data-action="arena-open">Bekijk de rijbakplanning ${icon('chevron-right', 15)}</button></section>`;
}
export function renderHorseArena(state, ctx, horseId) {
  if (!visibleHorseIds(state).includes(horseId)) return '';
  const rows = visibleRows(state).filter(row => row.horseId === horseId && row.date === todayOf(state) && ['approved', 'requested'].includes(row.status));
  if (!rows.length) return '';
  return `<section class="arena-horse-location"><div class="arena-section-heading"><h2>In de rijbak vandaag ${state.backend?.connected===true&&!state.backend?.p2?.connected?'<span class="mini-status">Prototype</span>':''}</h2>${ctx.icon('arena', 22)}</div>${rows.sort(byTime).map(row => `<div class="arena-summary-row"><span class="arena-time">${esc(row.start)}</span><div><strong>${esc(resource(state, row.resourceId)?.name || '')}</strong><p>${esc(row.end)} · ${esc(labels[row.status])}</p></div></div>`).join('')}<button class="fac-link" data-action="arena-open">Naar de rijbakplanning ${icon('chevron-right', 14)}</button></section>`;
}

export function createArenaController({ getState, save, render, navigate, showModal, closeModal, toast }) {
  function current() { const state = getState(); initFacilities(state); return state; }
  function fail(form, message) { const target = form.querySelector('.arena-form-error'); if (target) { target.textContent = message; target.hidden = false; target.focus?.(); } else toast(message); return true; }
  const errors = '<p class="arena-form-error" role="alert" tabindex="-1" hidden></p>';
  const field = (name, label, value = '', extra = '') => `<label class="form-field">${esc(label)}<input name="${name}" value="${esc(value)}" ${extra}></label>`;
  function footer(label = 'Opslaan') { return `<footer class="modal-footer"><button class="button-secondary" type="button" data-action="close-modal">Annuleren</button><button class="button-primary" type="submit">${label}</button></footer>`; }
  function reserveForm(resourceId) {
    const state = current();
    if (!canPlan(state)) { toast('Je kunt de rijbakplanning bekijken. Reserveren is voor deze toegang niet beschikbaar.'); return; }
    const places = facilities(state).resources.filter(place => place.kind === 'arena' && place.status === 'available');
    if (!places.length) { toast('Er is nog geen beschikbare rijbak. De stalmanager kan een rijbak instellen.'); return; }
    const horses = getVisibleState(state).horses.filter(h=>!state.backend?.p2?.connected||state.backend.horseCapabilities?.[h.id]?.planning===true&&state.backend.stableHorseIds.includes(h.id));
    const selectedPlace = places.some(place => place.id === resourceId) ? resourceId : places[0].id;
    showModal('Een plek in de rijbak', `<form id="arena-reserve-form" class="arena-form">${errors}<label class="form-field">Rijbak<select name="resourceId">${places.map(place => `<option value="${esc(place.id)}"${place.id === selectedPlace ? ' selected' : ''}>${esc(place.name)} · max. ${place.capacity} ruiters</option>`).join('')}</select></label>${field('date', 'Datum', dayOf(state), 'type="date" required')}<div class="form-grid">${field('start', 'Van', '10:00', 'type="time" required')}${field('end', 'Tot', '10:45', 'type="time" required')}</div><label class="form-field form-block">Paard · optioneel<select name="horseId"><option value="">Zonder gekoppeld paard</option>${horses.map(horse => `<option value="${esc(horse.id)}"${horse.id === state.horseId ? ' selected' : ''}>${esc(horse.name)}</option>`).join('')}</select></label><div class="form-grid"><label class="form-field">Activiteit · optioneel<select name="activity"><option value="">Vrij rijden</option>${['Dressuurtraining', 'Springles', 'Training', 'Les', 'Verzorging'].map(label => `<option>${label}</option>`).join('')}</select></label>${field('participants', 'Aantal ruiters / paarden', 1, 'type="number" min="1" max="30" required')}</div><label class="arena-exclusive-toggle"><input type="checkbox" name="exclusive"><span><strong>Hele rijbak reserveren</strong><small>De stalmanager moet deze aanvraag goedkeuren.</small></span></label><p class="arena-exclusive-help">Je aanvraag houdt de rijbak nog niet vrij. Na goedkeuring is deze periode helemaal voor jou gereserveerd.</p><label class="form-field"><span class="arena-reason-optional">Reden of notitie · optioneel</span><span class="arena-reason-required">Waarom wil je de rijbak alleen gebruiken?</span><textarea name="note" maxlength="600" placeholder="Wat is handig om vooraf te weten?"></textarea></label>${footer('<span class="arena-reason-optional">Reserveren</span><span class="arena-reason-required">Aanvraag versturen</span>')}</form>`, '', 'Jouw moment op stal');
  }
  function reviewForm(id, decision) {
    const state = current(), row = facilities(state).arenaBookings.find(item => item.id === id);
    if (!canManage(state)) { toast('Alleen de stalmanager kan rijbakaanvragen beoordelen.'); return; }
    if (!row || row.status !== 'requested' || !['approved', 'rejected'].includes(decision)) return;
    const place = resource(state, row.resourceId);
    showModal(decision === 'approved' ? 'Hele rijbak goedkeuren?' : 'Aanvraag afwijzen?', `<form id="arena-review-form" class="arena-form">${errors}<input name="bookingId" value="${esc(id)}" type="hidden"><input name="decision" value="${esc(decision)}" type="hidden"><div class="arena-review-summary"><strong>${esc(row.requesterName)} · ${esc(place?.name || '')}</strong><p>${esc(dateLabel(row.date))} · ${esc(row.start)} – ${esc(row.end)}</p><p>${esc(row.note)}</p></div>${decision === 'approved' ? '<p class="arena-review-copy">We controleren opnieuw of de hele rijbak vrij is. Andere reserveringen kunnen daarna niet over dit tijdvak heen.</p>' : ''}<label class="form-field">Reactie · optioneel<textarea name="decisionNote" maxlength="400"></textarea></label>${footer(decision === 'approved' ? 'Goedkeuren' : 'Afwijzen')}</form>`, '', 'Aanvraag rijbak');
  }
  function cancelForm(id) {
    const state = current(), row = facilities(state).arenaBookings.find(item => item.id === id);
    if (!row || !canCancel(state, row)) { toast('Deze reservering kun je niet annuleren.'); return; }
    const place = resource(state, row.resourceId);
    showModal('Reservering annuleren?', `<form id="arena-cancel-form" class="arena-form">${errors}<input name="bookingId" value="${esc(id)}" type="hidden"><p class="arena-review-copy">${esc(place?.name || 'Deze rijbak')} · ${esc(dateLabel(row.date))}<br>${esc(row.start)} – ${esc(row.end)}</p><p class="arena-review-copy">De reservering vervalt. Je kunt daarna een nieuw moment kiezen.</p>${footer('Reservering annuleren')}</form>`, '', 'Je planning');
  }
  function handleAction(action, button) {
    if (!action.startsWith('arena-')) return false;
    const state = current();
    switch (action) {
      case 'arena-open': navigate('arena-planning'); return true;
      case 'arena-reserve': reserveForm(button.dataset.resource); return true;
      case 'arena-review': reviewForm(button.dataset.id, button.dataset.decision); return true;
      case 'arena-cancel': cancelForm(button.dataset.id); return true;
      case 'arena-shift-day': { const direction = Number(button.dataset.direction); if (![1, -1].includes(direction)) return true; const date = new Date(`${dayOf(state)}T12:00:00Z`); date.setUTCDate(date.getUTCDate() + direction); state.facilityDate = date.toISOString().slice(0, 10); save(); render(); return true; }
      case 'arena-date': showModal('Welke dag wil je bekijken?', `<form id="arena-date-form" class="arena-form">${errors}${field('date', 'Datum', dayOf(state), 'type="date" required')}${footer('Dag bekijken')}</form>`, '', 'Rijbakplanning'); return true;
      default: return false;
    }
  }
  function handleSubmit(form, event) {
    const formId = form.getAttribute?.('id') || form.id;
    if (!['arena-reserve-form', 'arena-review-form', 'arena-cancel-form', 'arena-date-form'].includes(formId)) return false;
    event.preventDefault();
    const state = current(), data = new FormData(form), get = name => String(data.get(name) || '').trim();
    const actor = getPersona(state), bookings = facilities(state).arenaBookings;
    let message = '';
    if (formId === 'arena-date-form') {
      if (!validDay(get('date'))) return fail(form, 'Kies een geldige datum.');
      state.facilityDate = get('date'); save(); closeModal(); render(); return true;
    }
    if (formId === 'arena-reserve-form') {
      if (!canPlan(state) || !actor.id) return fail(form, 'Je kunt met deze toegang geen rijbak reserveren.');
      const exclusive = data.has('exclusive');
      const draft = { id: `arena-${crypto.randomUUID()}`, resourceId: get('resourceId'), date: get('date'), start: get('start'), end: get('end'), horseId: get('horseId') || null, participants: Number(get('participants')), activity: get('activity').slice(0, 80), note: get('note').slice(0, 600), exclusive, status: exclusive ? 'requested' : 'approved', requesterId: actor.id, requesterName: actor.name, decisionNote: '' };
      const problem = arenaReservationError(state, draft); if (problem) return fail(form, problem);
      bookings.push(draft); state.facilityDate = draft.date;
      message = exclusive ? 'Je aanvraag wacht op goedkeuring van de stalmanager.' : 'Je plek staat in de rijbakplanning.';
    } else if (formId === 'arena-review-form') {
      if (!canManage(state)) return fail(form, 'Alleen de stalmanager kan deze aanvraag beoordelen.');
      const row = bookings.find(item => item.id === get('bookingId')), decision = get('decision');
      if (!row || row.status !== 'requested') return fail(form, 'Deze aanvraag is al beoordeeld of geannuleerd.');
      if (!['approved', 'rejected'].includes(decision)) return fail(form, 'Kies goedkeuren of afwijzen.');
      if (decision === 'approved') { const problem = arenaReservationError(state, row); if (problem) return fail(form, problem); }
      row.status = decision; row.decisionNote = get('decisionNote').slice(0, 400); row.reviewedBy = actor.id;
      message = decision === 'approved' ? 'Goedgekeurd. De hele rijbak is in dit tijdvak gereserveerd.' : 'De aanvraag is afgewezen.';
    } else {
      const row = bookings.find(item => item.id === get('bookingId'));
      if (!row || !canCancel(state, row)) return fail(form, 'Deze reservering kun je niet annuleren of is al gesloten.');
      row.status = 'cancelled'; message = 'De reservering is geannuleerd.';
    }
    save(); closeModal(); render(); toast(message); return true;
  }
  return { handleAction, handleSubmit };
}
