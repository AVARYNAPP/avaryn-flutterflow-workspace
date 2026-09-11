// Demo providers are replaced with empty, non-authoritative providers in release builds.
import {PERSONAS, DEFAULT_PERSONA} from './demo-personas.js';
export {PERSONAS};

export function getPersona(state) {
  if(state?.backend?.connected)return state.backend.actor;
  return Object.hasOwn(PERSONAS, state?.persona) ? PERSONAS[state.persona] : DEFAULT_PERSONA;
}
export function visibleHorseIds(state) {
  const existing = new Set((state?.horses || []).map(horse => horse.id));
  return getPersona(state).accessibleHorseIds.filter(id => existing.has(id));
}
export function canManage(state) { return state?.backend?.connected ? state.backend.capabilities?.canManage===true : getPersona(state).id === 'manager'; }
export function canViewTeam(state) { return state?.backend?.connected ? state.backend.capabilities?.canViewTeam===true : canManage(state); }
export function canEditFeeding(state, horse) {
  if(state?.backend?.connected){const id=typeof horse==='string'?horse:horse?.id;return id?state.backend.horseCapabilities?.[id]?.feeding===true:state.backend.capabilities?.canEditFeeding===true;}
  const actor = getPersona(state);
  if (!['manager', 'owner'].includes(actor.id)) return false;
  if (!horse) return true;
  const id = typeof horse === 'string' ? horse : horse.id;
  return actor.accessibleHorseIds.includes(id) && (actor.id === 'manager' || actor.personalHorseIds.includes(id));
}
export function canCreateTask(state) { return state?.backend?.connected ? state.backend.capabilities?.canCreateTask===true : ['manager', 'owner'].includes(getPersona(state).id); }
export function canPlan(state,horseId) { return state?.backend?.connected ? (horseId?state.backend.horseCapabilities?.[horseId]?.planning===true:state.backend.capabilities?.canPlan===true) : ['manager', 'owner', 'rider'].includes(getPersona(state).id); }
export function canShareMoment(state) { return state?.backend?.connected ? state.backend.capabilities?.canShareMoment===true : Boolean(getPersona(state).id) && getPersona(state).id !== 'groom'; }
export function horseAccessLabel(state, horse) {
  const actor = getPersona(state);
  if (!horse || !actor.accessibleHorseIds.includes(horse.id)) return 'Beperkte toegang';
  if ((actor.roleKind||actor.id) === 'groom') return 'Beperkte toegang';
  if (actor.personalHorseIds.includes(horse.id)) return 'Eigen paard';
  if (actor.assignedHorseIds.includes(horse.id)) return 'Toegewezen';
  return 'Stalpaard';
}

const pick = (value, fields) => Object.fromEntries(fields.filter(key => Object.hasOwn(value, key)).map(key => [key, value[key]]));
const dailyHorseFields = ['id', 'name', 'image', 'stable', 'box'];
const nameMatches = (value, name) => Boolean(String(name || '').trim()) && String(value || '').trim().toLocaleLowerCase('nl-NL') === name.toLocaleLowerCase('nl-NL');

export function getVisibleState(state) {
  const view = JSON.parse(JSON.stringify(state || {}));
  if(view.backend?.connected)return view; // This snapshot contains only server-authorized core data.
  const actor = getPersona(view);
  const ids = new Set(visibleHorseIds(view));
  view.persona = actor.id;
  view.horses = (view.horses || []).filter(horse => ids.has(horse.id)).map(horse => {
    if (actor.id === 'manager') return horse;
    if (actor.personalHorseIds.includes(horse.id)) {
      const { team, ...personal } = horse;
      return personal;
    }
    return pick(horse, actor.id === 'groom' ? dailyHorseFields : [...dailyHorseFields, 'breed', 'age', 'discipline']);
  });
  if (view.facilities?.placements && view.facilities?.resources) {
    view.horses.forEach(horse => {
      const place = view.facilities.placements.find(p => p.horseId === horse.id);
      horse.box = place ? (view.facilities.resources.find(r => r.id === place.resourceId)?.name || 'Stalplaats bekijken') : 'Geen stalplaats gekoppeld';
    });
  }
  view.activities = (view.activities || []).filter(activity => ids.has(activity.horseId)).map(activity =>
    pick(activity, ['id', 'horseId', 'type', 'title', 'date', 'time', 'end', 'status', 'person', 'location', 'note']));
  view.tasks = (view.tasks || []).filter(task => {
    if (actor.id === 'manager') return !task.horseId || ids.has(task.horseId);
    if (actor.id === 'groom') return (!task.horseId||ids.has(task.horseId)) && nameMatches(task.assignee, actor.name);
    return ids.has(task.horseId) || (!task.horseId && nameMatches(task.assignee, actor.name));
  }).map(task => pick(task, ['id', 'horseId', 'title', 'date', 'time', 'location', 'note', 'status', 'assignee']));
  view.feeding = Object.fromEntries(Object.entries(view.feeding || {}).filter(([id]) => ids.has(id)).map(([id, feed]) => [id, {
    ...pick(feed, ['status', 'note', 'until']),
    meals: (feed.meals || []).map(meal => ({ ...pick(meal, ['name', 'time']), items: (meal.items || []).map(item => pick(item, ['product', 'amount', 'note'])) })),
  }]));
  view.team = actor.id === 'manager' ? (view.team || []) : [];
  if (view.selectedTaskId && !view.tasks.some(task => task.id === view.selectedTaskId)) view.selectedTaskId = null;
  return view;
}

export function canManageFacilities(state) { return state?.backend?.p2?.connected ? state.backend.p2.canManage===true : canManage(state); }
export function canBookFacilities(state) { return state?.backend?.p2?.connected ? state.backend.p2.canBook===true : canPlan(state); }
