import {renderHorseArena} from './arena.js';
import { getPersona, getVisibleState, horseAccessLabel, canManage } from './horse-access.js';

import {renderHorseLocation} from './facilities.js';

const doneStates = new Set(['completed', 'done', 'cancelled', 'afgerond', 'geannuleerd']);

function selectedHorse(state, ctx) {
  const view = getVisibleState(state);
  return state.horseId ? view.horses.find(horse => horse.id === state.horseId) : view.horses[0];
}

function nextActivity(state, id) {
  return state.activities
    .filter(item => (item.horseId || item.horse) === id && !doneStates.has(String(item.status || '').toLowerCase()) && (!state.backend?.connected || item.date >= (state.backend.todayDate || state.today)))
    .sort((a, b) => `${a.date || ''} ${a.time || ''}`.localeCompare(`${b.date || ''} ${b.time || ''}`))[0];
}

function activityLabel(activity, state) {
  if (!activity) return 'Ruimte voor een volgende afspraak';
  const date = activity.date ? new Date(`${activity.date}T12:00:00`) : null;
  const day = activity.dayLabel || activity.dateLabel || activity.day || (activity.date === (state.backend?.connected ? state.backend.todayDate || state.today : state.selectedDay) ? 'Vandaag' : date && !Number.isNaN(date.valueOf()) ? date.toLocaleDateString('nl-NL', { day: 'numeric', month: 'short' }) : '');
  return [day, activity.time, activity.title || activity.type].filter(Boolean).join(' · ');
}

function navigate(route, id, label, ctx, className = '') {
  return `<button class="${className}" data-action="navigate" data-route="${route}" data-horse="${ctx.esc(id)}">${label}</button>`;
}

function unavailableHorse(ctx) {
  return `<section class="horse-page"><div class="horse-list-empty"><h2>Dit paard staat niet in jouw overzicht</h2><p>Ga terug naar de paarden die voor jou beschikbaar zijn.</p><button class="horse-text-link" data-action="navigate" data-route="horses">${ctx.icon('chevron-left', 16)} Naar je paarden</button></div></section>`;
}

export function renderHorses(state, ctx) {
  state = getVisibleState(state);
  const { esc, icon } = ctx;
  const actor = getPersona(state);
  const filter = ['personal', 'stable', 'assigned'].includes(state.horseFilter) ? state.horseFilter : 'personal';
  const horses = state.horses.filter(horse => filter === 'personal' ? actor.personalHorseIds.includes(horse.id) : filter === 'assigned' ? actor.assignedHorseIds.includes(horse.id) : horse.stable === state.stableName);
  const description = filter === 'personal' ? 'Je eigen paarden en persoonlijke toegang.' : filter === 'assigned' ? 'De paarden voor jouw planning en verzorging.' : `${state.stableName || 'Jouw stal'} · de paarden die je mag bekijken.`;
  const canAdd = state.backend?.connected || canManage(state) || (actor.roleKind||actor.id) === 'owner';
  return `<section class="horse-page">
    <div class="horse-page-heading"><div><p class="horse-eyebrow">Dicht bij je paarden</p><h1>Paarden</h1><p class="horse-intro">Hun dag, op één vertrouwde plek.</p></div>${canAdd ? `<button class="horse-add" data-action="new-horse">${icon('plus', 18)}<span>Paard toevoegen${state.backend?.connected?'':'<small>Binnenkort</small>'}</span></button>` : ''}</div>
    <div class="horse-filters" role="group" aria-label="Welke paarden wil je zien?">${[['personal', 'Mijn paarden'], ['stable', 'Stalpaarden'], ['assigned', 'Toegewezen']].map(([value, label]) => `<button data-action="horse-filter" data-filter="${value}" aria-pressed="${filter === value}">${label}</button>`).join('')}</div>
    <div class="horse-list-context"><p>${esc(description)}</p><span>${horses.length} ${horses.length === 1 ? 'paard' : 'paarden'}</span></div>
    <div class="horse-grid">${horses.map(h => {
      const feed = state.feeding[h.id];
      const activity = nextActivity(state, h.id);
      const identity = [h.breed, h.age != null ? `${h.age} jaar` : ''].filter(Boolean).join(' · ');
      return `<article class="horse-card">
        ${navigate('horse-overview', h.id, `<img src="${esc(h.image)}" alt="${esc(h.name)}" class="horse-card-photo">${h.imageIsPlaceholder?'<span class="photo-example">Voorbeeldfoto</span>':''}<span class="horse-photo-arrow">${icon('chevron-right', 20)}</span>`, ctx, 'horse-image-button')}
        <div class="horse-card-body">
          <div class="horse-card-identity"><div><h2>${navigate('horse-overview', h.id, esc(h.name), ctx, 'horse-name-link')}</h2>${identity ? `<p>${esc(identity)}</p>` : ''}</div><span class="horse-access-label">${esc(horseAccessLabel(state, h))}</span></div>
          <p class="horse-stable-line">${icon('stable', 16)}<span>${esc(h.stable)}${(actor.roleKind||actor.id) === 'groom' ? ' · Toegewezen' : ''}</span></p>
          <div class="horse-card-signals"><div>${icon('calendar', 18)}<span>${esc(activityLabel(activity, state))}</span></div><div>${icon('feed', 18)}<span>${esc(feed?.status || 'Bekijk de voerinstructies')}</span></div></div>
        </div>
        <nav class="horse-card-actions" aria-label="${esc(h.name)} bekijken">${navigate('horse-overview', h.id, 'Overzicht', ctx)}${navigate('horse-planning', h.id, 'Planning', ctx)}${navigate('horse-feeding', h.id, 'Voeding', ctx)}</nav>
      </article>`;
    }).join('')}</div>
    ${horses.length ? '' : `<div class="horse-list-empty"><h2>${filter === 'personal' ? 'Je eigen plek voor je paarden' : filter === 'assigned' ? 'Nog geen paarden toegewezen' : 'Geen stalpaarden in dit overzicht'}</h2><p>${filter === 'personal' && actor.assignedHorseIds.length ? 'De paarden waarvoor je zorgt, vind je onder Toegewezen.' : filter === 'personal' ? 'Hier komen je eigen paarden en paarden met persoonlijke toegang.' : filter === 'assigned' ? 'Paarden met een taak of afspraak voor jou verschijnen hier.' : 'Je ziet hier alleen beschikbare paarden van de huidige stal.'}</p>${filter === 'personal' && actor.assignedHorseIds.length ? `<button class="horse-text-link" data-action="horse-filter" data-filter="assigned">Bekijk toegewezen paarden ${icon('chevron-right', 16)}</button>` : ''}</div>`}
  </section>`;
}

export function renderHorseHeader(state, ctx) {
  state = getVisibleState(state);
  const h = selectedHorse(state, ctx);
  if (!h) return unavailableHorse(ctx);
  const { esc, icon } = ctx;
  return `<header class="horse-header">
    <button class="horse-back" data-action="navigate" data-route="horses">${icon('chevron-left', 16)} Alle paarden</button>
    <div class="horse-header-main"><img class="horse-header-photo" src="${esc(h.image)}" alt="${esc(h.name)}">
      <div class="horse-header-copy">${h.imageIsPlaceholder?'<small class="backend-photo-note">Voorbeeldfoto</small>':''}<p class="horse-eyebrow">${esc(h.stable)}</p><h1>${esc(h.name)}</h1>${h.breed || h.age != null ? `<p>${esc([h.breed, h.age != null ? `${h.age} jaar` : ''].filter(Boolean).join(' · '))}</p>` : ''}<span class="horse-access-label">${esc(horseAccessLabel(state, h))}</span></div>
    </div>
  </header>`;
}

export function renderHorseTabs(state, ctx) {
  const h = selectedHorse(state, ctx);
  if (!h) return '';
  return `<nav class="horse-tabs" aria-label="Paardpagina">${[
    ['horse-overview', 'Overzicht'], ['horse-planning', 'Planning'], ['horse-feeding', 'Voeding'],
  ].map(([route, label]) => `<button data-action="navigate" data-route="${route}" data-horse="${ctx.esc(h.id)}" ${state.route === route ? 'aria-current="page"' : ''}>${label}</button>`).join('')}</nav>`;
}

function mealPreview(feed, ctx) {
  if (!feed) return '<p class="horse-muted">Een rustig ritme begint met een helder voerplan.</p>';
  return `<div class="horse-meal-preview">${feed.meals.map(meal => `<div><span>${ctx.esc(meal.name)}</span><strong>${meal.items.length ? meal.items.map(item => ctx.esc(`${item.amount} ${item.product}`)).join(' · ') : 'Geen extra gift'}</strong></div>`).join('')}</div>`;
}

function teamPreview(state, h, ctx) {
  const members = Array.isArray(h.team) ? h.team : !state.backend?.connected&&Array.isArray(state.team) ? state.team.slice(0, 3) : [];
  if (!members.length&&state.backend?.connected) return '<p class="horse-muted">Er zijn nog geen betrokkenen aan dit paard gekoppeld.</p>';
  if (!members.length) return `<div class="horse-team-place">${ctx.icon('stable', 24)}<div><strong>${ctx.esc(h.stable)}</strong><p>De vertrouwde plek van ${ctx.esc(h.name)}.</p></div></div>`;
  return `<div class="horse-team">${members.map(member => {
    const name = typeof member === 'string' ? member : member.name;
    const role = typeof member === 'string' ? '' : member.role;
    const parts = String(name || '').split(' ').filter(Boolean);
    const initials = [parts[0]?.[0], parts.length > 1 ? parts.at(-1)?.[0] : ''].join('').toUpperCase();
    return `<div class="horse-person"><span class="horse-person-avatar" aria-hidden="true">${ctx.esc(initials)}</span><div><strong>${ctx.esc(name || '')}</strong>${role ? `<span>${ctx.esc(role)}</span>` : ''}</div></div>`;
  }).join('')}</div>`;
}

export function renderHorseOverview(state, ctx) {
  state = getVisibleState(state);
  const h = selectedHorse(state, ctx);
  if (!h) return unavailableHorse(ctx);
  const showProfile = state.backend?.connected || canManage(state) || getPersona(state).personalHorseIds.includes(h.id);
  const feed = state.feeding[h.id];
  const activity = nextActivity(state, h.id);
  const { esc, icon } = ctx;
  return `<section class="horse-page">${renderHorseHeader(state, ctx)}${renderHorseTabs(state, ctx)}
    ${state.backend?.connected?`<div class="quick-actions"><button class="button-secondary" data-action="horse-residency" data-horse="${esc(h.id)}">${icon('location',17)} Verblijfplaats</button>${h.capabilities?.edit?`<button class="button-secondary" data-action="edit-horse" data-horse="${esc(h.id)}">${icon('edit',17)} Paardgegevens aanpassen</button><button class="button-secondary" data-action="horse-photo" data-horse="${esc(h.id)}">${icon('camera',17)} ${h.photoStatus==='ready'?'Foto wijzigen':'Foto toevoegen'}</button>`:''}</div>${h.photoStatus==='unavailable'?'<p class="horse-muted">De foto kon niet worden geladen. Je paardgegevens zijn beschikbaar.</p>':h.photoStatus==='none'?'<p class="horse-muted">Er is nog geen foto toegevoegd.</p>':''}`:''}
    ${renderHorseLocation(state,ctx,h.id)}${renderHorseArena(state,ctx,h.id)}
    <div class="horse-overview-grid">
      <section class="horse-section horse-next"><div class="horse-section-heading"><div><p class="horse-eyebrow">Samen op pad</p><h2>Volgende afspraak</h2></div>${icon('calendar', 22)}</div>
        ${activity ? ctx.activityCard(activity, { compact: true, showHorse: false }) : '<p class="horse-muted">Nog even alle ruimte in de agenda.</p>'}
        ${navigate('horse-planning', h.id, `Bekijk de planning ${icon('chevron-right', 16)}`, ctx, 'horse-text-link')}
      </section>
      <section class="horse-section horse-feed-preview"><div class="horse-section-heading"><div><p class="horse-eyebrow">Een vertrouwd ritme</p><h2>Voeding vandaag</h2></div>${icon('feed', 24)}</div>
        ${feed ? `<span class="horse-feed-status"><span></span>${esc(feed.status)}</span>` : ''}
        ${mealPreview(feed, ctx)}
        ${navigate('horse-feeding', h.id, `Bekijk het voerplan ${icon('chevron-right', 16)}`, ctx, 'horse-text-link')}
      </section>
      ${canManage(state) ? `<section class="horse-section horse-people"><div class="horse-section-heading"><div><p class="horse-eyebrow">Samen voor ${esc(h.name)}</p><h2>In vertrouwde handen</h2></div>${icon('users', 22)}</div>${teamPreview(state, h, ctx)}</section>` : ''}
      ${showProfile ? `<details class="horse-details"><summary><span><span class="horse-eyebrow">Alles bij elkaar</span><strong>Paardgegevens</strong></span>${icon('chevron-right', 20)}</summary><dl>${[
        ['Naam', h.name], ['Ras', h.breed], ['Leeftijd', h.age != null ? `${h.age} jaar` : ''], ['Geslacht', h.sex], ['Kleur', h.color], ['Stokmaat', h.height], ['Discipline', h.discipline], ['Stal', h.stable],  ['Eigenaar', h.owner],
      ].filter(([, value]) => value).map(([label, value]) => `<div><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`).join('')}</dl></details>` : ''}
    </div>
  </section>`;
}
