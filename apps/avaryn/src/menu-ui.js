import {PRODUCT} from './product-config.js';
import { MENU_GROUPS, PLAN_DEFINITIONS, SUBSCRIPTION_ROWS } from './product-structure.js';
import { getPersona, canManage, canCreateTask, canPlan, canShareMoment } from './horse-access.js';

import {getProfileQuickActions,getPreferredMenuIds,roleProfileLabels} from './role-profile.js';

const privacyCopy = 'Vrienden zien alleen wat jij deelt. Stalrechten blijven apart.';
const soonFeatures = {
  'new-horse': { label: 'Paard toevoegen', icon: 'horse', description: 'Een eigen plek voor een nieuw paard, met de mensen die erbij horen.', comingDescription: 'Paarden toevoegen is nog niet beschikbaar in deze preview. Je kunt de bestaande paarden en hun schermen wel bekijken.' },
  'share-moment': { label: 'Moment delen', icon: 'heart', description: 'Leg je training, buitenrit of verzorgmoment vast.', comingDescription: 'Een moment vastleggen en zelf kiezen met wie je het deelt, komt later. Deze preview slaat geen berichten of foto’s op en deelt niets met anderen.' },
  'quick-note': { label: 'Notitie toevoegen', icon: 'edit', description: 'Bewaar wat je opvalt tijdens het rijden of verzorgen.', comingDescription: 'Een losse notitie toevoegen komt later. Je kunt nu al de bestaande instructies bij afspraken en taken bekijken.' },
  'team-invite': { label: 'Teamlid uitnodigen', icon: 'users', description: 'Samen voor je paarden zorgen.', comingDescription: 'Uitnodigingen versturen komt later. In deze preview wordt niemand uitgenodigd en krijgt niemand nieuwe toegang.' },
  'health-note': { label: 'Gezondheid noteren', icon: 'heart', description: 'Een rustige plek voor observaties en verzorging.', comingDescription: 'Gezondheidsnotities krijgen later een eigen plek, met duidelijke toegang voor betrokkenen. Deze preview bewaart geen gezondheidsgegevens.' },
  competition: { label: 'Wedstrijd toevoegen', icon: 'trophy', description: 'Werk toe naar jullie volgende start.', comingDescription: 'Een wedstrijd met bijbehorende voorbereiding en resultaten komt later. Een gewone afspraak kun je al in de planning zetten.' },
  document: { label: 'Document toevoegen', icon: 'edit', description: 'Belangrijke papieren bij je paard bewaren.', comingDescription: 'Documenten uploaden en veilig bewaren komt later. Deze preview uploadt of bewaart geen bestanden.' },
};

function badge(plan, ctx) {
  return plan ? `<span class="menu-plan-badge">${ctx.esc(plan)}</span>` : '';
}

function menuItem(item, ctx, state) {
  if(state.backend?.p2?.connected&&item.status==='Prototype'&&item.target?.kind==='navigate'&&['facilities','pastures','stalls','facility-planning','arena-planning','function-profile'].includes(item.target.value))item={...item,status:''};
  if(state.backend?.connected){
    const descriptions={'pastures':'Bekijk en plan de paarden op de weides.','facilities':'Bekijk de voorzieningen van jouw stal.','boxes':'Bekijk en wijzig de stalplaatsen binnen jouw toegang.','pasture-facilities':'Bekijk de weides, hun status en planning.','paddocks':'Bekijk de paddocks en hun status.','arenas':'Bekijk rijbakplanning, capaciteit en aanvragen.','walker':'Bekijk de stapmolens, plaatsen en planning.','wash':'Bekijk wasplaatsen en hun beschikbaarheid.','locker':'Bekijk de zadelkamer en beschikbare kasten.','facility-planning':'Plan en wijzig faciliteitenmomenten.','vitality-focus':'Bewaar een persoonlijk aandachtspunt voor je volgende rit.','vitality-warmup':'Een algemene voorbereiding van 5 of 10 minuten.'};
    if(descriptions[item.id])item={...item,description:descriptions[item.id]};
    if(item.target?.kind==='vitality'&&item.status==='Prototype')item={...item,status:''};
  }
  const coming = item.target?.kind === 'coming';
  return `<button class="menu-item" data-action="menu-item" data-id="${ctx.esc(item.id)}">
    <span class="menu-item-icon">${ctx.icon(item.icon || 'leaf', 21)}</span>
    <span class="menu-item-copy"><span class="menu-item-name">${ctx.esc(item.label)}</span><span class="menu-item-description">${ctx.esc(item.description)}</span><span class="menu-item-badges">${badge(item.plan, ctx)}${coming ? '<span class="menu-soon">Binnenkort</span>' : (item.status||item.id==='moments')?`<span class="menu-soon">${ctx.esc(item.status||'Prototype')}</span>`:''}</span></span>
    <span class="menu-item-arrow">${ctx.icon('chevron-right', 16)}</span>
  </button>`;
}

export function renderMenu(state, ctx) {
  const persona = getPersona(state);
  const all=state.menuMode==='all', preferred=new Set(getPreferredMenuIds(state));
  const groups=MENU_GROUPS.map(g=>({...g,items:all?g.items:g.items.filter(i=>preferred.has(i.id))})).filter(g=>g.items.length);
  return `<div class="menu-content">
    <div class="menu-welcome"><span class="menu-welcome-mark">${ctx.icon('horse', 29)}</span><div><h3>Je paarden dichtbij.<br>Rust in je dag.</h3><p>Jouw dag met paarden, op één plek.</p></div></div>
    <div class="menu-personal-head"><div class="menu-view-switch" role="group" aria-label="Menuweergave"><button data-action="menu-mode" data-mode="personal" aria-pressed="${!all}">Voor mij</button><button data-action="menu-mode" data-mode="all" aria-pressed="${all}">Alles</button></div><button class="text-link" data-action="navigate" data-route="function-profile">Mijn functieprofiel ${ctx.icon('arrow-right',14)}</button></div>
    <p class="menu-profile-context">${all?'Alle mogelijkheden, rustig bij elkaar.':`Afgestemd op ${ctx.esc(roleProfileLabels(state).join(' · '))}.`}</p>
    <div class="menu-groups">${groups.map(group => `<details class="menu-group">
      <summary><span class="menu-group-icon">${ctx.icon(group.icon || 'leaf', 20)}</span><span><strong>${ctx.esc(group.label)}</strong><small>${ctx.esc(group.description)}</small></span>${ctx.icon('chevron-down', 16)}</summary>
      <div class="menu-group-items">${group.items.map(item => menuItem(item.id==='tasks'&&!canManage(state)?{...item,plan:'Gratis'}:item, ctx, state)).join('')}</div>${group.privacyCopy?`<p class="menu-proposal-note">${ctx.esc(group.privacyCopy)} ${state.backend?.connected?'Persoonlijk bewaard bij je account; delen is nog niet beschikbaar.':'Alleen een persoonlijk deelvoorbeeld; delen gebeurt hier niet.'}</p>`:''}
    </details>`).join('')}</div>
    <p class="menu-proposal-note">Abonnementslabels zijn een voorstel. Ze beperken deze preview niet. Binnenkort betekent dat de functie nog niet beschikbaar is.</p>
    <footer class="menu-account"><button class="menu-profile" data-action="profile"><span class="menu-avatar">${ctx.esc(persona.initials)}</span><span><strong>${ctx.esc(persona.name)}</strong><small>${ctx.esc(persona.roleLabel)}</small></span>${ctx.icon('chevron-right', 16)}</button><button class="menu-plans-link" data-action="navigate" data-route="plans">Bekijk de abonnementen ${ctx.icon('arrow-right', 16)}</button></footer>
  </div>`;
}

function quickButton(action, label, description, iconName, ctx, { coming = false, status = '', route = '', feature = '', type = '', section = '', secondary = false } = {}) {
  return `<button class="menu-quick-action${secondary ? ' menu-quick-secondary' : ''}" data-action="${action}"${route ? ` data-route="${route}"` : ''}${feature ? ` data-feature="${feature}"` : ''}${type ? ` data-type="${ctx.esc(type)}"` : ''}${section ? ` data-section="${ctx.esc(section)}"` : ''}>
    <span class="menu-quick-icon">${ctx.icon(iconName, secondary ? 19 : 23)}</span><span class="menu-quick-copy"><strong>${ctx.esc(label)}</strong>${description ? `<small>${ctx.esc(description)}</small>` : ''}${coming ? '<span class="menu-soon">Binnenkort</span>' : status ? `<span class="menu-soon">${ctx.esc(status)}</span>` : ''}</span>${ctx.icon('chevron-right', 16)}
  </button>`;
}

export function renderQuickActions(state, ctx) {
  const actions=getProfileQuickActions(state), vitality=actions.filter(a=>a.group==='rider-vitality'), primary=actions.filter(a=>!a.coming&&a.group!=='rider-vitality'), later=actions.filter(a=>a.coming);
  const button=(a,secondary=false)=>quickButton(a.action,a.label,a.description,a.icon,ctx,{coming:a.coming,status:a.status,route:a.route,feature:a.feature,type:a.type,section:a.section,secondary});
  return `<div class="menu-quick-content"><p class="menu-quick-intro">Voor ${ctx.esc(roleProfileLabels(state).join(' · '))}. Wat wil je vandaag doen?</p><div class="menu-quick-primary">${primary.map(a=>button(a)).join('')}</div>${vitality.length?`<details class="menu-group"><summary><span class="menu-group-icon">${ctx.icon('heart',20)}</span><span><strong>Ruiter & fitheid</strong><small>Persoonlijke voorbereiding en terugblik${state.backend?.connected?'':' · Prototype'}</small></span>${ctx.icon('chevron-down',16)}</summary><div class="menu-quick-primary">${vitality.map(a=>button(a)).join('')}</div><p class="menu-proposal-note">Jouw ruitergegevens zijn persoonlijk. Deel alleen wat jij kiest. Dit deelvoorbeeld verstuurt niets.</p></details>`:''}${later.length?`<section class="menu-quick-later"><h3>In voorbereiding</h3><div>${later.map(a=>button(a,true)).join('')}</div></section>`:''}<button class="menu-inline-link" data-action="navigate" data-route="function-profile">${ctx.icon('roles',18)} Mijn functieprofiel aanpassen</button></div>`;
}

function momentImages(state, ctx, className) {
  const ids = getPersona(state).accessibleHorseIds;
  return `<div class="${className}">${state.horses.filter(horse => ids.includes(horse.id)).slice(0, 2).map(horse => `<img src="${ctx.esc(horse.image)}" alt="${ctx.esc(horse.name)}" loading="lazy">`).join('')}</div>`;
}

export function renderMomentCard(state, ctx) {
  return `<article class="menu-moment-card">${momentImages(state, ctx, 'menu-moment-card-images')}<div class="menu-moment-card-copy"><span class="menu-moment-eyebrow">Samen beleven</span><h3>Deel je moment</h3><p>Training, buitenrit of verzorgmoment vastleggen.</p><button data-action="navigate" data-route="moments">Ontdek Momenten ${ctx.icon('arrow-right', 16)}</button><span class="menu-soon">Binnenkort</span></div></article>`;
}

export function renderMoments(state, ctx) {
  const share = canShareMoment(state);
  return `<section class="menu-moments-page"><header class="menu-page-heading"><p class="menu-moment-eyebrow">Samen beleven</p><h1>De kleine momenten.<br>Het grote plezier.</h1><p>Van een fijne training tot een rustige avond op stal. Een plek voor wat jij en je paard samen meemaken.</p></header>
    <div class="menu-moments-hero">${momentImages(state, ctx, 'menu-moments-images')}<div class="menu-moments-invitation"><span class="menu-soon">Binnenkort</span><h2>Jullie verhaal,<br>op jouw manier.</h2><p>Momenten brengt later paardmomenten, vrienden en gedeelde stalupdates bij elkaar. ${PRODUCT.demo?'Hieronder zie je hoe dat kan voelen, met fictieve voorbeeldmomenten.':''} Je kunt nog niets plaatsen of verbinden.</p>${share ? `<button class="menu-solid-button" data-action="share-moment">${ctx.icon('heart', 18)} Moment delen <span>· Binnenkort</span></button>` : '<p class="menu-moments-permission">Momenten delen is voor jouw huidige rol nog niet beschikbaar.</p>'}</div></div>
    <section class="moment-examples"><div class="section-heading"><div><p class="eyebrow">Een eerste indruk</p><h2>Momenten om te bewaren</h2></div><span class="menu-soon">Voorbeelden</span></div><div class="moment-example-grid">${(PRODUCT.demo?[
      {name:'Emma',title:'Emma deelde een training met Orion',copy:'Een fijne training samen. Soms zit de vooruitgang in een klein moment.',horse:state.horses.find(h=>h.id==='orion')||state.horses[0],kind:'Training'},
      {name:'Noor',title:'Noor plaatste een verzorgmoment',copy:'Nog even borstelen en rustig afsluiten. Tijd en aandacht maken het verschil.',horse:state.horses[0],kind:'Verzorging'},
    ]:[]).filter(a=>a.horse).map(a=>`<article class="moment-example"><img src="${ctx.esc(a.horse.image)}" alt="Paard bij een fictief ${ctx.esc(a.kind.toLowerCase())}moment"><div><span class="menu-moment-eyebrow">${ctx.esc(a.kind)} · voorbeeld</span><h3>${ctx.esc(a.title.replace('Orion',a.horse.name))}</h3><p>${ctx.esc(a.copy)}</p><span class="moment-example-foot">${ctx.icon('heart',16)} Alleen een indruk van de vormgeving</span></div></article>`).join('')}</div></section>
    <aside class="menu-privacy">${ctx.icon('heart', 23)}<div><h2>Jij kiest wat dichtbij komt.</h2><p>${privacyCopy}</p><small>Dit is de privacyrichting voor later. Vrienden krijgen daarmee geen toegang tot voeding, gezondheid, locatie, taken of beheer.</small></div></aside>
    <button class="menu-inline-link" data-action="navigate" data-route="today">${ctx.icon('arrow-left', 16)} Terug naar Vandaag</button>
  </section>`;
}

export function renderPlans(state, ctx) {
  return `<section class="menu-plans-page"><header class="menu-page-heading"><p class="menu-moment-eyebrow">Ruimte om te groeien</p><h1>Voor jouw leven<br>met paarden.</h1><p>Een eerste indeling: van je eigen paard tot samen zorgen op stal.</p></header>
    <div class="menu-plan-disclaimer">${ctx.icon('info', 20)}<p>Productvoorstel — geen prijzen, betalingen of blokkades in deze preview. Een abonnementslabel zegt niets over beschikbaarheid.</p></div>
    <div class="menu-plan-grid">${PLAN_DEFINITIONS.map(plan => `<article class="menu-plan-card"><span class="menu-plan-tier">${ctx.esc(plan.badge || 'Voorstel')}</span><h2>${ctx.esc(plan.name)}</h2><p class="menu-plan-tagline">${ctx.esc(plan.tagline)}</p><p>${ctx.esc(plan.description)}</p></article>`).join('')}</div>
    <details class="menu-plan-comparison"><summary><span><strong>Vergelijk de voorgestelde functies</strong><small>Gratis, Plus, Pro, Business en later</small></span>${ctx.icon('chevron-down', 19)}</summary><p class="menu-table-hint">Op een klein scherm kun je de tabel opzij schuiven.</p><div class="menu-table-scroll" tabindex="0" role="region" aria-label="Voorgestelde abonnementsmatrix, horizontaal scrollbaar"><table><caption>Conceptindeling; geen huidige toegangseisen of betaalgrenzen.</caption><thead><tr><th scope="col">Functie</th><th scope="col">Free / Starter</th><th scope="col">Rider Plus</th><th scope="col">Stable Pro</th><th scope="col">Business / Elite</th><th scope="col">Later / Partner</th><th scope="col">Reden</th></tr></thead><tbody>${SUBSCRIPTION_ROWS.map(row => `<tr><th scope="row">${ctx.esc(row.feature)}</th>${['free', 'plus', 'pro', 'business', 'partner', 'reason'].map(key => `<td>${ctx.esc(row[key])}</td>`).join('')}</tr>`).join('')}</tbody></table></div></details>
    <aside class="menu-privacy">${ctx.icon('heart',23)}<div><h2>Ruitergegevens blijven persoonlijk.</h2><p>Jouw ruitergegevens zijn persoonlijk. Deel alleen wat jij kiest. Stal- en teamabonnementen geven geen toegang tot je warming-ups, gevoelens of trainingsnotities.</p><small>Oefeningen en routines vormen een prototypebasis. Echte video’s, uitgebreide trainingshistorie en personalisatie volgen later; teamprogramma’s vragen afzonderlijke toestemming.</small></div></aside>
    <aside class="menu-plan-community">${ctx.icon('heart', 23)}<div><h2>Verbonden zijn begint laagdrempelig.</h2><p>Basisvrienden en momenten blijven in het voorstel deels gratis. Samenwerken op stal hoort bij teamfuncties; toegang tot je paarden staat daar los van.</p></div></aside>
    <button class="menu-inline-link" data-action="navigate" data-route="today">${ctx.icon('arrow-left', 16)} Terug naar Vandaag</button></section>`;
}

export function renderComingSoon(item, ctx) {
  const lookup = typeof item === 'string' ? item : item?.id;
  const menuEntry = MENU_GROUPS.flatMap(group => group.items).find(entry => entry.id === lookup);
  const feature = typeof item === 'object' && item ? item : menuEntry || soonFeatures[lookup] || { label: 'Deze functie', icon: 'leaf' };
  const description = feature.comingDescription || feature.description || 'Deze functie krijgt later een eigen plek in AVARYN.';
  return `<div class="menu-coming"><span class="menu-coming-icon">${ctx.icon(feature.icon || 'leaf', 30)}</span><p>${ctx.esc(description)}</p><p class="menu-coming-honesty">Nog niet beschikbaar in deze preview.</p>${['share-moment', 'moments', 'friends'].includes(lookup) ? `<p class="menu-coming-privacy">${privacyCopy}</p>` : ''}<button class="menu-solid-button" data-action="close-modal">Verder kijken ${ctx.icon('arrow-right', 16)}</button></div>`;
}
