import {browserDay,dashboardClock} from './browser-clock.js';
import {PRODUCT} from './product-config.js';
import {initializePlatform} from './platform.js';
import {createHorseProfile} from './horse-profile.js';
import {createAccountLifecycle} from './account-lifecycle.js';
import {createVitalityController} from './vitality.js';
import {createVitalityBackend} from './vitality-backend.js';
import {renderTaskForm,updateTaskTiming} from './task-form.js';
import {taskToday,taskWhenLabel,taskFormValues} from './task-timing.js';
import {retireLegacyPreviewCache} from './cache-refresh.js';
import {createConnectedP2Controller} from './connected-p2-controller.js';
import {createBackendController} from './backend-controller.js';
import {prototypeNotice,backendNotice} from './backend-ui.js';
import {renderArenaPlanning,createArenaController} from './arena.js';
import {INITIAL_STATE} from './data.js';
import {icon,esc,createContext} from './components.js';
import {renderPlanning} from './planning.js';
import {renderTasks} from './tasks.js';
import {renderHorses,renderHorseOverview,renderHorseHeader,renderHorseTabs} from './horses.js';
import {renderHorseFeeding,renderStableFeeding} from './feeding.js';
import {renderToday,renderStable} from './daily-ui.js';
import {PERSONAS,getPersona,getVisibleState,visibleHorseIds,canManage,canViewTeam,canEditFeeding,canCreateTask,canPlan,canShareMoment} from './horse-access.js';
import {initFacilities,renderFacilities,renderPastures,renderStalls,renderFacilityPlanning,createFacilityController} from './facilities.js';
import {ROLE_FUNCTIONS,getFunctions,roleProfileLabels,renderRoleProfile} from './role-profile.js';
import {MENU_GROUPS} from './product-structure.js';
import {renderMenu,renderQuickActions,renderMoments,renderPlans,renderComingSoon} from './menu-ui.js';

const VERSION=PRODUCT.candidate;
const platform=await initializePlatform().catch(()=>({blocked:{message:'Deze app kon de beveiligde sessie niet openen. Sluit de app en probeer opnieuw.'}}));
if(platform.blocked){document.querySelector('#app').innerHTML=`<div class="access-page"><section class="access-card"><span class="wordmark">AVARYN</span><h1>Verbinding voorbereiden</h1><p>${esc(platform.blocked.message)}</p></section></div>`;}else{
const STORAGE='avaryn-v8-connected-demo-v1';
const clone=value=>JSON.parse(JSON.stringify(value));
let state=clone(INITIAL_STATE);
let backendController=null,p2Controller=null,vitalityController=null,horseProfile=null,accountLifecycle=null;
if(PRODUCT.demo)try{const stored=JSON.parse(localStorage.getItem(STORAGE)||'null');if(stored?.schema===1&&Array.isArray(stored.data?.tasks)&&Array.isArray(stored.data?.horses))state={...state,...stored.data};}catch{}
if(!PERSONAS[state.persona])state.persona=PRODUCT.demo?'manager':null;
initFacilities(state);
const modal=document.querySelector('#modal');
const viewState=()=>getVisibleState(state);
const routeNames={today:'Vandaag',horses:'Paarden','horse-overview':'Overzicht','horse-planning':'Planning','horse-feeding':'Voeding',planning:'Planning',stable:'Stal',tasks:'Taken','stable-feed':'Stalvoeding',moments:'Momenten',plans:'Abonnementen',facilities:'Faciliteiten',pastures:'Weideplanning',stalls:'Stalplaatsen','facility-planning':'Faciliteitenplanning','arena-planning':'Rijbakplanning','function-profile':'Mijn functieprofiel'};
const paths={today:'vandaag',horses:'paarden',planning:'planning',stable:'stal',tasks:'taken','stable-feed':'stal/voeding',moments:'momenten',plans:'abonnementen',facilities:'faciliteiten',pastures:'weideplanning',stalls:'stalplaatsen','facility-planning':'faciliteitenplanning','arena-planning':'rijbakplanning','function-profile':'functieprofiel'};
const dateText=(date,options={weekday:'long',day:'numeric',month:'long'})=>new Date(`${date}T12:00:00Z`).toLocaleDateString('nl-NL',{...options,timeZone:'UTC'});
const openTasks=()=>viewState().tasks.filter(t=>!['done','completed'].includes(t.status));
const save=()=>{if(state.backend?.connected){backendController?.saveLocal();return;}try{localStorage.setItem(STORAGE,JSON.stringify({schema:1,data:state}));}catch{}};
function parseHash(){
  const p=location.hash.replace(/^#\/?/,'').split('/');
  if(p[0]==='paard'&&visibleHorseIds(state).includes(p[1])){state.horseId=p[1];state.route={'overzicht':'horse-overview','planning':'horse-planning','voeding':'horse-feeding'}[p[2]]||'horse-overview';}
  else state.route=p[0]==='paard'?'horses':Object.keys(paths).find(k=>paths[k]===p.join('/'))||'today';
}
function navigate(route,horseId){
  if(!routeNames[route])return;
  horseProfile?.cancelOpen();
  if(horseId&&!visibleHorseIds(state).includes(horseId))return unavailable('horse-access');
  if(horseId)state.horseId=horseId;
  if(!visibleHorseIds(state).includes(state.horseId))state.horseId=visibleHorseIds(state)[0];
  state.route=route;
  if(route==='planning'&&state.period==='today'&&state.selectedDay!==taskToday(state))state.period='week';
  const dest=route.startsWith('horse-')?`paard/${state.horseId}/${{'horse-overview':'overzicht','horse-planning':'planning','horse-feeding':'voeding'}[route]}`:paths[route];
  if(modal.open)modal.close();
  if(history.state?.sheet)history.replaceState(null,'','#/'+dest);else history.pushState(null,'','#/'+dest);
  if(state.backend?.connected&&['today','stable'].includes(route)&&state.selectedDay!==state.today){state.selectedDay=state.today;backendController.reload();}else render();window.scrollTo(0,0);save();
}
function toast(message){const el=document.querySelector('#toast');el.textContent=message;el.classList.add('show');clearTimeout(toast.timer);toast.timer=setTimeout(()=>el.classList.remove('show'),2800);}
function navButton(route,label,ic,desktop=false){
  const active=route==='horses'?state.route==='horses'||state.route.startsWith('horse-'):route==='stable'?['stable','stable-feed','facilities','pastures','stalls','facility-planning','arena-planning'].includes(state.route):state.route===route;
  return `<button class="${desktop?'nav-link':'bottom-link'} ${active?'is-active':''}" data-action="navigate" data-route="${route}"${active?' aria-current="page"':''}>${icon(ic,21)}<span>${label}</span></button>`;
}
function shell(content,view){const person=getPersona(state);return `<div class="app-layout"><aside class="sidebar"><div><a class="wordmark" href="#/vandaag">AVARYN</a><p class="brand-tagline">JE PAARDEN DICHTBIJ.</p></div><nav class="sidebar-nav" aria-label="Hoofdnavigatie">${navButton('today','Vandaag','today',true)}${navButton('horses','Paarden','horse',true)}${navButton('planning','Planning','calendar',true)}${navButton('stable','Stal','stable',true)}</nav><button class="sidebar-add button-primary" data-action="quick-actions">${icon('plus',19)} Iets toevoegen</button><button class="nav-link sidebar-menu" data-action="open-menu">${icon('menu',20)} Alle mogelijkheden</button><div class="sidebar-bottom"><button class="sidebar-person" data-action="profile"><span class="profile-avatar">${esc(person.initials)}</span><span><strong>${esc(person.name)}</strong><small>${esc(person.roleLabel)}</small></span></button></div></aside><div class="app-main"><header class="topbar"><div class="brand-tools"><button class="icon-button menu-trigger" data-action="open-menu" aria-label="Menu openen">${icon('menu',19)}</button><a class="wordmark mobile-brand" href="#/vandaag">AVARYN</a><div class="breadcrumbs">${esc(view.stableName)} ${icon('chevron-right',12)} <b>${routeNames[state.route]}</b></div></div><div class="top-actions"><button class="icon-button" data-action="toggle-theme" aria-label="${state.theme==='dark'?'Lichte modus':'Donkere modus'}">${icon(state.theme==='dark'?'sun':'moon',17)}</button><button class="profile-avatar" data-action="profile" aria-label="Profiel van ${esc(person.name)}">${esc(person.initials)}</button></div></header><main id="main" class="page" tabindex="-1">${content}</main></div><nav class="bottom-nav" aria-label="Hoofdnavigatie mobiel">${navButton('today','Vandaag','today')}${navButton('horses','Paarden','horse')}<button class="central-plus" data-action="quick-actions" aria-label="Snelle acties openen"><span>${icon('plus',25)}</span></button>${navButton('planning','Planning','calendar')}${navButton('stable','Stal','stable')}</nav></div>`;}
function render(){
  vitalityController?.syncContext();
  accountLifecycle?.syncContext();
  document.documentElement.dataset.theme=state.theme==='dark'?'dark':'light';
  if(accountLifecycle?.isPending()){document.querySelector('#app').innerHTML='<div class="access-loading"><h1>Je verwijderaanvraag wordt afgehandeld.</h1><p>Je gewone accounttoegang is gesloten. Controleer de status om dezelfde aanvraag te vervolgen.</p><button class="button-primary" data-action="account-delete">Verwijderstatus controleren</button><button class="button-secondary" data-action="logout">Uitloggen</button></div>';return;}
  const gate=backendController?.getScreen();if(gate){document.querySelector('#app').innerHTML=gate;return;}
  const view=viewState();if(!view.horses.some(h=>h.id===state.horseId)){state.horseId=view.horses[0]?.id;view.horseId=state.horseId;}
  const ctx=createContext(view);let content='';
  switch(state.route){
    case'today':content=renderToday(view,ctx);break;
    case'horses':content=renderHorses(view,ctx);break;
    case'horse-overview':content=renderHorseOverview(view,ctx);break;
    case'horse-planning':content=renderHorseHeader(view,ctx)+renderHorseTabs(view,ctx)+renderPlanning(view,ctx);break;
    case'horse-feeding':content=renderHorseFeeding(view,ctx);break;
    case'planning':content=renderPlanning(view,ctx);break;
    case'tasks':content=renderTasks(view,ctx);break;
    case'stable':content=renderStable(view,ctx);break;
    case'stable-feed':content=renderStableFeeding(view,ctx);break;
    case'moments':content=renderMoments(view,ctx);break;
    case'plans':content=renderPlans(view,ctx);break;
    case'facilities':content=renderFacilities(view,ctx);break;
    case'pastures':content=renderPastures(view,ctx);break;
    case'stalls':content=renderStalls(view,ctx);break;
    case'facility-planning':content=renderFacilityPlanning(view,ctx);break;
    case'arena-planning':content=renderArenaPlanning(view,ctx);break;
    case'function-profile':content=renderRoleProfile(view,ctx);break;
    default:content=renderToday(view,ctx);
  }
  if(state.backend?.connected){if(!state.backend.p2?.connected&&['facilities','pastures','stalls','facility-planning','arena-planning','function-profile'].includes(state.route))content=prototypeNotice()+content;else if(['today','stable'].includes(state.route))content=backendNotice(state)+content;}
  document.querySelector('#app').innerHTML=shell(content,view);
  p2Controller?.capture(document.querySelector('#role-profile-form'));
  document.title=`${routeNames[state.route]} · AVARYN`;
}
function showModal(title,body,footer='',kicker='',variant=''){
  const wasOpen=modal.open;modal.dataset.viewId=crypto.randomUUID();modal.className=variant;
  modal.innerHTML=`<div class="modal-inner"><header class="modal-heading"><div>${kicker?`<p class="modal-kicker">${esc(kicker)}</p>`:''}<h2 id="modal-title">${esc(title)}</h2></div><button type="button" class="icon-button" data-action="close-modal" aria-label="Sluiten">${icon('close',16)}</button></header>${body}${footer?`<footer class="modal-footer">${footer}</footer>`:''}</div>`;
  p2Controller?.capture(modal.querySelector('form'));
  const horseForm=modal.querySelector('form');if(horseForm)horseProfile?.capture(horseForm);
  if(!wasOpen){history.pushState({sheet:true},'');modal.showModal();}modal.scrollTop=0;
}
function closeModal(){horseProfile?.cancelOpen();if(modal.open)modal.close();if(history.state?.sheet)history.back();}
function openMenu(){const view=viewState();showModal('Jouw AVARYN',renderMenu(view,createContext(view)),'','Alles op één plek','menu-sheet');}
function openQuickActions(){const view=viewState();showModal('Wat wil je doen?',renderQuickActions(view,createContext(view)),'','Dicht bij je dag','quick-sheet');}
const extraFeatures={
 'treatment-note':{label:'Notitie na behandeling',description:'Een plek voor observaties en afgesproken opvolging. Dit is een visueel voorstel; deze preview bewaart geen behandelnotities en geeft geen medisch advies.'},
 'advice-note':{label:'Adviesnotitie',description:'Leg hier later afgesproken voerinstructies vast voor de mensen die ze mogen lezen. Deze preview maakt geen voedingsadvies en bewaart geen adviesnotities.'},
 'progress':{label:'Voortgang bekijken',description:'Voortgang van ruiter en paard krijgt later een eigen overzicht. Er is hier geen behandeling, diagnose of beoordeling van fitheid.'},
 'new-horse':{label:'Paard toevoegen',description:'Hier voeg je straks een paard toe en leg je vast wie het mag zien. In deze preview kun je de bestaande paarden bekijken; er wordt nog geen nieuw paard aangemaakt.'},
 'share-moment':{label:'Moment delen',description:'Leg straks een training, buitenrit of verzorgmoment vast en kies zelf met wie je het deelt. In deze preview kun je nog niets plaatsen. Vrienden zien alleen wat jij deelt. Stalrechten blijven apart.'},
 'team-invite':{label:'Teamlid uitnodigen',description:'Hier nodig je straks iemand uit voor een afgebakende rol op stal. De preview verstuurt geen uitnodigingen en verandert geen toegang.'},
 'quick-note':{label:'Notitie toevoegen',description:'Hier bewaar je straks een losse trainingsnotitie bij een paard. Bij een geplande activiteit kun je nu al een notitie invullen in deze lokale preview.'},
 'health-note':{label:'Gezondheid noteren',description:'Een eigen plek voor zorgnotities en afgesproken opvolging. Opslag en afzonderlijke toegang tot gezondheidsgegevens worden later aangesloten.'},
 'competition':{label:'Wedstrijd toevoegen',description:'Startgegevens, resultaten en wedstrijdvoorbereiding komen later samen. Een wedstrijdafspraak kun je nu al via Activiteit plannen vastleggen in de lokale agenda.'},
 'document':{label:'Document toevoegen',description:'Bewaar straks documenten bij het juiste paard. De preview uploadt of deelt nog geen bestanden.'},
 'goals':{label:'Samen aan je doelen',description:'Hier volgen doelen voor jouw fitheid, training en de ontwikkeling van je paard. Het doelenlogboek is nog in voorbereiding.'},
 'horse-access':{label:'Dit paard staat niet in jouw overzicht',description:'Deze voorbeeldrol heeft alleen de paarden die bij het dagelijkse werk horen. De overige paarden en hun gegevens worden hier niet getoond.'},
 'feeding-access':{label:'Voerinstructies bekijken',description:'Je kunt de klaargelegde instructies volgen. Het aanpassen van het voerplan hoort bij de eigenaar of stalmanager.'},
 'planning-access':{label:'Je afspraken bekijken',description:'Deze rol bekijkt de toegewezen afspraken. Nieuwe activiteiten plannen hoort bij de eigenaar, trainer of stalmanager.'},
 'task-access':{label:'Je taken uitvoeren',description:'Deze rol kan toegewezen taken lezen en afronden. De eigenaar of stalmanager voegt taken toe.'},
 'team-access':{label:'Het stalteam',description:'Het volledige teamoverzicht en beheer horen bij de stalmanager. Jouw eigen taken en voerinstructies blijven bereikbaar.'},
 'moment-access':{label:'Momenten bekijken',description:'Delen is voor deze voorbeeldrol nog niet ingeschakeld. Toestemming voor momenten blijft apart van toegang tot paarden en stalgegevens.'}
};
function unavailable(id){
 const item=extraFeatures[id]||MENU_GROUPS.flatMap(g=>g.items).find(i=>i.id===id)||{label:'Binnenkort',description:'Deze mogelijkheid wordt later uitgewerkt. In deze preview is ze nog niet gekoppeld.'};
 const roleMessage=id.endsWith('-access');
 showModal(item.label,roleMessage?`<div class="access-explanation"><span class="feed-preview-icon">${icon('shield',25)}</span><p>${esc(item.description)}</p></div>`:renderComingSoon(item,createContext(viewState())),roleMessage?'<button class="button-primary" data-action="close-modal">Verder kijken</button>':'',roleMessage?'Jouw toegang':'Binnenkort','coming-sheet');
}
function openProfile(){const person=getPersona(state);showModal(person.name,`<div class="profile-card"><span class="profile-avatar">${esc(person.initials)}</span><div><strong>${esc(person.roleLabel)}</strong><p>${esc(state.stableName)}</p></div></div><div class="profile-links">${state.backend?.connected?`<button data-action="edit-profile">${icon('edit',19)} Mijn gegevens ${icon('chevron-right',17)}</button>`:''}<button data-action="navigate" data-route="function-profile">${icon('roles',19)} Mijn functieprofiel ${icon('chevron-right',17)}</button><button data-action="navigate" data-route="plans">${icon('sparkles',19)} Abonnementen bekijken ${icon('chevron-right',17)}</button><button data-action="settings">${icon('settings',19)} Instellingen ${icon('chevron-right',17)}</button>${state.backend?.connected?`<button data-action="open-invitation">${icon('users',19)} Uitnodiging openen ${icon('chevron-right',17)}</button><button data-action="switch-stable">${icon('stable',19)} Stal kiezen ${icon('chevron-right',17)}</button><button data-action="authority-transfer">${icon('shield',19)} Hoofdbeheer en overdracht ${icon('chevron-right',17)}</button><button data-action="account-delete">${icon('shield',19)} Account verwijderen ${icon('chevron-right',17)}</button><button data-action="logout">${icon('arrow-right',19)} Uitloggen</button>`:`<button data-action="login-open">${icon('shield',19)} Met testaccount inloggen ${icon('chevron-right',17)}</button>`}</div>`,'','Jouw profiel');}
function showSettings(){showModal('Kies je weergave',`<p class="settings-intro">Een vertrouwde sfeer, op ieder moment van de dag.</p><div class="theme-options"><button class="button-secondary" data-action="set-theme" data-theme="light" aria-pressed="${state.theme!=='dark'}">${icon('sun',20)} Licht</button><button class="button-secondary" data-action="set-theme" data-theme="dark" aria-pressed="${state.theme==='dark'}">${icon('moon',20)} Donker</button></div>`,'','Instellingen');}
function showTeam(){if(!canViewTeam(state))return unavailable('team-access');showModal('Samen op stal',`<div class="team-list">${state.team.map(t=>`<div class="team-person"><span class="profile-avatar">${esc(t.initials)}</span><div><strong>${esc(t.name)}</strong><small>${esc(t.role)}</small></div></div>`).join('')}</div>`,`<button class="button-secondary" data-action="team-invite">${icon('plus',16)} Teamlid uitnodigen <span class="mini-status">Binnenkort</span></button>`,state.stableName);}
function manageStable(){if(!canManage(state))return unavailable('team-access');showModal('Stalgegevens',`<form id="stable-form"><label class="form-field">Naam van de stal<input name="name" value="${esc(state.stableName)}" required></label><label class="form-field">Plaats<input name="location" value="${esc(state.stableLocation)}" required></label><footer class="modal-footer"><button type="button" class="button-secondary" data-action="close-modal">Annuleren</button><button type="submit" class="button-primary">Opslaan</button></footer></form>`,'','Beheer');}
function prototypeInfo(){
 const live=!!state.backend?.connected;
 if(!PRODUCT.demo){showModal('Over AVARYN',`<p>Je paarden, stalwerk en ruiterfitheid op één plek. Je accountgegevens worden bewaard bij je account. Je stalteam ziet alleen waarvoor het toegang heeft.</p><p>Momenten, video’s en abonnementen zijn in voorbereiding. Er zijn geen betalingen of sociale publicaties.</p><p class="preview-version">${esc(VERSION)}</p>`,`<button class="button-primary" data-action="close-modal">Gereed</button>`,'AVARYN pilot');return;}
 showModal('Over deze preview',`<div class="prototype-copy"><p>De warme V8-vormgeving staat vast. Rijbakken, weides en faciliteiten kun je hier uitproberen.</p><p>${live?'Vandaag, paarden, planning, voeding, taken en de stalcontext worden opgehaald uit de bestaande fictieve testomgeving. Opslaan wordt pas bevestigd na een geslaagde serveractie en herlezing. Ook de faciliteiten, stalplaatsen, reserveringen en je functievoorkeuren worden veilig opgeslagen. Je stalteam ziet alleen de gegevens waarvoor het toegang heeft.':'Je bekijkt fictieve voorbeeldgegevens. Aanpassingen blijven alleen in deze browser. Via je testaccount kun je ook de gekoppelde kernflows controleren.'}</p><p>Ruiterfitheid is een persoonlijk prototype: oefeningen, routines, focus en terugblikken blijven alleen in deze browser bij je testaccount. Video’s volgen later. Delen is een voorstel; er wordt niets geplaatst. Momenten, documenten en abonnementen zijn productvoorstellen. Functievoorkeuren geven nooit extra rechten. Voorbeeldvoer is geen voedingsadvies.</p><p class="preview-version">${VERSION}</p></div>${live?'':`<fieldset class="persona-preview"><legend>Bekijk de voorbeeldrol</legend>${Object.values(PERSONAS).map(p=>`<button type="button" data-action="set-persona" data-persona="${p.id}" aria-pressed="${state.persona===p.id}"><strong>${esc(p.roleLabel)}</strong><span>${esc(p.name)}</span></button>`).join('')}</fieldset>`}`,`<button class="button-secondary" data-action="${live?'enter-demo':'reset-demo'}">${live?'Visueel voorbeeld bekijken':'Voorbeeldgegevens herstellen'}</button><button class="button-primary" data-action="${live?'close-modal':'login-open'}">${live?'Verder bekijken':'Met testaccount inloggen'}</button>`,'Productbeoordeling');
}
function openTask(id){
 const view=viewState(),t=view.tasks.find(t=>t.id===id);if(!t)return;
 const h=view.horses.find(h=>h.id===t.horseId),done=['done','completed'].includes(t.status);
 showModal(t.title,horseStamp(h)+`<div class="detail-facts"><div><span>${icon('clock',13)} Wanneer</span>${esc(taskWhenLabel(t,taskToday(state)))}</div><div><span>${icon('location',13)} Waar</span>${esc(t.location)}</div><div><span>${icon('users',13)} Verantwoordelijke</span>${esc(t.assignee)}</div><div><span>Status</span><span class="badge ${done?'success':''}">${done?'Afgerond':'Open'}</span></div></div><div class="instruction-box"><h3>Zo pak je het aan</h3><p>${esc(t.note)}</p></div>`,`${h?`<button class="button-secondary" data-action="task-feeding" data-horse="${h.id}">${icon('feed',16)} Voerinstructies</button>`:''}${(done||(state.backend?.connected&&!t.canComplete))?`<button class="button-primary" data-action="close-modal">${icon('check',17)} Klaar</button>`:`<button class="button-primary" data-action="complete-task" data-id="${t.id}">${icon('check',17)} Taak afronden</button>`}`,'Taakinstructie');
}
function openActivity(id){
 const view=viewState(),a=view.activities.find(a=>a.id===id)||view.backend?.todayItems.find(a=>a.id===id&&a.sourceType==='horse_activity');if(!a)return;
 const h=view.horses.find(h=>h.id===a.horseId),done=['done','completed'].includes(a.status);
 showModal(a.title,horseStamp(h)+`<div class="detail-facts"><div><span>${icon('calendar',13)} Datum</span>${dateText(a.date,{day:'numeric',month:'long'})}</div><div><span>${icon('clock',13)} Tijd</span>${esc(a.time)} – ${esc(a.end)}</div>${a.location?.trim()?`<div><span>${icon('location',13)} Plaats</span>${esc(a.location)}</div>`:''}<div><span>${icon('users',13)} Met</span>${esc(a.person)}</div></div><div class="instruction-box"><h3>Goed om te weten</h3><p>${esc(a.note)}</p></div>`,canPlan(state,a.horseId)?`<button class="button-secondary" data-action="edit-activity" data-id="${a.id}">${icon('edit',15)} Aanpassen</button><button class="button-primary" data-action="${done||(state.backend?.connected&&!a.canComplete)?'close-modal':'complete-activity'}" data-id="${a.id}">${icon('check',17)} ${done?'Afgerond':state.backend?.connected&&!a.canComplete?'Verder kijken':'Afronden'}</button>`:`<button class="button-primary" data-action="close-modal">Verder kijken</button>`,a.type);
}

function horseStamp(h){return h?`<div class="modal-horse"><img src="${h.image}" alt=""><div><strong>${esc(h.name)}</strong><small>${[state.stableName,h.box].filter(value=>String(value||'').trim()).map(esc).join(' · ')}</small></div></div>`:'';}
function horseOptions(id,allowNone=false){return (allowNone?'<option value="">Algemene staltaak</option>':'')+viewState().horses.map(h=>`<option value="${h.id}"${id===h.id?' selected':''}>${esc(h.name)}</option>`).join('');}
function showActivityForm(id,type){if(!canPlan(state))return unavailable("planning-access");const a=state.activities.find(a=>a.id===id)||{horseId:state.horseId,type:type||'Training',title:'',date:state.selectedDay,time:'15:00',end:'16:00',location:'Binnenbak',person:getPersona(state).name,note:''};showModal(id?'Afspraak aanpassen':'Een nieuwe afspraak',`<form id="activity-form" data-edit-id="${esc(id||'')}"><label class="form-field">Paard<select name="horseId">${horseOptions(a.horseId)}</select></label><div class="form-grid"><label class="form-field">Activiteit<select name="type">${['Training','Hoefsmid','Dierenarts','Wedstrijd','Verzorging'].map(t=>`<option${t===a.type?' selected':''}>${t}</option>`).join('')}</select></label><label class="form-field">Datum<input type="date" name="date" value="${a.date}" required></label></div><label class="form-field form-block">Titel<input name="title" value="${esc(a.title)}" placeholder="Bijvoorbeeld dressuurles" required></label><div class="form-grid"><label class="form-field">Van<input type="time" name="time" value="${a.time}" required></label><label class="form-field">Tot<input type="time" name="end" value="${a.end}" required></label></div><div class="form-grid form-block"><label class="form-field">Plaats<input name="location" value="${esc(a.location)}" required></label><label class="form-field">Met<input name="person" value="${esc(a.person)}" required></label></div><label class="form-field form-block">Notitie<textarea name="note" placeholder="Wat is handig om vooraf te weten?">${esc(a.note)}</textarea></label><footer class="modal-footer"><button type="button" class="button-secondary" data-action="close-modal">Annuleren</button><button class="button-primary" type="submit">${icon('check',17)} Afspraak opslaan</button></footer></form>`,'','Planning');}
function showTaskForm(){if(!canCreateTask(state))return unavailable("task-access");showModal('Een nieuwe taak',renderTaskForm(state,{id:'task-form',horseOptions:horseOptions('',true),assigneeName:'assignee',assigneeOptions:(canManage(state)?state.team.slice(0,3):[getPersona(state)]).map(t=>`<option>${esc(t.name)}</option>`).join(''),locations:(state.facilities?.resources||[]).map(r=>r.name)}),'','Stalwerk');}
function feedEditRow(item={product:'',amount:'',note:''}){return `<div class="feed-edit-row" data-feed-row><div class="form-grid"><label class="form-field">Product<input data-field="product" value="${esc(item.product)}" required></label><label class="form-field">Hoeveelheid<input data-field="amount" value="${esc(item.amount)}" placeholder="1 kg" required></label></div><label class="form-field">Notitie<input data-field="note" value="${esc(item.note)}"></label></div>`;}
function editFeeding(id){if(!canEditFeeding(state,id))return unavailable("feeding-access");const h=viewState().horses.find(h=>h.id===id);if(!h)return;showModal(`Voerinstructies ${h.name}`,`<form id="feeding-form" data-horse="${h.id}">${state.feeding[id].meals.map((meal,i)=>`<fieldset class="feed-edit-meal" data-meal-index="${i}"><legend>${meal.name} · ${meal.time}</legend><div class="feed-edit-rows">${meal.items.map(feedEditRow).join('')}</div><button type="button" class="text-link" data-action="add-feed-row" data-meal-index="${i}">${icon('plus',14)} Product toevoegen</button></fieldset>`).join('')}<footer class="modal-footer"><button type="button" class="button-secondary" data-action="close-modal">Annuleren</button><button class="button-primary" type="submit">${icon('check',17)} Instructies opslaan</button></footer></form>`,'','Voeding');}

const vitalityBackend=createVitalityBackend({getState:()=>state,getBackend:()=>backendController});
vitalityController=createVitalityController({remote:vitalityBackend,getState:()=>state,showModal,closeModal,toast,navigate,render});
const facilityController=createFacilityController({getState:()=>state,save,render,navigate,showModal,closeModal,toast});
const arenaController=createArenaController({getState:()=>state,save,render,navigate,showModal,closeModal,toast});
p2Controller=createConnectedP2Controller({getState:()=>state,getBackend:()=>backendController,closeModal,toast});
horseProfile=createHorseProfile({getState:()=>state,getBackend:()=>backendController,showModal,perform:(...args)=>backendController.perform(...args),esc,nativePhoto:platform.horsePhoto});
backendController=createBackendController({clientOptions:{baseUrl:platform.apiBase,storage:platform.storage},purgeMedia:()=>horseProfile.dispose(),clearAuthCallback:()=>platform.clearAuthCallback?.(),augmentLoad:async next=>{
 const fresh=await horseProfile.loadPhotos(await vitalityBackend.load(await p2Controller.load(next)));
 fresh.horses=fresh.horses.map(h=>({...h,image:h.image||'assets/horse-placeholder.svg'}));return fresh;
},getState:()=>state,setState:value=>{state=value;},save,render,navigate,showModal,closeModal,toast,restoreRoute:parseHash});
accountLifecycle=createAccountLifecycle({getState:()=>state,getBackend:()=>backendController,showModal,closeModal,navigate,esc,clearSession:args=>backendController.clearDeletedSession(args),onPending:({isCurrent})=>{if(isCurrent())backendController.suspendAccount();}});
function dispatch(action,button){if(accountLifecycle.isPending()&&!['account-delete','close-modal','logout','toggle-theme'].includes(action))return;if(horseProfile.handleAction(action,button)||accountLifecycle.handleAction(action,button))return;if(vitalityController.handleAction(action,button))return;if(backendController.handleAction(action,button)||p2Controller.handleAction(action,button)||arenaController.handleAction(action,button))return;if(facilityController.handleAction(action,button))return;const id=button.dataset.id;
 switch(action){
  case'navigate':navigate(button.dataset.route,button.dataset.horse);break;
  case'open-menu':openMenu();break;
  case'menu-mode':state.menuMode=button.dataset.mode==='all'?'all':'personal';save();openMenu();break;
  case'quick-actions':openQuickActions();break;
  case'menu-item':{
   const item=MENU_GROUPS.flatMap(g=>g.items).find(i=>i.id===id);if(!item)return;
   if(item.target.kind==='navigate'){if(item.target.filter)state.facilityFilter=item.target.filter;else if(item.target.value==='facilities')state.facilityFilter='all';navigate(item.target.value);}
   else if(item.target.kind==='vitality')vitalityController.handleAction('vitality-open',{dataset:{section:item.target.value}});
   else if(item.target.kind==='existing')dispatch(item.target.value,button);
   else unavailable(item.target.value||item.id);break;
  }
  case'coming':unavailable(button.dataset.feature);break;
  case'new-horse':unavailable('new-horse');break;
  case'share-moment':unavailable(canShareMoment(state)?'share-moment':'moment-access');break;
  case'team-invite':unavailable(canManage(state)?'team-invite':'team-access');break;
  case'quick-note':unavailable('quick-note');break;
  case'open-feeding':navigate('stable-feed');break;
  case'toggle-theme':state.theme=state.theme==='dark'?'light':'dark';save();render();break;
  case'set-theme':state.theme=button.dataset.theme==='dark'?'dark':'light';save();render();showSettings();break;
  case'profile':openProfile();break;
  case'settings':showSettings();break;
  case'prototype-info':prototypeInfo();break;
  case'set-persona':{
    if(!PERSONAS[button.dataset.persona])return;
    state.persona=button.dataset.persona;state.horseId=visibleHorseIds(state)[0];state.horseFilter=['rider','groom'].includes(state.persona)?'assigned':'personal';save();navigate('today');break;
  }
  case'horse-filter':if(['personal','stable','assigned'].includes(button.dataset.filter)){state.horseFilter=button.dataset.filter;save();render();}break;
  case'stable-horses':state.horseFilter='stable';navigate('horses');break;
  case'close-modal':closeModal();break;
  case'open-task':openTask(id);break;
  case'complete-task':{if(!viewState().tasks.some(t=>t.id===id))return;const t=state.tasks.find(t=>t.id===id);t.status='done';save();closeModal();render();toast('Taak afgerond. Fijn, weer iets gedaan.');break;}
  case'task-feeding':navigate('horse-feeding',button.dataset.horse);break;
  case'open-activity':openActivity(id);break;
  case'complete-activity':{if(!canPlan(state)||!viewState().activities.some(a=>a.id===id))return;state.activities.find(a=>a.id===id).status='done';save();closeModal();render();toast('Activiteit afgerond.');break;}
  case'new-activity':showActivityForm(undefined,button.dataset.type);break;
  case'edit-activity':if(viewState().activities.some(a=>a.id===id))showActivityForm(id);break;
  case'new-task':showTaskForm();break;
  case'period':state.period=button.dataset.period;if(state.period==='today')state.selectedDay=state.today||browserDay();save();if(state.backend?.connected)backendController.reload();else render();break;
  case'select-day':state.selectedDay=button.dataset.day;save();if(state.backend?.connected)backendController.reload();else render();break;
  case'shift-date':{const d=new Date(`${state.selectedDay}T12:00:00Z`),delta=Number(button.dataset.direction)||1;if(state.period==='month')d.setUTCMonth(d.getUTCMonth()+delta,1);else d.setUTCDate(d.getUTCDate()+delta*7);state.selectedDay=d.toISOString().slice(0,10);save();if(state.backend?.connected)backendController.reload();else render();break;}
  case'edit-feeding':editFeeding(button.dataset.horse||state.horseId);break;
  case'add-feed-row':button.closest('fieldset[data-meal-index]').querySelector('.feed-edit-rows').insertAdjacentHTML('beforeend',feedEditRow());break;
  case'team':showTeam();break;
  case'manage-stable':manageStable();break;
  case'reset-demo':{const theme=state.theme;state=clone(INITIAL_STATE);initFacilities(state);state.theme=theme;save();navigate('today');toast('De oorspronkelijke voorbeeldgegevens staan terug.');break;}
 }
}
document.addEventListener('click',event=>{const b=event.target.closest('[data-action]');if(!b)return;event.preventDefault();dispatch(b.dataset.action,b);});
document.addEventListener('submit',event=>{if(accountLifecycle.handleSubmit(event.target,event))return;if(accountLifecycle.isPending()){event.preventDefault();return;}if(horseProfile.handleSubmit(event.target,event)||vitalityController.handleSubmit(event.target,event))return;
 const form=event.target;
 if(backendController.handleSubmit(form,event)||p2Controller.handleSubmit(form,event)||arenaController.handleSubmit(form,event)||facilityController.handleSubmit(form,event))return;
 if(form.id==='role-profile-form'){
  event.preventDefault();const chosen=[...new Set(new FormData(form).getAll('functions'))].filter(id=>ROLE_FUNCTIONS.some(r=>r.id===id&&!r.later));
  if(!chosen.length){form.querySelector('#role-profile-error').textContent='Kies minimaal één functie die bij jou past.';return;}
  state.functionProfiles={...state.functionProfiles,[getPersona(state).id]:chosen};save();render();toast('Je functieprofiel is opgeslagen. Je menu en acties sluiten nu aan.');return;
 }
 if(!['activity-form','task-form','feeding-form','stable-form'].includes(form.id))return;
 event.preventDefault();const f=new FormData(form);
 if(form.id==='activity-form'){
  if(!canPlan(state)||!visibleHorseIds(state).includes(String(f.get('horseId'))))return;
  if(String(f.get('end'))<=String(f.get('time'))){const input=form.querySelector('[name=end]');input.setCustomValidity('Kies een eindtijd na de starttijd.');input.reportValidity();input.addEventListener('input',()=>input.setCustomValidity(''),{once:true});return;}
  const values=Object.fromEntries(f.entries()),existing=state.activities.find(a=>a.id===form.dataset.editId);
  if(existing){if(!viewState().activities.some(a=>a.id===existing.id))return;Object.assign(existing,values);}else state.activities.push({id:crypto.randomUUID(),status:'planned',...values});
  state.selectedDay=values.date;state.period=values.date===browserDay()?'today':'week';save();navigate('planning');toast('Afspraak opgeslagen in je agenda.');
 }else if(form.id==='task-form'){
  if(!canCreateTask(state)||(f.get('horseId')&&!visibleHorseIds(state).includes(String(f.get('horseId')))))return;
  if(!(canManage(state)?state.team.slice(0,3):[getPersona(state)]).some(person=>person.name===f.get('assignee')))return;
  const values=taskFormValues(Object.fromEntries(f.entries()),taskToday(state));
  state.tasks.push({id:crypto.randomUUID(),status:'open',...values});if(values.date)state.selectedDay=values.date;save();navigate('tasks');toast(values.date?'Taak toegevoegd aan de gekozen dag.':'Taak toegevoegd aan Algemene taken.');
 }else if(form.id==='feeding-form'){
  if(!canEditFeeding(state,form.dataset.horse)||!visibleHorseIds(state).includes(form.dataset.horse))return;
  const plan=state.feeding[form.dataset.horse];
  for(const section of form.querySelectorAll('fieldset[data-meal-index]')){const i=Number(section.dataset.mealIndex);plan.meals[i].items=Array.from(section.querySelectorAll('[data-feed-row]')).map(row=>Object.fromEntries(['product','amount','note'].map(key=>[key,row.querySelector(`[data-field="${key}"]`).value.trim()])));}
  save();closeModal();render();toast('Voerinstructies bijgewerkt.');
 }else{
  if(!canManage(state))return;state.stableName=String(f.get('name')).trim();state.stableLocation=String(f.get('location')).trim();state.horses.forEach(h=>h.stable=state.stableName);save();closeModal();render();toast('Stalgegevens bijgewerkt.');
 }
});
document.addEventListener('change',event=>{if(updateTaskTiming(event.target))return;if(event.target.matches('[data-task-day]')&&event.target.value){state.selectedDay=event.target.value;save();if(state.backend?.connected)backendController.reload();else render();}});
modal.addEventListener('cancel',event=>{event.preventDefault();closeModal();});
window.addEventListener('popstate',()=>{horseProfile.cancelOpen();if(modal.open)modal.close();parseHash();render();window.scrollTo(0,0);});
window.addEventListener('hashchange',()=>{horseProfile.cancelOpen();if(modal.open)modal.close();parseHash();render();window.scrollTo(0,0);});
void retireLegacyPreviewCache();
parseHash();render();await backendController.init();
platform.onAuthCallback?.(value=>backendController.handleNativeEmailCallback(value),error=>toast(error.message));

// Keep an open Today header current without replacing forms or polling the backend.
function refreshTodayClock(){
  const header=document.querySelector('[data-today-day]');
  if(!header||document.hidden)return;
  const clock=dashboardClock(new Date(),state);
  if(header.dataset.todayDay!==clock.day){render();return;}
  header.querySelector('[data-today-date]').textContent=clock.dateLabel;
  header.querySelector('[data-today-greeting]').textContent=clock.greeting;
}
setInterval(refreshTodayClock,60000);
window.addEventListener('focus',refreshTodayClock);
document.addEventListener('visibilitychange',refreshTodayClock);

}
