import { createContext, esc, icon } from './components.js';
import { canManageFacilities as canManage, getVisibleState, visibleHorseIds } from './horse-access.js';
import { FACILITY_DAY, FACILITY_KINDS, createFacilityFixtures, createEmptyFacilities, initFacilities, newResource, validDay, bookingError, configurationError, maximumOccupancy, arenaCapacityError } from './facility-data.js';
export { initFacilities } from './facility-data.js';

const ROUTES = new Set(['facilities', 'pastures', 'stalls', 'facility-planning', 'arena-planning']);
const STATUSES = { available: 'Beschikbaar', occupied: 'Bezet', rest: 'Rust', maintenance: 'Onderhoud', reserved: 'Gereserveerd' };
const kindsForPlanning = new Set(['walker', 'wash', 'paddock']);
const todayOf = state => state.backend?.connected === true && validDay(state.today) ? state.today : FACILITY_DAY;
const dateOf = state => validDay(state.facilityDate) ? state.facilityDate : todayOf(state);
const dayLabel = (day, short = false) => new Date(`${day}T12:00:00Z`).toLocaleDateString('nl-NL', { timeZone: 'UTC', weekday: short ? undefined : 'long', day: 'numeric', month: 'long' });
const raw = state => state.facilities?.schema === 1 ? state.facilities : state.backend?.connected === true ? createEmptyFacilities() : createFacilityFixtures();
const byTime = (a, b) => a.start.localeCompare(b.start);
const resource = (facilities, id) => facilities.resources.find(row => row.id === id);

function scoped(state) {
  const view = getVisibleState(state), facilities = raw(state);
  if(state.backend?.p2?.connected)return {...view,facilityDate:dateOf(state),facilities:{...facilities,bookings:facilities.bookings.filter(b=>b.status==='approved')}};
  const allowed = new Set(visibleHorseIds(state));
  const manager = canManage(state);
  const placements = facilities.placements.filter(row => allowed.has(row.horseId));
  const bookings = facilities.bookings.map(row => {
    const horseIds = row.horseIds.filter(id => allowed.has(id));
    if (!horseIds.length) return null;
    return { ...row, horseIds, note: manager || horseIds.length === row.horseIds.length ? row.note : '' };
  }).filter(Boolean);
  const used = new Set([...placements.map(row => row.resourceId), ...bookings.map(row => row.resourceId)]);
  return { ...view, facilityDate: dateOf(state), facilities: { ...facilities, placements, bookings,
    resources: facilities.resources.filter(row => manager || row.kind === 'arena' || used.has(row.id)).map(row => manager ? row : { ...row, description: '' }),
  } };
}
function badge(place, bookings = [], placement) {
  const text = place.status !== 'available' ? STATUSES[place.status] : placement ? 'Bezet' : bookings.length ? 'Ingepland' : 'Beschikbaar';
  return `<span class="fac-status fac-status--${place.status !== 'available' ? place.status : placement || bookings.length ? 'planned' : 'available'}">${esc(text)}</span>`;
}
function routeLink(route, label, className = 'fac-link') { return `<button class="${className}" data-action="fac-open" data-route="${route}">${esc(label)} ${icon('chevron-right', 16)}</button>`; }
function header(state, title, subtitle, action = '') {
  return `<header class="fac-heading"><div><p class="fac-eyebrow">${esc(state.stableName || 'Jouw stal')}</p><h1>${esc(title)}</h1><p>${esc(subtitle)}</p></div>${action}</header>`;
}
function primary(action, label, attributes = '') { return `<button class="fac-primary" data-action="${action}" ${attributes}>${icon('plus', 18)}<span>${esc(label)}</span></button>`; }
function dates(state) {
  const date = dateOf(state);
  return `<div class="fac-datebar"><button data-action="fac-shift-day" data-direction="-1" aria-label="Vorige dag">${icon('chevron-left', 18)}</button><button class="fac-date-label" data-action="fac-select-date" aria-label="Datum kiezen: ${esc(dayLabel(date))}">${icon('calendar', 17)}<span>${date === todayOf(state) ? 'Vandaag' : esc(dayLabel(date))}<small>${date === todayOf(state) ? esc(dayLabel(date)) : 'Datum kiezen'}</small></span></button><button data-action="fac-shift-day" data-direction="1" aria-label="Volgende dag">${icon('chevron-right', 18)}</button></div>`;
}
function horsePeople(ids, state, compact = false) {
  return `<div class="fac-horses${compact ? ' fac-horses--compact' : ''}">${ids.map(id => {
    const horse = state.horses.find(row => row.id === id);
    return horse ? `<button data-action="navigate" data-route="horse-overview" data-horse="${esc(horse.id)}"><img src="${esc(horse.image)}" alt=""><span>${esc(horse.name)}</span>${compact ? '' : icon('chevron-right', 14)}</button>` : '';
  }).join('')}</div>`;
}
function bookingCard(booking, state, includePlace = false) {
  const place = resource(state.facilities, booking.resourceId);
  if (!place) return '';
  const edit=state.backend?.p2?.connected?booking.canEdit===true:canManage(state);
  const cancel=state.backend?.p2?.connected?booking.canCancel===true:canManage(state);
  const people=booking.horseIds.some(id=>state.horses.some(h=>h.id===id))?horsePeople(booking.horseIds,state):'<p class="fac-muted">Gereserveerd · '+esc(booking.participants||1)+' plaats(en)</p>';
  return `<article class="fac-booking"><header><div><span class="fac-time">${esc(booking.start)}<span>—</span>${esc(booking.end)}</span>${includePlace ? `<h3>${esc(place.name)}</h3>` : ''}</div>${edit ? `<button class="fac-icon-button" data-action="fac-edit-booking" data-id="${esc(booking.id)}" aria-label="Planning ${esc(place.name)} ${esc(booking.start)} wijzigen">${icon('edit', 16)}</button>` : ''}</header>${people}${booking.note ? `<p class="fac-note">${icon('info', 15)}<span>${esc(booking.note)}</span></p>` : ''}${edit||cancel ? `<div class="fac-booking-footer">${edit?`<button class="fac-link" data-action="fac-edit-booking" data-id="${esc(booking.id)}">Planning wijzigen ${icon('chevron-right', 14)}</button>`:''}${cancel?`<button class="fac-quiet" data-action="fac-release-booking" data-id="${esc(booking.id)}">Vrijmaken</button>`:''}</div>` : ''}</article>`;
}
function blank(message) { return `<div class="fac-empty"><span>${icon('leaf', 27)}</span><p>${esc(message)}</p></div>`; }

export function renderFacilities(input, ctx) {
  const state = scoped(input), fac = state.facilities, manager = canManage(input);
  const filter=Object.hasOwn(FACILITY_KINDS,state.facilityFilter||'')?state.facilityFilter:null;
  return `<section class="fac-view">${filter?'<button class="fac-link" data-action="fac-show-all">'+icon('arrow-left',16)+' Alle faciliteiten</button>':''}${header(state, filter?(filter==='locker'?'Zadelkamer':FACILITY_KINDS[filter].label):'Faciliteiten', manager ? 'Een fijne plek voor alles rond je paard.' : 'De plekken die horen bij jouw paarden.', manager ? `<button class="fac-secondary" data-action="fac-config">${icon('settings', 18)}<span>Beheren</span></button>` : '')}<div class="fac-shortcuts">${routeLink('pastures', 'Weideplanning')}${routeLink('stalls', 'Stalplaatsen')}${routeLink('facility-planning', 'Faciliteitenplanning')}</div><div class="fac-kind-grid">${Object.entries(FACILITY_KINDS).filter(([kind])=>!filter||filter===kind).map(([kind, meta]) => {
    const places = fac.resources.filter(row => row.kind === kind);
    if (!manager && !places.length) return '';
    return `<article class="fac-kind-card"><header><span class="fac-kind-icon">${ctx.icon(meta.icon, 27)}</span><span class="fac-kind-count">${places.length}</span></header><h2>${esc(meta.label)}</h2><p>${['walker', 'arena'].includes(kind) ? `${places.reduce((sum, row) => sum + row.capacity, 0)} plaatsen in totaal` : kind === 'locker' ? fac.tackRoom ? 'In de zadelkamer' : 'Geen zadelkamer ingesteld' : manager ? ({stall:'Rust en een eigen plek',pasture:'Buiten bewegen',paddock:'Frisse lucht en beweging',wash:'Dagelijkse verzorging'}[kind] || 'Een plek op stal') : 'Voor jouw paarden'}</p><details class="fac-resource-list"><summary>Namen en status ${icon('chevron-down', 15)}</summary>${places.length ? places.map(place => `<div class="fac-resource-row"><div><strong>${esc(place.name)}</strong><small>${esc(place.status !== 'available' ? STATUSES[place.status] : fac.placements.some(row => row.resourceId === place.id) ? 'Bezet' : fac.bookings.some(row => row.resourceId === place.id && row.date === state.facilityDate) ? 'Ingepland' : 'Beschikbaar')}${['walker', 'arena'].includes(place.kind) ? ` · ${place.capacity} plaatsen` : ''}</small></div>${manager ? `<button class="fac-icon-button" data-action="fac-edit-resource" data-resource="${esc(place.id)}" aria-label="${esc(place.name)} bewerken">${icon('edit', 15)}</button>` : ''}</div>`).join('') : '<p class="fac-muted">Nog niet toegevoegd.</p>'}</details>${kind !== 'locker' ? routeLink(meta.route, kind === 'stall' ? 'Bekijk de stalplaatsen' : kind === 'pasture' ? 'Naar de weideplanning' : 'Bekijk de planning') : ''}</article>`;
  }).join('')}</div>${manager ? '<p class="fac-footnote">Namen kun je zelf aanpassen. QR-bordjes zijn later beschikbaar.</p>' : ''}</section>`;
}

export function renderPastures(input, ctx) {
  const state = scoped(input), fac = state.facilities, manager = canManage(input);
  const places = fac.resources.filter(row => row.kind === 'pasture');
  return `<section class="fac-view">${header(state, 'Weideplanning', 'Buitenlucht, beweging en een rustig dagritme.', manager ? primary('fac-book', 'Paard toewijzen', 'data-kind="pasture"') : '')}${dates(state)}<div class="fac-pasture-grid">${places.map(place => {
    const bookings = fac.bookings.filter(row => row.resourceId === place.id && row.date === state.facilityDate).sort(byTime);
    return `<section class="fac-pasture-card"><header class="fac-place-heading"><span class="fac-landscape-icon">${ctx.icon('pasture', 29)}</span><div><h2>${esc(place.name)}</h2>${place.description ? `<p>${esc(place.description)}</p>` : ''}</div>${badge(place, bookings)}</header><div class="fac-pasture-body">${bookings.length ? bookings.map(row => bookingCard(row, state)).join('') : `<div class="fac-place-rest">${icon(place.status === 'rest' ? 'leaf' : place.status === 'maintenance' ? 'settings' : 'sun', 25)}<h3>${esc(place.status === 'rest' ? 'Even rust voor het gras' : place.status === 'maintenance' ? 'Deze weide krijgt aandacht' : place.status === 'occupied' ? 'Deze weide is bezet' : 'Alle ruimte om naar buiten te gaan')}</h3><p>${place.status === 'available' ? 'Er staan nog geen paarden ingepland voor deze dag.' : 'Er kunnen nu geen nieuwe paarden worden toegewezen.'}</p></div>`}</div>${manager ? `<footer class="fac-place-footer">${place.status === 'available' ? `<button class="fac-link" data-action="fac-book" data-kind="pasture" data-resource="${esc(place.id)}">${icon('plus', 16)} Paard toewijzen</button>` : '<span></span>'}<button class="fac-quiet" data-action="fac-edit-resource" data-resource="${esc(place.id)}">Naam en status</button>${bookings.length&&!state.backend?.p2?.connected ? `<button class="fac-quiet" data-action="fac-free-pasture" data-resource="${esc(place.id)}">Weide vrijmaken</button>` : ''}</footer>` : ''}</section>`;
  }).join('')}</div>${places.length ? '' : blank('Er staat voor jouw paarden nog geen weide in dit overzicht.')}</section>`;
}

export function renderStalls(input, ctx) {
  const state = scoped(input), fac = state.facilities, manager = canManage(input);
  const stalls = fac.resources.filter(row => row.kind === 'stall');
  const occupied = stalls.filter(row => fac.placements.some(item => item.resourceId === row.id)).length;
  return `<section class="fac-view">${header(state, 'Stalplaatsen', 'Een vertrouwde eigen plek, dichtbij je team.', manager ? `<button class="fac-secondary" data-action="fac-config">${icon('settings', 18)} Beheren</button>` : '')}<div class="fac-stall-overview"><span>${icon('stall', 25)}</span><div><strong>${occupied} ${occupied === 1 ? 'paard heeft' : 'paarden hebben'} een eigen plek</strong><p>${manager ? `${stalls.length - occupied} ${stalls.length - occupied === 1 ? 'stalplaats' : 'stalplaatsen'} zonder paard` : 'Je ziet alleen de stalplaatsen van jouw paarden.'}</p></div></div><div class="fac-stall-grid">${stalls.map(place => {
    const placement = fac.placements.find(row => row.resourceId === place.id);
    return `<article class="fac-stall-card"><header><div><span class="fac-stall-number">${String(place.number).padStart(2, '0')}</span><h2>${esc(place.name)}</h2></div>${badge(place, [], placement)}</header><p class="fac-stall-type">${esc(place.type || 'Standaardbox')}</p>${placement ? `${placement.horseId?horsePeople([placement.horseId], state):'<p class="fac-muted">Deze stalplaats is bezet.</p>'}${placement.note ? `<p class="fac-note"><span>${esc(placement.note)}</span></p>` : ''}` : `<div class="fac-vacant">${place.status === 'available' ? 'Een vrije plek op stal' : 'Geen paard gekoppeld'}</div>`}${manager ? `<footer>${place.status === 'available' && (!placement || placement.horseId) ? `<button class="fac-link" data-action="fac-assign-stall" data-resource="${esc(place.id)}">${icon(placement ? 'edit' : 'plus', 15)} ${placement ? 'Koppeling wijzigen' : 'Paard koppelen'}</button>` : ''}<button class="fac-icon-button" data-action="fac-edit-resource" data-resource="${esc(place.id)}" aria-label="Naam en status van ${esc(place.name)} wijzigen">${icon('settings', 16)}</button>${placement?.horseId ? `<button class="fac-quiet" data-action="fac-release-stall" data-resource="${esc(place.id)}">Vrijmaken</button>` : ''}</footer>` : ''}</article>`;
  }).join('')}</div>${stalls.length ? '' : blank('Er is nog geen stalplaats aan jouw paarden gekoppeld.')}<p class="fac-footnote">QR-bordjes zijn later beschikbaar.</p></section>`;
}

export function renderFacilityPlanning(input, ctx) {
  const state = scoped(input), fac = state.facilities, manager = canManage(input);
  const order=['walker','wash','paddock'];
  const places = fac.resources.filter(row => kindsForPlanning.has(row.kind)).sort((a,b)=>order.indexOf(a.kind)-order.indexOf(b.kind)||a.number-b.number);
  return `<section class="fac-view">${header(state, 'Faciliteitenplanning', 'Van een rondje stappen tot even afspoelen.', manager ? primary('fac-book', 'Reserveren', 'data-kind="facility"') : '')}${dates(state)}<div class="fac-planning-grid">${places.map(place => {
    const bookings = fac.bookings.filter(row => row.resourceId === place.id && row.date === state.facilityDate).sort(byTime);
    return `<section class="fac-schedule-card"><header class="fac-place-heading"><span class="fac-kind-icon">${ctx.icon(FACILITY_KINDS[place.kind].icon, 26)}</span><div><h2>${esc(place.name)}</h2><p>${place.kind === 'walker' ? `${place.capacity} plaatsen` : place.kind === 'paddock' ? 'Vrij bewegen' : 'Verzorging op stal'}</p></div>${badge(place, bookings)}</header><div class="fac-schedule-body">${bookings.length ? bookings.map(row => bookingCard(row, state)).join('') : `<div class="fac-schedule-free">${icon(place.status === 'available' ? 'clock' : 'settings', 23)}<p>${place.status === 'available' ? 'Nog geen reserveringen op deze dag.' : esc(STATUSES[place.status])}</p></div>`}</div>${manager && place.status === 'available' ? `<footer class="fac-place-footer"><button class="fac-link" data-action="fac-book" data-kind="facility" data-resource="${esc(place.id)}">${icon('plus', 16)} Tijd inplannen</button><button class="fac-quiet" data-action="fac-edit-resource" data-resource="${esc(place.id)}">Naam en status</button></footer>` : ''}</section>`;
  }).join('')}</div>${places.length ? '' : blank('Er zijn nog geen faciliteiten ingepland voor jouw paarden.')}</section>`;
}

export function renderFacilitySummary(input, ctx) {
  const state = scoped(input), fac = state.facilities;
  const today = fac.bookings.filter(row => row.date === todayOf(state)).sort(byTime).slice(0, 2);
  const counts = ['stall', 'pasture', 'paddock'].map(kind => `${fac.resources.filter(row => row.kind === kind).length} ${kind === 'stall' ? 'stalplaatsen' : kind === 'pasture' ? 'weides' : 'paddocks'}`);
  return `<section class="fac-summary"><div class="fac-summary-heading"><span class="fac-kind-icon">${ctx.icon('pasture', 23)}</span><div><p class="fac-eyebrow">Een fijne plek</p><h2>Vandaag op stal ${input.backend?.connected&&!input.backend?.p2?.connected?'<span class="mini-status">Prototype</span>':''}</h2></div></div>${today.length ? today.map(row => { const place = resource(fac, row.resourceId); return `<div class="fac-summary-row"><div>${horsePeople(row.horseIds, state, true)}</div><p><strong>${esc(place?.name || '')}</strong><span>${esc(row.start)} – ${esc(row.end)}</span></p></div>`; }).join('') : '<p class="fac-muted">Geen weide- of faciliteitenmomenten ingepland voor vandaag.</p>'}${canManage(input) ? `<p class="fac-summary-counts">${counts.map(esc).join(' · ')}</p>` : ''}${routeLink('pastures', 'Open de weideplanning')}</section>`;
}

export function renderHorseLocation(input, ctx, horseId) {
  const state = scoped(input), fac = state.facilities;
  const horse = state.horses.find(horse => horse.id === horseId);
  if (!horse) return '';
  const stableLabel = input.backend?.connected ? horse.stable || 'Nog geen verblijfplaats gekoppeld' : state.stableName || '';
  const canPlace = input.backend?.connected ? !!horse.organizationId && horse.organizationId === input.backend.organizationId && input.backend.permissionCodes?.['organization.residencies.manage'] === true : canManage(input);
  const placement = fac.placements.find(row => row.horseId === horseId);
  const box = placement && resource(fac, placement.resourceId);
  const outdoors = fac.bookings.filter(row => row.date === todayOf(state) && row.horseIds.includes(horseId) && ['pasture', 'paddock'].includes(resource(fac, row.resourceId)?.kind)).sort(byTime);
  return `<section class="fac-location"><header><span class="fac-kind-icon">${ctx.icon('location', 23)}</span><div><p class="fac-eyebrow">Dichtbij</p><h2>Locatie vandaag ${input.backend?.connected&&!input.backend?.p2?.connected?'<span class="mini-status">Prototype</span>':''}</h2></div></header><div class="fac-location-row"><span>${icon('stall', 18)}</span><div><strong>${box ? esc(box.name) : 'Nog geen vaste stalplaats'}</strong><p>${esc(stableLabel)}</p></div></div>${outdoors.map(row => `<div class="fac-location-row"><span>${ctx.icon(FACILITY_KINDS[resource(fac, row.resourceId).kind].icon, 18)}</span><div><strong>${esc(resource(fac, row.resourceId).name)}</strong><p>${esc(row.start)} – ${esc(row.end)}</p></div></div>`).join('')}<footer>${canPlace ? `<button class="fac-link" data-action="${input.backend?.connected?'horse-placement':'fac-horse-location'}" data-horse="${esc(horseId)}">Locatie wijzigen ${icon('edit', 14)}</button>` : ''}${routeLink('pastures', 'Weideplanning')}</footer></section>`;
}

export function createFacilityController({ getState, save, render, navigate, showModal, closeModal, toast }) {
  function current() { const state = getState(); initFacilities(state); return state; }
  function context() { return createContext(getVisibleState(current())); }
  function requireManager() { if (canManage(current())) return true; toast('Alleen de stalmanager kan plekken en toewijzingen aanpassen.'); return false; }
  function error(form, message) { const node = form.querySelector('.fac-form-error'); if (node) { node.textContent = message; node.hidden = false; node.focus?.(); } else toast(message); return true; }
  const errorBox = '<p class="fac-form-error" role="alert" tabindex="-1" hidden></p>';
  function footer(label = 'Opslaan') { return `<footer class="modal-footer"><button class="button-secondary" type="button" data-action="close-modal">Annuleren</button><button class="button-primary" type="submit">${esc(label)}</button></footer>`; }
  function showForm(title, id, body, label, kicker = 'Op stal') { showModal(title, `<form id="${id}" class="fac-form">${errorBox}${body}${footer(label)}</form>`, '', kicker); }
  function input(name, label, value = '', attributes = '') { return `<label class="form-field">${esc(label)}<input name="${name}" value="${esc(value)}" ${attributes}></label>`; }
  function options(rows, selected, label = row => row.name) { return rows.map(row => `<option value="${esc(row.id)}"${row.id === selected ? ' selected' : ''}>${esc(label(row))}</option>`).join(''); }
  function configForm() {
    const state = current(), fac = state.facilities;
    showForm('De plekken op jouw stal', 'fac-config-form', `<p class="fac-form-intro">Pas het aantal plekken aan. Je eigen namen en bestaande toewijzingen blijven behouden.</p><div class="form-grid">${Object.entries(FACILITY_KINDS).map(([kind, meta]) => input(kind, meta.label, fac.configuration?.counts?.[kind] ?? fac.resources.filter(row => row.kind === kind).length, 'type="number" min="0" max="50" required')).join('')}</div>${input('walkerCapacity', 'Plaatsen per stapmolen', fac.configuration?.walkerCapacity || fac.resources.find(row => row.kind === 'walker')?.capacity || 4, 'type="number" min="1" max="20" required')}<label class="fac-check"><input type="checkbox" name="tackRoom"${fac.tackRoom ? ' checked' : ''}> Er is een zadelkamer</label>`, 'Plekken opslaan');
  }
  function resourceForm(id) {
    const place = resource(current().facilities, id); if (!place) return;
    showForm(`${place.name} aanpassen`, 'fac-resource-form', `<p class="fac-form-intro">Bezetting volgt uit de gekoppelde paarden en planning. Hier kies je of deze plek gebruikt mag worden.</p><input type="hidden" name="resourceId" value="${esc(id)}">${input('name', 'Naam', place.name, 'required maxlength="60"')}<label class="form-field">Gebruik van deze plek<select name="status">${Object.entries(STATUSES).filter(([value]) => place.kind === 'arena' ? value !== 'rest' : value !== 'reserved').map(([value, label]) => `<option value="${value}"${place.status === value ? ' selected' : ''}>${label}</option>`).join('')}</select></label>${place.kind === 'stall' ? `<label class="form-field">Staltype<select name="type">${['Standaardbox', 'Met uitloop', 'Hengstenbox', 'Veulenbox'].map(value => `<option${place.type === value ? ' selected' : ''}>${value}</option>`).join('')}</select></label>` : ''}${place.kind === 'arena' ? `<label class="form-field">Soort rijbak<select name="arenaType">${['Binnenbak', 'Buitenbak', 'Overdekt'].map(value => `<option${place.type === value ? ' selected' : ''}>${value}</option>`).join('')}</select></label>${input('arenaCapacity', 'Maximaal aantal ruiters tegelijk', place.capacity, 'type="number" min="1" max="30" required')}` : ''}<label class="form-field">Korte omschrijving<textarea name="description" maxlength="240">${esc(place.description)}</textarea></label>`, 'Wijzigingen opslaan');
  }
  function placementForm(resourceId, horseId) {
    const state = current(), fac = state.facilities, horses = getVisibleState(state).horses.filter(h=>!state.backend?.p2?.connected||state.backend.stableHorseIds.includes(h.id));
    const existing = fac.placements.find(row => resourceId ? row.resourceId === resourceId : row.horseId === horseId);
    const selectedHorse = horseId || existing?.horseId || horses[0]?.id;
    const selectedPlace = resourceId || fac.placements.find(row => row.horseId === selectedHorse)?.resourceId || fac.resources.find(row => row.kind === 'stall' && row.status === 'available' && !fac.placements.some(item => item.resourceId === row.id))?.id;
    const stalls = fac.resources.filter(row => row.kind === 'stall' && row.status === 'available');
    if (!stalls.length || !horses.length) { toast('Er is nog geen beschikbare stalplaats of paard om te koppelen.'); return; }
    showForm('Een eigen plek op stal', 'fac-placement-form', `<p class="fac-form-intro">Kies het paard en de stalplaats. Had dit paard al een plek? Dan verplaatsen we de koppeling naar de nieuwe stal.</p><label class="form-field">Paard<select name="horseId">${options(horses, selectedHorse)}</select></label><label class="form-field">Stalplaats<select name="resourceId">${options(stalls, selectedPlace, row => `${row.name}${fac.placements.some(item => item.resourceId === row.id) ? ' · bezet' : ''}`)}</select></label><label class="form-field">Handig om te weten<textarea name="note" maxlength="500">${esc(existing?.note || '')}</textarea></label>`, 'Paard koppelen', 'Waar staat dit paard?');
  }
  function bookingForm(id, resourceId, kind = 'facility') {
    const state = current(), fac = state.facilities, horses = getVisibleState(state).horses.filter(h=>!state.backend?.p2?.connected||state.backend.stableHorseIds.includes(h.id));
    const old = id && fac.bookings.find(row => row.id === id);
    if (id && !old) return;
    const oldPlace = old && resource(fac, old.resourceId);
    const pasture = oldPlace ? oldPlace.kind === 'pasture' : kind === 'pasture';
    const places = fac.resources.filter(row => (pasture ? row.kind === 'pasture' : kindsForPlanning.has(row.kind)) && (row.status === 'available' || row.id === old?.resourceId));
    if (!places.length || !horses.length) { toast('Er is nog geen beschikbare plek of paard voor deze planning.'); return; }
    const selected = old?.resourceId || (places.some(row => row.id === resourceId) ? resourceId : places[0].id);
    const horseIds = old?.horseIds || [visibleHorseIds(state).includes(state.horseId) ? state.horseId : horses[0].id];
    showForm(old ? 'Planning wijzigen' : pasture ? 'Naar de weide' : 'Een moment inplannen', 'fac-booking-form', `<input name="bookingId" type="hidden" value="${esc(old?.id || '')}"><fieldset class="fac-horse-picker"><legend>Voor welk paard?</legend>${horses.map(horse => `<label><input type="checkbox" name="horseIds" value="${esc(horse.id)}"${horseIds.includes(horse.id) ? ' checked' : ''}><img src="${esc(horse.image)}" alt=""><span>${esc(horse.name)}</span></label>`).join('')}</fieldset><label class="form-field">${pasture ? 'Weide' : 'Faciliteit'}<select name="resourceId">${options(places, selected, row => row.kind === 'walker' ? `${row.name} · ${row.capacity} plaatsen` : row.name)}</select></label>${input('date', 'Datum', old?.date || dateOf(state), 'type="date" required')}<div class="form-grid">${input('start', 'Van', old?.start || (pasture ? '08:00' : '10:00'), 'type="time" required')}${input('end', 'Tot', old?.end || (pasture ? '12:00' : '10:30'), 'type="time" required')}</div><label class="form-field form-block">Instructie of notitie<textarea name="note" maxlength="600" placeholder="Wat is handig om te weten?">${esc(old?.note || '')}</textarea></label>`, old ? 'Planning opslaan' : pasture ? 'Paarden toewijzen' : 'Reserveren', 'Waar staat dit paard vandaag?');
  }
  function releaseForm(mode, id) {
    const state = current(), fac = state.facilities;
    const booking = mode === 'booking' && fac.bookings.find(row => row.id === id);
    const place = resource(fac, booking ? booking.resourceId : id);
    if (!place) return;
    const date = dateOf(state);
    const phrase = mode === 'pasture' ? `Alle toewijzingen op ${dayLabel(date)} worden uit ${place.name} gehaald.` : mode === 'booking' ? `De toewijzing van ${booking.start} tot ${booking.end} op ${dayLabel(booking.date)} vervalt.` : 'Het paard wordt van deze stalplaats losgekoppeld. Het paard blijft in je overzicht.';
    showForm(`${place.name} vrijmaken?`, 'fac-release-form', `<input name="mode" type="hidden" value="${esc(mode)}"><input name="releaseId" type="hidden" value="${esc(id)}"><input name="date" type="hidden" value="${esc(date)}"><p class="fac-form-intro">${esc(phrase)}</p>`, 'Vrijmaken');
  }
  function handleAction(action, button) {
    if (!action.startsWith('fac-')) return false;
    const state = current();
    if (action === 'fac-show-all') { state.facilityFilter='all'; save(); navigate('facilities'); return true; }
    if (action === 'fac-open') { if (ROUTES.has(button.dataset.route)) navigate(button.dataset.route); return true; }
    if (action === 'fac-shift-day') { const delta = Number(button.dataset.direction); if (![1, -1].includes(delta)) return true; const date = new Date(`${dateOf(state)}T12:00:00Z`); date.setUTCDate(date.getUTCDate() + delta); state.facilityDate = date.toISOString().slice(0, 10); save(); render(); return true; }
    if (action === 'fac-select-date') { showForm('Welke dag wil je bekijken?', 'fac-date-form', input('date', 'Datum', dateOf(state), 'type="date" required'), 'Dag bekijken', 'Planning'); return true; }
    const allowed = ['fac-config', 'fac-edit-resource', 'fac-assign-stall', 'fac-horse-location', 'fac-release-stall', 'fac-book', 'fac-edit-booking', 'fac-release-booking', 'fac-free-pasture'];
    if (!allowed.includes(action)) return false;
    if(state.backend?.p2?.connected&&['fac-edit-booking','fac-release-booking'].includes(action)){
      const row=state.facilities.bookings.find(b=>b.id===button.dataset.id);
      if(action==='fac-edit-booking'&&row?.canEdit)bookingForm(row.id);
      else if(action==='fac-release-booking'&&row?.canCancel)releaseForm('booking',row.id);
      else toast('Deze reservering kun je niet aanpassen.');
      return true;
    }
    if (!requireManager()) return true;
    if (action === 'fac-config') configForm();
    else if (action === 'fac-edit-resource') resourceForm(button.dataset.resource);
    else if (action === 'fac-assign-stall') placementForm(button.dataset.resource);
    else if (action === 'fac-horse-location') { if (visibleHorseIds(state).includes(button.dataset.horse)) placementForm(undefined, button.dataset.horse); }
    else if (action === 'fac-release-stall') releaseForm('stall', button.dataset.resource);
    else if (action === 'fac-book') bookingForm(undefined, button.dataset.resource, button.dataset.kind);
    else if (action === 'fac-edit-booking') bookingForm(button.dataset.id);
    else if (action === 'fac-release-booking') releaseForm('booking', button.dataset.id);
    else if (action === 'fac-free-pasture') releaseForm('pasture', button.dataset.resource);
    return true;
  }
  function handleSubmit(form, event) {
    if (!['fac-date-form', 'fac-config-form', 'fac-resource-form', 'fac-placement-form', 'fac-booking-form', 'fac-release-form'].includes(form.id)) return false;
    event.preventDefault();
    const state = current(), fac = state.facilities, data = new FormData(form), get = name => String(data.get(name) || '').trim();
    if (form.id === 'fac-date-form') {
      if (!validDay(get('date'))) return error(form, 'Kies een geldige datum.');
      state.facilityDate = get('date'); save(); closeModal(); render(); return true;
    }
    if (!requireManager()) return true;
    let message = '';
    if (form.id === 'fac-config-form') {
      const counts = Object.fromEntries(Object.keys(FACILITY_KINDS).map(kind => [kind, Number(get(kind))]));
      const capacity = Number(get('walkerCapacity')), tackRoom = data.has('tackRoom');
      const problem = configurationError(fac, counts, capacity, tackRoom); if (problem) return error(form, problem);
      fac.resources = fac.resources.filter(row => row.number <= counts[row.kind]);
      for (const [kind, count] of Object.entries(counts)) for (let number = 1; number <= count; number++) if (!fac.resources.some(row => row.kind === kind && row.number === number)) fac.resources.push(newResource(kind, number, kind === 'walker' ? capacity : undefined));
      fac.resources.forEach(row => { if (row.kind === 'walker') row.capacity = capacity; }); fac.tackRoom = tackRoom;
      message = 'De plekken op je stal zijn bijgewerkt.';
    } else if (form.id === 'fac-resource-form') {
      const place = resource(fac, get('resourceId')); if (!place) return error(form, 'Deze plek is niet meer beschikbaar.');
      const name = get('name'), status = get('status');
      if (!name || name.length > 60 || !Object.hasOwn(STATUSES, status) || (place.kind === 'arena' ? status === 'rest' : status === 'reserved')) return error(form, 'Vul een naam en een geldige status in.');
      if (fac.resources.some(row => row.id !== place.id && row.name.toLocaleLowerCase('nl-NL') === name.toLocaleLowerCase('nl-NL'))) return error(form, 'Deze naam is al in gebruik. Kies een herkenbare andere naam.');
      if (status !== 'available' && (fac.placements.some(row => row.resourceId === place.id) || fac.bookings.some(row => row.resourceId === place.id && row.date >= dateOf(state)))) return error(form, 'Deze plek heeft nog een paard of komende planning. Maak die eerst vrij voordat je de status verandert.');
      if (place.kind === 'arena') {
        if (status !== 'available' && (fac.arenaBookings || []).some(row => row.resourceId === place.id && ['requested', 'approved'].includes(row.status) && row.date >= dateOf(state))) return error(form, 'Deze rijbak heeft nog reserveringen of aanvragen. Annuleer of beoordeel die eerst voordat je de status verandert.');
        const capacity = Number(get('arenaCapacity')), problem = arenaCapacityError(fac, place.id, capacity);
        if (problem) return error(form, problem);
        if (!['Binnenbak', 'Buitenbak', 'Overdekt'].includes(get('arenaType'))) return error(form, 'Kies een soort rijbak.');
        place.capacity = capacity; place.type = get('arenaType');
      }
      Object.assign(place, { name, status, description: get('description').slice(0, 240) });
      if (place.kind === 'stall') place.type = ['Standaardbox', 'Met uitloop', 'Hengstenbox', 'Veulenbox'].includes(get('type')) ? get('type') : 'Standaardbox';
      message = 'Naam en status zijn bijgewerkt.';
    } else if (form.id === 'fac-placement-form') {
      const place = resource(fac, get('resourceId')), horseId = get('horseId');
      if (!place || place.kind !== 'stall' || place.status !== 'available' || !visibleHorseIds(state).includes(horseId)) return error(form, 'Kies een beschikbaar paard en een vrije stalplaats.');
      if (fac.placements.some(row => row.resourceId === place.id && row.horseId !== horseId)) return error(form, 'Deze stalplaats is al bezet. Kies een andere plek of maak de huidige koppeling eerst vrij.');
      fac.placements = fac.placements.filter(row => row.horseId !== horseId && row.resourceId !== place.id);
      fac.placements.push({ resourceId: place.id, horseId, note: get('note').slice(0, 500) });
      message = 'Het paard heeft een plek op stal.';
    } else if (form.id === 'fac-booking-form') {
      const id = get('bookingId'), previous = id && fac.bookings.find(row => row.id === id);
      if (id && !previous) return error(form, 'Deze planning is inmiddels vrijgemaakt. Open een nieuwe toewijzing.');
      const draft = { id: id || `fac-${crypto.randomUUID()}`, resourceId: get('resourceId'), horseIds: data.getAll('horseIds').map(String), date: get('date'), start: get('start'), end: get('end'), note: get('note').slice(0, 600) };
      const problem = bookingError(fac, draft, visibleHorseIds(state)); if (problem) return error(form, problem);
      fac.bookings = fac.bookings.filter(row => row.id !== id); fac.bookings.push(draft); state.facilityDate = draft.date;
      message = previous ? 'De planning is bijgewerkt.' : 'Het moment staat in de planning.';
    } else if (form.id === 'fac-release-form') {
      const mode = get('mode'), id = get('releaseId');
      if (mode === 'stall') { if (resource(fac, id)?.kind !== 'stall') return error(form, 'Kies een bestaande stalplaats.'); fac.placements = fac.placements.filter(row => row.resourceId !== id); }
      else if (mode === 'booking') { if (!fac.bookings.some(row => row.id === id)) return error(form, 'Deze planning is al vrijgemaakt.'); fac.bookings = fac.bookings.filter(row => row.id !== id); }
      else if (mode === 'pasture') { if (resource(fac, id)?.kind !== 'pasture' || !validDay(get('date'))) return error(form, 'Kies een bestaande weide en datum.'); fac.bookings = fac.bookings.filter(row => !(row.resourceId === id && row.date === get('date'))); }
      else return false;
      message = 'De plek is vrijgemaakt.';
    }
    save(); closeModal(); render(); toast(message); return true;
  }
  return { handleAction, handleSubmit };
}
