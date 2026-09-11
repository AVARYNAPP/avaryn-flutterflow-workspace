import {getActiveStableView} from './stable-view.js';
import { getVisibleState, canEditFeeding } from './horse-access.js';
import { renderHorseHeader, renderHorseTabs } from './horses.js';

const mealIcon = name => ({ Ochtend: 'sunrise', Middag: 'sun', Avond: 'moon' }[name] || 'feed');

const displayDate=value=>value?String(value).split('-').reverse().join('-'):'';
function feedStatus(feed, ctx) {
  return `<div class="feeding-plan-status"><span class="feeding-status-dot"></span>${ctx.esc(feed.status || 'Voerplan')}<span class="feeding-status-detail">${feed.effectiveUntil?`Tot en met ${ctx.esc(displayDate(feed.effectiveUntil))}`:'Dagelijks ritme'}</span></div>`;
}

function feedItem(item, ctx) {
  return `<li class="feeding-item"><div class="feeding-item-main"><strong>${ctx.esc(item.product)}</strong><span class="feeding-amount">${ctx.esc(item.amount)}</span></div>${item.note ? `<p class="feeding-item-note">${ctx.icon('info', 15)}<span>${ctx.esc(item.note)}</span></p>` : ''}</li>`;
}

function mealBlock(meal, ctx) {
  return `<section class="feeding-meal"><header><div class="feeding-meal-icon">${ctx.icon(mealIcon(meal.name), 23)}</div><div><h3>${ctx.esc(meal.name)}</h3>${meal.time ? `<span>${ctx.esc(meal.time)}</span>` : ''}</div></header>
    ${meal.items.length ? `<ul class="feeding-items">${meal.items.map(item => feedItem(item, ctx)).join('')}</ul>` : '<p class="feeding-no-gift">Geen producten vastgelegd voor dit dagdeel.</p>'}
  </section>`;
}

function planLibrary(state,h,feed,ctx){
  if(!state.backend?.connected)return '';
  const plans=(feed?.plans||[]).filter(p=>p.planStatus!=='retired'),basis=plans.find(p=>p.planType==='standard'),temporary=plans.filter(p=>p.planType==='temporary');
  const edit=canEditFeeding(state,h),button=(p,label)=>edit?`<button class="feeding-edit" data-action="backend-feed-plan" data-horse="${ctx.esc(h.id)}" data-plan="${ctx.esc(p?.planId||'')}" data-plan-type="${p?.planType||'standard'}">${ctx.icon('edit',16)} ${label}</button>`:'';
  return `<section class="section"><div class="section-heading"><h2>Basisvoeding</h2>${button(basis,basis?'Aanpassen':'Vastleggen')}</div>${basis?`<p class="horse-muted">${feed.planId===basis.planId?'Geldt vandaag.':'Bewaard als vaste basis.'} Vanaf ${displayDate(basis.effectiveFrom)}${basis.effectiveUntil?` tot en met ${displayDate(basis.effectiveUntil)}`:''}.</p>${feed.planId!==basis.planId?`<div class="feeding-meal-grid">${basis.meals.map(m=>mealBlock(m,ctx)).join('')}</div>`:''}`:'<p>Leg eerst de basisvoeding vast. Daarna kun je een tijdelijk schema toevoegen.</p>'}</section>
  <section class="section"><div class="section-heading"><h2>Tijdelijke schema’s</h2>${edit&&basis?.planStatus==='active'?`<button class="feeding-edit" data-action="backend-feed-plan" data-horse="${ctx.esc(h.id)}" data-plan-type="temporary">${ctx.icon('plus',16)} Toevoegen</button>`:''}</div><p class="horse-muted">Een tijdelijk schema vervangt de volledige basisvoeding binnen de gekozen periode. Daarna wordt de basis hervat.</p>${temporary.map(p=>`<section class="feeding-meal"><header><div><h3>${displayDate(p.effectiveFrom)} – ${displayDate(p.effectiveUntil)}</h3><span>${feed.planId===p.planId?'Geldt vandaag':p.effectiveUntil<state.today?'Afgelopen':p.effectiveFrom>state.today?'Gepland':'Bewaard'}</span></div>${button(p,'Bekijken en aanpassen')}</header>${feed.planId!==p.planId?`<div class="feeding-meal-grid">${p.meals.map(m=>mealBlock(m,ctx)).join('')}</div>`:''}</section>`).join('')||'<p class="feeding-no-gift">Er is geen tijdelijk schema vastgelegd.</p>'}</section>`;
}

export function renderHorseFeeding(state, ctx) {
  state = getVisibleState(state);
  const h = state.horseId ? state.horses.find(horse => horse.id === state.horseId) : state.horses[0];
  if (!h) return renderHorseHeader(state, ctx);
  const feed = state.feeding[h.id];
  return `<section class="horse-page">${renderHorseHeader(state, ctx)}${renderHorseTabs(state, ctx)}
    <div class="feeding-heading"><div><p class="horse-eyebrow">Goed zorgen begint hier</p><h2>Het voerplan van ${ctx.esc(h.name)}</h2></div>${canEditFeeding(state, h) ? `<button class="feeding-edit" data-action="edit-feeding" data-horse="${ctx.esc(h.id)}">${ctx.icon('edit', 17)} <span>Bewerken</span></button>` : '<span class="feeding-readonly">Voerinstructies</span>'}</div>
    ${feed ? `${feedStatus(feed, ctx)}<div class="feeding-meal-grid">${feed.meals.map(meal => mealBlock(meal, ctx)).join('')}</div>${feed.note ? `<aside class="feeding-note">${ctx.icon('info', 20)}<div><h3>Goed om te weten</h3><p>${ctx.esc(feed.note)}</p></div></aside>` : ''}` : '<div class="feeding-note"><p>Geef de dag structuur met een voerplan.</p></div>'}${planLibrary(state,h,feed,ctx)}
  </section>`;
}

export function renderStableFeeding(state, ctx) {
  state = getActiveStableView(getVisibleState(state));
  const mealNames = ['Ochtend', 'Middag', 'Avond'];
  const stable = (state.backend?.connected&&state.backend.organizationId?state.stableName:null) || state.stable?.name || state.horses[0]?.stable || 'De stal';
  return `<section class="feeding-stable-page"><div class="feeding-heading"><div><p class="horse-eyebrow">${ctx.esc(stable)}</p><h1>Voeding op stal</h1><p class="feeding-intro">Een helder overzicht. Voor ieder paard, op ieder moment.</p></div></div>
    <div class="feeding-stable-rhythm">${ctx.icon('feed', 20)}<span>${state.horses.length} ${state.horses.length === 1 ? 'paard' : 'paarden'} <span aria-hidden="true">·</span> Ochtend, middag en avond</span></div>
    ${state.horses.length ? `<div class="feeding-stable-grid">${mealNames.map(name => `<section class="feeding-stable-meal"><header><div class="feeding-meal-icon">${ctx.icon(mealIcon(name), 24)}</div><div><h2>${name}</h2><span>${ctx.esc(state.feeding[state.horses[0]?.id]?.meals.find(meal => meal.name === name)?.time || '')}</span></div></header>
      ${state.horses.map(h => {
        const feed = state.feeding[h.id];
        const meal = feed?.meals.find(item => item.name === name);
        return `<article class="feeding-horse"><button class="feeding-horse-title" data-action="navigate" data-route="horse-feeding" data-horse="${ctx.esc(h.id)}"><img src="${ctx.esc(h.image)}" alt=""><span><strong>${ctx.esc(h.name)}</strong><span>${ctx.esc(feed?.status || 'Voerplan bekijken')}</span></span>${ctx.icon('chevron-right', 18)}</button>
          ${meal?.items.length ? `<ul class="feeding-items">${meal.items.map(item => feedItem(item, ctx)).join('')}</ul>` : '<p class="feeding-no-gift">Geen producten vastgelegd voor dit dagdeel.</p>'}
          ${feed?.note ? `<p class="feeding-stable-plan-note">${ctx.icon('info', 14)}<span>${ctx.esc(feed.note)}</span></p>` : ''}
        </article>`;
      }).join('')}
    </section>`).join('')}</div>` : '<div class="feeding-note"><p>Er staan nog geen voerinstructies voor jouw paarden in dit overzicht.</p></div>'}
  </section>`;
}
