// Shared facility model and validators; fixture providers are build-selected.
import {FACILITY_DAY, FACILITY_COUNTS, createFacilityFixtures as createFixtureData} from './demo-facilities.js';
export {FACILITY_DAY};
export const FACILITY_KINDS = Object.freeze({
  stall: { label: 'Stalplaatsen', singular: 'Stal', icon: 'stall', count: FACILITY_COUNTS.stall ?? 0, capacity: 1, route: 'stalls' },
  pasture: { label: 'Weides', singular: 'Weide', icon: 'pasture', count: FACILITY_COUNTS.pasture ?? 0, capacity: 6, route: 'pastures' },
  paddock: { label: 'Paddocks', singular: 'Paddock', icon: 'paddock', count: FACILITY_COUNTS.paddock ?? 0, capacity: 2, route: 'facility-planning' },
  arena: { label: 'Rijbakken', singular: 'Rijbak', icon: 'arena', count: FACILITY_COUNTS.arena ?? 0, capacity: 4, route: 'arena-planning' },
  walker: { label: 'Stapmolens', singular: 'Stapmolen', icon: 'walker', count: FACILITY_COUNTS.walker ?? 0, capacity: 4, route: 'facility-planning' },
  wash: { label: 'Wasplaatsen', singular: 'Wasplaats', icon: 'wash', count: FACILITY_COUNTS.wash ?? 0, capacity: 1, route: 'facility-planning' },
  locker: { label: 'Zadelkasten', singular: 'Kast', icon: 'locker', count: FACILITY_COUNTS.locker ?? 0, capacity: 1, route: 'facilities' },
});
export function newResource(kind, number, capacity) {
  const meta = FACILITY_KINDS[kind];
  return { id: `${kind}-${number}`, kind, number, name: `${meta.singular} ${number}`, status: 'available', capacity: capacity || meta.capacity, description: '', type: kind === 'stall' ? 'Standaardbox' : kind === 'arena' ? 'Binnenbak' : '' };
}
export function createFacilityFixtures() {
  return createFixtureData({FACILITY_KINDS, newResource, createEmptyFacilities});
}
export function createEmptyFacilities() {
  return { schema: 1, arenaSetupVersion: 1, tackRoom: false, resources: [], placements: [], bookings: [], arenaBookings: [] };
}
export function initFacilities(state) {
  const live = state.backend?.connected === true;
  const defaults = live ? createEmptyFacilities() : createFacilityFixtures();
  if (!state.facilities || state.facilities.schema !== 1) state.facilities = defaults;
  else {
    for (const key of ['resources', 'placements', 'bookings']) if (!Array.isArray(state.facilities[key])) state.facilities[key] = defaults[key];
    if (typeof state.facilities.tackRoom !== 'boolean') state.facilities.tackRoom = defaults.tackRoom;
    if (!state.facilities.arenaSetupVersion) {
      if (!live && !state.facilities.resources.some(row => row.kind === 'arena')) state.facilities.resources.push(...defaults.resources.filter(row => row.kind === 'arena'));
      if (!Array.isArray(state.facilities.arenaBookings)) state.facilities.arenaBookings = defaults.arenaBookings;
      state.facilities.arenaSetupVersion = 1;
    }
    if (!Array.isArray(state.facilities.arenaBookings)) state.facilities.arenaBookings = [];
  }
  if (!validDay(state.facilityDate)) state.facilityDate = FACILITY_DAY;
  return state.facilities;
}
export function maximumArenaOccupancy(bookings, capacity) {
  return maximumOccupancy(bookings.filter(row => row.status === 'approved').map(row => ({ ...row, horseIds: Array.from({ length: row.exclusive ? capacity : row.participants }, (_, i) => i) })));
}
export function arenaCapacityError(facilities, resourceId, capacity) {
  if (!Number.isInteger(capacity) || capacity < 1 || capacity > 30) return 'Kies een heel aantal van 1 tot en met 30 ruiters.';
  const rows = (facilities.arenaBookings || []).filter(row => row.resourceId === resourceId && ['requested', 'approved'].includes(row.status));
  if (rows.some(row => row.participants > capacity) || maximumArenaOccupancy(rows, capacity) > capacity) return 'Er staan al meer deelnemers ingepland of aangevraagd. Pas die reserveringen eerst aan voordat je de capaciteit verlaagt.';
  return '';
}
export function validDay(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value || ''))) return false;
  const d = new Date(`${value}T12:00:00Z`);
  return !Number.isNaN(d.valueOf()) && d.toISOString().slice(0, 10) === value;
}
export function validTime(value) { return /^([01]\d|2[0-3]):[0-5]\d$/.test(String(value || '')); }
export function overlaps(a, b) { return a.date === b.date && a.start < b.end && b.start < a.end; }
export function maximumOccupancy(bookings) {
  const dates = [...new Set(bookings.map(row => row.date))];
  return Math.max(0, ...dates.map(day => {
    const events = bookings.filter(row => row.date === day).flatMap(row => [{ time: row.start, delta: row.horseIds.length }, { time: row.end, delta: -row.horseIds.length }]);
    events.sort((a, b) => a.time.localeCompare(b.time) || a.delta - b.delta);
    let total = 0, maximum = 0;
    for (const event of events) { total += event.delta; maximum = Math.max(maximum, total); }
    return maximum;
  }));
}
export function bookingError(facilities, draft, accessibleIds) {
  const place = facilities.resources.find(row => row.id === draft.resourceId);
  if (!place || !['pasture', 'paddock', 'walker', 'wash'].includes(place.kind)) return 'Kies een beschikbare weide of faciliteit.';
  if (place.status !== 'available') return `${place.name} is niet beschikbaar. Kies een andere plek of pas eerst de status aan.`;
  if (!validDay(draft.date) || !validTime(draft.start) || !validTime(draft.end)) return 'Vul een geldige datum en begin- en eindtijd in.';
  if (draft.end <= draft.start) return 'Kies een eindtijd na de begintijd.';
  if (!draft.horseIds.length || new Set(draft.horseIds).size !== draft.horseIds.length || draft.horseIds.some(id => !accessibleIds.includes(id))) return 'Kies minstens één paard uit je eigen overzicht.';
  const others = facilities.bookings.filter(row => row.id !== draft.id);
  if (maximumOccupancy([...others.filter(row => row.resourceId === place.id), draft]) > place.capacity) return `${place.name} heeft op dit tijdstip te weinig vrije plaatsen. Kies een ander tijdstip of minder paarden.`;
  const outdoor = new Set(['pasture', 'paddock']);
  const sameUse = kind => outdoor.has(place.kind) ? outdoor.has(kind) : ['walker', 'wash'].includes(kind);
  if (others.some(row => overlaps(row, draft) && row.horseIds.some(id => draft.horseIds.includes(id)) && sameUse(facilities.resources.find(resource => resource.id === row.resourceId)?.kind))) return 'Een gekozen paard staat in dit tijdvak al op een andere plek ingepland. Pas de bestaande planning aan of kies een andere tijd.';
  return '';
}
export function configurationError(facilities, counts, walkerCapacity, tackRoom) {
  if (Object.keys(FACILITY_KINDS).some(kind => !Number.isInteger(counts[kind]) || counts[kind] < 0 || counts[kind] > 50)) return 'Gebruik per soort een heel aantal van 0 tot en met 50.';
  if (!Number.isInteger(walkerCapacity) || walkerCapacity < 1 || walkerCapacity > 20) return 'Een stapmolen heeft 1 tot en met 20 plaatsen.';
  if (!tackRoom && counts.locker > 0) return 'Zet de zadelkamer aan of kies 0 zadelkasten.';
  const removed = facilities.resources.filter(row => row.number > counts[row.kind]);
  const used = removed.find(row => facilities.placements.some(item => item.resourceId === row.id) || facilities.bookings.some(item => item.resourceId === row.id) || (facilities.arenaBookings || []).some(item => item.resourceId === row.id));
  if (used) return `${used.name} heeft nog een paard of bewaarde planning. Deze plek kan niet worden verwijderd zolang die toewijzingen bewaard blijven.`;
  const tooSmall = facilities.resources.find(row => row.kind === 'walker' && row.number <= counts.walker && maximumOccupancy(facilities.bookings.filter(item => item.resourceId === row.id)) > walkerCapacity);
  if (tooSmall) return `${tooSmall.name} heeft al meer paarden tegelijk ingepland dan het nieuwe aantal plaatsen.`;
  return '';
}
