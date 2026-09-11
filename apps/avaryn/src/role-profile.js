import { getPersona, canManage, canCreateTask, canPlan, canBookFacilities, canShareMoment } from './horse-access.js';

export const ROLE_FUNCTIONS = Object.freeze([
  { id: 'owner', label: 'Paardeigenaar', description: 'De dagelijkse zorg voor je eigen paard.', icon: 'horse', later: false },
  { id: 'rider', label: 'Ruiter', description: 'Rijden, beleven en samen groeien.', icon: 'horse', later: false },
  { id: 'manager', label: 'Stalhouder / stalmanager', description: 'Rust en overzicht voor stal en team.', icon: 'stable', later: false },
  { id: 'trainer', label: 'Trainer', description: 'Paard en ruiter begeleiden in hun ontwikkeling.', icon: 'trophy', later: false },
  { id: 'groom', label: 'Groom / medewerker', description: 'Aandacht voor het dagelijkse werk op stal.', icon: 'tasks', later: false },
  { id: 'farrier', label: 'Hoefsmid', description: 'Afspraken en betrokken paarden bij de hand.', icon: 'horse', later: false },
  { id: 'vet', label: 'Dierenarts', description: 'Een ingang voor afspraken en zorgnotities.', icon: 'heart', later: false },
  { id: 'physio', label: 'Fysiotherapeut / osteopaat', description: 'Begeleiding en aandacht voor beweging.', icon: 'leaf', later: false },
  { id: 'nutrition', label: 'Voedingsadviseur', description: 'Voerplannen en betrokken paarden bekijken.', icon: 'feed', later: false },
  { id: 'breeder', label: 'Fokker', description: 'Een passende plek voor later.', icon: 'horse', later: true },
  { id: 'partner', label: 'Leverancier / partner', description: 'Producten en samenwerking, apart uitgewerkt.', icon: 'leaf', later: true },
  { id: 'organizer', label: 'Wedstrijdorganisatie', description: 'Evenementen en ontmoetingen, voor later.', icon: 'trophy', later: true },
  { id: 'sponsor', label: 'Sponsor / merk', description: 'Herkenbare samenwerkingen, voor later.', icon: 'heart', later: true },
].map(item => Object.freeze(item)));

const defaults = Object.freeze({
  manager: Object.freeze(['owner', 'manager']), owner: Object.freeze(['owner']),
  rider: Object.freeze(['rider', 'trainer']), groom: Object.freeze(['groom']),
});
const activeIds = new Set(ROLE_FUNCTIONS.filter(item => !item.later).map(item => item.id));

function profileKind(state) {
  const actor = getPersona(state);
  if (Object.hasOwn(defaults, actor.roleKind)) return actor.roleKind;
  if (Object.hasOwn(defaults, actor.id)) return actor.id;
  return canManage(state) ? 'manager' : canPlan(state) ? 'rider' : 'groom';
}

// Preferences only. This module never changes persona or horse-access rules.
export function getFunctions(state) {
  const id = getPersona(state).id;
  const saved = state?.functionProfiles?.[id];
  const selected = Array.isArray(saved) ? [...new Set(saved.filter(value => activeIds.has(value)))] : [];
  return selected.length ? selected : [...defaults[profileKind(state)]];
}

export function roleProfileLabels(state) {
  return getFunctions(state).map(id => ROLE_FUNCTIONS.find(item => item.id === id).label);
}

function functionChoice(item, selected, ctx) {
  return `<label class="role-function${item.later ? ' role-function-later' : ''}">
    <input type="checkbox" name="functions" value="${item.id}"${selected.includes(item.id) ? ' checked' : ''}${item.later ? ' disabled' : ''}>
    <span class="role-function-icon">${ctx.icon(item.icon, 23)}</span>
    <span class="role-function-copy"><strong>${ctx.esc(item.label)}</strong><small>${ctx.esc(item.description)}</small>${item.later ? '<span class="role-later-badge">Binnenkort</span>' : ''}</span>
  </label>`;
}

export function renderRoleProfile(state, ctx) {
  const selected = getFunctions(state);
  const limitedProfessional = !canPlan(state) && selected.some(id => ['farrier', 'vet', 'physio', 'trainer', 'rider', 'manager'].includes(id));
  return `<section class="role-profile-page"><header class="role-profile-heading"><span class="role-profile-kicker">Op jouw manier</span><h1>Mijn functieprofiel</h1><p>Waarvoor gebruik jij AVARYN?</p></header>
    <div class="role-profile-intro"><span>${ctx.icon('roles', 29)}</span><p>Je kunt meerdere rollen kiezen. Dit helpt AVARYN om je startscherm, acties en menu’s beter te laten aansluiten.</p></div>
    <form id="role-profile-form" aria-describedby="role-profile-help role-profile-access">
      <fieldset class="role-fieldset"><legend>Jouw functies</legend><p id="role-profile-help">Kies minimaal één functie. Meerdere functies tegelijk is prima.</p><div class="role-function-grid">${ROLE_FUNCTIONS.filter(item => !item.later).map(item => functionChoice(item, selected, ctx)).join('')}</div></fieldset>
      <details class="role-future"><summary><span><strong>Verder vooruit</strong><small>Deze functies volgen later.</small></span>${ctx.icon('chevron-down', 18)}</summary><div class="role-function-grid">${ROLE_FUNCTIONS.filter(item => item.later).map(item => functionChoice(item, [], ctx)).join('')}</div></details>
      <aside class="role-access" id="role-profile-access">${ctx.icon('info', 23)}<div><h2>Jouw toegang blijft apart</h2><p>Een functie kiezen geeft geen extra toegang. Wat je bij een paard of stal mag bekijken en doen, blijft gekoppeld aan je stalteam, paardrechten en uitnodigingen.</p><p>Je huidige toegang: <strong>${ctx.esc(getPersona(state).roleLabel)}</strong>.</p>${limitedProfessional ? '<p class="role-access-hint">Je gekozen functie sluit aan op je werk. Met je huidige toegang kun je afspraken en instructies bekijken; zelf plannen of beheer openen wordt daarmee niet beschikbaar.</p>' : ''}</div></aside>
      <p id="role-profile-error" class="role-profile-error" role="alert" aria-live="polite"></p>
      <footer class="role-profile-save"><p>Je kunt je voorkeuren later weer aanpassen.</p><button type="submit">${ctx.icon('check', 19)} Functies opslaan</button></footer>
    </form>
  </section>`;
}

export function getProfileQuickActions(state) {
  const functions = new Set(getFunctions(state));
  const kind = profileKind(state);
  const vitality = ['owner', 'rider', 'trainer'].some(id => functions.has(id));
  const result = [];
  const seen = new Set();
  const add = (action, label, description, icon, options = {}) => {
    const item = { action, label, description, icon, ...options };
    const key = [action, item.route || '', item.feature || '', item.type || ''].join(':');
    if (!seen.has(key)) { seen.add(key); result.push(item); }
  };
  const view = (route, label, description, icon) => add('navigate', label, description, icon, { route });
  const coming = (feature, label, description, icon) => add('coming', label, description, icon, { feature, coming: true });
  const plan = (label, type) => canPlan(state)
    ? add('new-activity', label, 'Een afspraak in jullie agenda zetten.', 'calendar', { type })
    : view('planning', 'Afspraken bekijken', 'Je huidige toegang geeft kijktoegang; een functie kiezen geeft geen planningsrecht.', 'calendar');
  const share = () => { if (!vitality && canShareMoment(state)) add('share-moment', 'Moment delen', 'Bewaar een moment dat je bijblijft.', 'heart', { coming: true }); };
  const feeding = label => add('open-feeding', label, 'Bekijk het voerplan binnen je bestaande toegang.', 'feed');
  const horses = label => view('horses', label, 'Alleen de paarden die al voor jou toegankelijk zijn.', 'horse');

  if (functions.has('owner')) {
    if (state.backend?.connected || ['manager', 'owner'].includes(kind)) add('new-horse', 'Paard toevoegen', 'Een eigen plek voor je paard.', 'horse', { coming: !state.backend?.connected });
    feeding('Voerplan openen'); plan('Training plannen', 'Training'); share();
    if (kind !== 'groom') coming('document', 'Document toevoegen', 'Belangrijke papieren bij je paard bewaren.', 'tasks');
  }
  if (functions.has('rider') || functions.has('trainer')) {
    plan('Training plannen', 'Training');
    if (canPlan(state)) {
      coming('competition', 'Wedstrijd toevoegen', 'Bereid jullie volgende start voor.', 'trophy');
    }
    share();
  }
  if (functions.has('manager')) {
    if (canCreateTask(state)) add('new-task', 'Taak toevoegen', 'Een klus voor later, vandaag of een gekozen moment.', 'tasks');
    if (canManage(state)) add('team-invite', 'Teamlid uitnodigen', 'Samen zorgen voor je paarden.', 'users', { coming: !state.backend?.connected });
    view('pastures', 'Weideplanning openen', canManage(state) ? 'Waar staat welk paard vandaag?' : 'Bekijk de planning binnen je bestaande toegang.', 'pasture');
    view('facility-planning', canManage(state) ? 'Faciliteit plannen' : 'Faciliteitenplanning bekijken', canManage(state) ? 'Vind ruimte in de stapmolen of wasplaats.' : 'Je gekozen functie geeft geen beheerrechten.', 'walker');
  }
  if (functions.has('groom') || kind === 'groom') {
    view('tasks', 'Mijn taken', 'Lees de instructie en rond je taak af.', 'tasks');
    feeding('Voeding vandaag'); share();
  }
  if (functions.has('farrier')) {
    plan('Hoefsmidafspraak plannen', 'Hoefsmid'); horses('Betrokken paarden');
    if (canPlan(state)) coming('treatment-note', 'Notitie na behandeling', 'Ruimte voor een eigen terugblik, later beschikbaar.', 'edit');
    coming('availability', 'Eigen beschikbaarheid', 'Laat later weten wanneer je beschikbaar bent.', 'clock');
  }
  if (functions.has('vet')) {
    plan('Dierenartsafspraak plannen', 'Dierenarts'); horses('Betrokken paarden');
    if (canPlan(state)) {
      coming('treatment-note', 'Behandelnotitie', 'Een toekomstige notitieplek; nog geen medisch dossier.', 'edit');
      coming('document', 'Document toevoegen', 'Bestanden gericht bewaren en delen, voor later.', 'tasks');
    }
  }
  if (functions.has('physio')) {
    plan('Behandeling plannen', 'Verzorging');
    if (canPlan(state)) coming('treatment-note', 'Notitie toevoegen', 'Leg later je eigen observaties vast.', 'edit');
    coming('progress', 'Voortgang bekijken', 'Een terugblik op jullie ontwikkeling, voor later.', 'calendar');
  }
  if (functions.has('nutrition')) {
    feeding('Voerplan bekijken'); horses('Paarden met voedingstoegang');
    if (kind !== 'groom') coming('advice-note', 'Adviesnotitie', 'Een toekomstige notitieplek; hier wordt geen voedingsadvies gegeven.', 'edit');
  }
  // Personal prototype actions, never an authorization shortcut for horses, teams or social posting.
  if (vitality) {
    const prototype = { group: 'rider-vitality', status: state.backend?.connected?'':'Prototype' };
    add('vitality-warmup', 'Warming-up starten', 'Een korte voorbereiding vóór je rit.', 'sun', prototype);
    add('vitality-reflection', 'Trainingsreflectie', 'Sta stil bij jullie rit en wat je meeneemt.', 'edit', prototype);
    add('vitality-focus', 'Focuspunt toevoegen', 'Eén aandachtspunt voor de volgende keer.', 'check', prototype);
    add('vitality-share', 'Moment delen', 'Bekijk een deelvoorbeeld; er wordt niets verstuurd.', 'heart', {...prototype,status:'Voorbeeld'});
  }
  const arenaPreferred = canManage(state) || ['manager', 'rider', 'trainer'].some(id => functions.has(id));
  if (arenaPreferred && canBookFacilities(state)) {
    add('arena-reserve', 'Rijbak reserveren', 'Kies een plek voor jullie training.', 'arena', { status: state.backend?.p2?.connected ? '' : 'Prototype' });
  } else if (arenaPreferred || functions.has('groom') || kind === 'groom') {
    add('navigate', 'Rijbakplanning bekijken', 'Bekijk de planning binnen je bestaande toegang.', 'arena', { route: 'arena-planning', status: state.backend?.p2?.connected ? '' : 'Prototype' });
  }
  // A preference never creates management rights. Existing managers keep this entry.
  if (canManage(state)) add('manage-stable', 'Stal beheren', 'De gegevens van je stal bijwerken.', 'settings');
  if (!result.length) horses('Mijn toegankelijke paarden');
  return result;
}

export function getPreferredMenuIds(state) {
  const functions = new Set(getFunctions(state));
  const ids = new Set(['tasks', 'feeding-today', 'calendar', 'moments', 'profile', 'role-profile', 'settings', 'plans', 'support']);
  const add = (...values) => values.forEach(value => ids.add(value));
  if (['owner', 'rider', 'trainer'].some(id => functions.has(id))) add('vitality-exercises', 'vitality-warmup', 'vitality-cooldown', 'vitality-mobility', 'vitality-focus', 'vitality-goals', 'vitality-feeling', 'vitality-journal');
  if (functions.has('owner')) add('feeding-plans', 'health-care', 'farrier', 'veterinarian', 'documents', 'friends');
  if (functions.has('rider') || functions.has('trainer')) add('training-log', 'goals', 'competitions', 'results', 'inspiration', 'arenas');
  if (functions.has('manager')) add('facilities', 'pastures', 'boxes', 'facility-planning', 'pasture-facilities', 'paddocks', 'walker', 'wash', 'locker', 'availability', 'arenas');
  if (functions.has('groom') || profileKind(state) === 'groom') add('pastures', 'facility-planning', 'availability', 'arenas');
  if (functions.has('farrier')) add('farrier', 'health-care', 'availability', 'contacts');
  if (functions.has('vet')) add('veterinarian', 'health-care', 'documents', 'contacts');
  if (functions.has('physio')) add('health-care', 'training-log', 'availability');
  if (functions.has('nutrition')) add('feeding-plans', 'nutrition-products', 'health-care');
  if (canManage(state)) add('team', 'management', 'arenas');
  return [...ids];
}
