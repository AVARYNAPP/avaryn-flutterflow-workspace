import {getPersona,visibleHorseIds,PERSONAS} from './horse-access.js';
import {getFunctions} from './role-profile.js';
import {esc,icon} from './components.js';
import {EXERCISES,ROUTINES,EXERCISE_SAFETY,durationLabel} from './exercise-data.js';
import {browserDay,activityDay,activityOrder} from './browser-clock.js';

export const WARMUP_STEPS=Object.freeze(['Nek/schouders losmaken','Heupen openen','Enkels/kuiten activeren','Ademhaling/focus','Korte balanscheck']);
export const VITALITY_FEELINGS=Object.freeze(['Rustig','Energiek','Gespannen','Moe','Sterk']);
const PREFIX='avaryn-v8-rider-vitality-v1:';
const ACTIONS=new Set(['vitality-open','vitality-warmup','vitality-skip','vitality-later','vitality-reflection','vitality-focus','vitality-share','vitality-moments','vitality-exercises','vitality-start','vitality-previous','vitality-pause','vitality-video','vitality-return','vitality-restart']);
const FORM_IDS=new Set(['vitality-warmup-form','vitality-reflection-form','vitality-focus-form','vitality-step-form']);
const dayOf=state=>state?.backend?.calendar?.today_date||state?.today||browserDay();
const cleanText=value=>typeof value==='string'?value.trim().slice(0,500):'';
function scopeOf(state){
  if(state?.backend){
    const id=state.backend.connected===true&&state.backend.actor?.id;
    return typeof id==='string'&&id.trim()?`connected:${encodeURIComponent(id)}`:null;
  }
  return Object.hasOwn(PERSONAS,state?.persona)?`demo:${state.persona}`:null;
}
export function canUseVitality(state){
  return Boolean(scopeOf(state)&&getFunctions(state).some(value=>['owner','rider','trainer'].includes(value)));
}
function storageFor(injected){return injected===undefined?globalThis.localStorage:injected;}
const routineById=id=>ROUTINES.find(r=>r.id===id);
const routineEmpty=()=>({currentStep:0,completed:[],status:'in_progress'});
const legacyOrder=[0,1,2,4,3]; // Old checklist had breathing before balance.
const emptyDay=()=>({warmup:null,reflection:null,focus:'',routines:{}});
function currentRecord(state){
  const record=state.backend?.vitality;
  return record?.profile_id===state.backend?.actor?.id&&record?.on_date===dayOf(state)&&Number.isSafeInteger(record?.row_version)&&record.row_version>=0&&record.document&&typeof record.document==='object'&&!Array.isArray(record.document)?record:null;
}
function cleanRoutine(value){
  if(!value||!Number.isInteger(value.currentStep)||value.currentStep<0||value.currentStep>=5)return null;
  const completed=[...new Set((Array.isArray(value.completed)?value.completed:[]).filter(i=>Number.isInteger(i)&&i>=0&&i<5))];
  return {currentStep:value.currentStep,completed,status:value.status==='done'&&completed.length===5?'done':value.status==='later'?'later':'in_progress'};
}
function cleanDay(value){
  if(!value||typeof value!=='object')return emptyDay();
  const w=value.warmup,r=value.reflection;
  const result={warmup:w&&[5,10].includes(w.minutes)&&['done','later','skipped'].includes(w.status)?{
    minutes:w.minutes,status:w.status,steps:[...new Set((Array.isArray(w.steps)?w.steps:[]).filter(i=>Number.isInteger(i)&&i>=0&&i<WARMUP_STEPS.length))]
  }:null,reflection:r&&typeof r==='object'?{
    person:VITALITY_FEELINGS.includes(r.person)?r.person:'',horse:VITALITY_FEELINGS.includes(r.horse)?r.horse:'',focus:cleanText(r.focus),sharingIntent:r.sharingIntent==='later'?'later':'private'
  }:null,focus:cleanText(value.focus),routines:{}};
  for(const routine of ROUTINES.filter(r=>r.seconds)){const saved=cleanRoutine(value.routines?.[routine.id]);if(saved)result.routines[routine.id]=saved;}
  if(result.warmup&&!Object.hasOwn(value,'routines')){
    const id=w.minutes===10?'extended':'basic',completed=result.warmup.steps.map(i=>legacyOrder[i]);
    if(!result.routines[id])result.routines[id]={currentStep:[0,1,2,3,4].find(i=>!completed.includes(i))??4,completed,status:w.status==='done'&&completed.length===5?'done':'later'};
  }
  return result;
}
function readDocument(scope,storage){
  try{
    const target=storageFor(storage);if(!target)throw new Error('unavailable');
    const text=target.getItem(PREFIX+scope),parsed=text?JSON.parse(text):{version:1,days:{}};
    if(parsed?.version!==1||!parsed.days||typeof parsed.days!=='object'||Array.isArray(parsed.days))throw new Error('unreadable');
    return {ok:true,document:{version:1,days:parsed.days}};
  }catch{return {ok:false,document:{version:1,days:{}}};}
}
// Connected accounts read only the current server record; demo storage is never imported.
export function readVitality(state,{storage}={}){
  if(!canUseVitality(state))return {...emptyDay(),available:false};
  if(state.backend?.connected){const record=currentRecord(state);return {...cleanDay(record?.document),available:Boolean(record)};}
  const result=readDocument(scopeOf(state),storage);
  return {...cleanDay(result.document.days[dayOf(state)]),available:result.ok};
}
export function vitalityTraining(state,day=dayOf(state)){
  if(!canUseVitality(state))return null;
  const ids=new Set(visibleHorseIds(state));
  const activity=(state.activities||[]).filter(a=>activityDay(a)===day&&ids.has(a.horseId)&&
    (a.itemKind?a.itemKind==='training':a.type==='Training')&&['planned','in_progress'].includes(a.status))
    .sort(activityOrder)[0];
  const horse=activity&&(state.horses||[]).find(h=>h.id===activity.horseId);
  return horse?{activity,horse}:null;
}
export function renderVitalityCard(state,ctx={esc,icon},day){
  if(!canUseVitality(state))return '';
  const training=vitalityTraining(state,day);
  const title=training?'Warming-up voor je rit':'Ruiterfitheid';
  const text=training?`5 minuten voorbereiding voor je training met ${training.horse.name}.`:'Kies een focuspunt voor je volgende rit.';
  return `<section class="vitality-card" aria-label="Ruiter & fitheid"><span class="vitality-card-icon">${ctx.icon('roles',25)}</span><div class="vitality-card-body"><div class="vitality-card-label"><span>Paard én mens</span>${state.backend?.vitality?'':'<span class="vitality-badge">Prototype</span>'}</div><h2>${ctx.esc(title)}</h2><p>${ctx.esc(text)}</p><div class="vitality-card-actions"><button type="button" class="text-link" data-action="${training?'vitality-start':'vitality-focus'}"${training?' data-routine="basic"':''}>${training?'Start 5 min':'Focuspunt toevoegen'} ${ctx.icon('chevron-right',15)}</button><button type="button" class="vitality-quiet" data-action="vitality-exercises">${training?'Oefeningen':'Oefeningen bekijken'}</button></div></div></section>`;
}
const privacy=()=>'<p class="vitality-privacy"><strong>Prototype · persoonlijk en lokaal.</strong> Je keuzes en tekst blijven alleen in deze browser, apart voor dit account. Ze worden niet naar je stalteam, vrienden of de server verstuurd.</p>';
const errorSlot=()=>'<p class="vitality-error" role="alert" data-vitality-error hidden></p>';
const footer=(label,later=false)=>`<footer class="modal-footer"><button type="button" class="button-secondary" data-action="${later?'vitality-later':'close-modal'}">${later?'Later':'Annuleren'}</button><button type="submit" class="button-primary">${label}</button></footer>`;
const actionButton=(action,label)=>`<button type="button" class="button-secondary" data-action="${action}">${label}</button>`;
const feelingField=(name,label,value)=>`<label class="form-field">${label}<select name="${name}"><option value="">Kies een woord (optioneel)</option>${VITALITY_FEELINGS.map(word=>`<option${value===word?' selected':''}>${word}</option>`).join('')}</select></label>`;

export function createVitalityController({getState,showModal,closeModal,toast,navigate,render=()=>{},storage,remote}){
  let fingerprint='',generation=0,active=null;
  const forms=new WeakMap(),buttons=new WeakMap();
  const requests=new WeakMap();let pending=false;
  const privateCopy=()=>getState().backend?.connected?'<p class="vitality-privacy"><strong>Persoonlijk bewaard in je account.</strong> Je voortgang, reflectie en focus zijn beschikbaar op je apparaten. Ze worden niet met je stalteam of vrienden gedeeld. Eerdere lokale prototypegegevens worden niet geïmporteerd.</p>':privacy();
  const savedCopy=(local,connected)=>getState().backend?.connected?connected:local;
  function commit(operation,done){
    const captured={generation,viewId:active?.viewId};
    const finish=ok=>{syncContext();if(ok&&captured.generation===generation&&captured.viewId===active?.viewId&&owned())done();};
    if(operation?.then)void operation.then(finish);else finish(operation);
  }
  function owned(){const modal=globalThis.document?.getElementById('modal');return Boolean(active&&modal===active.modal&&modal.open&&modal.dataset.viewId===active.viewId);}
  function syncContext(){
    const state=getState(),next=JSON.stringify([scopeOf(state),dayOf(state),canUseVitality(state)]);
    if(next===fingerprint)return false;
    fingerprint=next;generation++;
    const close=owned();active=null;if(close)closeModal();
    return true;
  }
  function allowed(){syncContext();if(canUseVitality(getState()))return true;toast('Kies Ruiter, Paardeigenaar of Trainer in je functieprofiel om dit persoonlijke prototype te bekijken.');return false;}
  function display(title,body,footerButtons='',meta={}){
    showModal(title,`<div class="vitality-sheet-content">${body}</div>`,footerButtons,savedCopy('Ruiter & fitheid · Prototype','Ruiter & fitheid'),'vitality-sheet');
    const modal=globalThis.document?.getElementById('modal');
    active={...meta,scope:scopeOf(getState()),day:dayOf(getState()),generation,modal,viewId:modal?.dataset.viewId};
    const form=modal?.querySelector('[data-vitality-form]');if(form)forms.set(form,{...active});
    for(const button of modal?.querySelectorAll('[data-action^="vitality-"]')||[])buttons.set(button,{...active});
  }
  function formCurrent(form){
    syncContext();const captured=forms.get(form);
    return Boolean(captured&&canUseVitality(getState())&&owned()&&captured.generation===generation&&captured.scope===scopeOf(getState())&&captured.day===dayOf(getState())&&captured.viewId===active.viewId&&form.isConnected&&globalThis.document.getElementById(form.id)===form);
  }
  function showError(form,message){const node=form?.querySelector('[data-vitality-error]');if(node){node.textContent=message;node.hidden=false;}else toast(message);}
  function persist(update,form){
    if(getState().backend?.connected){
      const host=form||active?.modal,state=getState(),captured={generation,scope:scopeOf(state),day:dayOf(state)};
      if(pending||!host)return false;
      const record=currentRecord(state);
      if(!remote||!record){showError(form,'Je persoonlijke voortgang is niet geladen. Open dit onderdeel opnieuw; er is niets opgeslagen.');return false;}
      const request=requests.get(host)||{document:update(cleanDay(record.document)),rowVersion:record.row_version,requestId:crypto.randomUUID()};
      requests.set(host,request);pending=true;
      const controls=[...(host.querySelectorAll?.('input,textarea,select,button[type="submit"],button[data-action="vitality-pause"],button[data-action="vitality-previous"],button[data-action="vitality-restart"]')||[])].map(el=>[el,el.disabled]);controls.forEach(([el])=>el.disabled=true);
      return remote.save(request).then(ok=>{requests.delete(host);return ok;}).catch(error=>{
        if(!error.uncertain)requests.delete(host);
        if(captured.generation===generation&&captured.scope===scopeOf(getState())&&captured.day===dayOf(getState()))showError(form,error.message||'Opslaan is niet bevestigd. Je invoer blijft staan.');
        return false;
      }).finally(()=>{pending=false;controls.forEach(([el,disabled])=>{el.disabled=disabled||(requests.has(host)&&['INPUT','TEXTAREA','SELECT'].includes(el.tagName));});});
    }
    const state=getState(),scope=scopeOf(state),day=dayOf(state),read=readDocument(scope,storage);
    if(!read.ok){showError(form,'Lokale opslag is niet beschikbaar. Je invoer blijft hier staan; er is niets opgeslagen.');return false;}
    try{
      const next=update(cleanDay(read.document.days[day]));
      const days={...read.document.days,[day]:next};
      storageFor(storage).setItem(PREFIX+scope,JSON.stringify({version:1,days}));return true;
    }catch{showError(form,'Opslaan in deze browser lukte niet. Je invoer blijft staan. Probeer het opnieuw.');return false;}
  }
  const safety=()=>`<p class="vitality-safety">${EXERCISE_SAFETY}</p>`;
  const localState=()=>readVitality(getState(),{storage});
  function routineState(id){return localState().routines[id]||routineEmpty();}
  function warmup(){
    const saved=localState();
    display('Warming-up',`<p class="vitality-intro">Kies een algemene voorbereiding op jouw tempo. De duur is een richtlijn; er loopt geen timer.</p><div class="vitality-routines">${ROUTINES.map(r=>`<button type="button" class="vitality-routine" data-action="vitality-start" data-routine="${r.id}"><span>${icon(r.seconds?'roles':'clock',23)}</span><span><strong>${r.title}</strong><small>${r.description}</small><em>${r.seconds?`${durationLabel(r.seconds.reduce((a,b)=>a+b,0))} · ${saved.routines[r.id]?.status==='done'?'Afgerond vandaag':saved.routines[r.id]?`Hervatten bij stap ${saved.routines[r.id].currentStep+1}`:'5 stappen'}`:'Binnenkort'}</em></span>${icon('chevron-right',17)}</button>`).join('')}</div>${privateCopy()}`,actionButton('vitality-exercises','Oefeningen bekijken'));
  }
  function completion(id){
    const routine=routineById(id);
    display('Even voorbereid',`<p class="vitality-intro">Je hebt de vijf stappen van ${esc(routine.title)} doorlopen. Dit is geen tijd- of fitheidsmeting. Wil je kort terugblikken?</p>${privateCopy()}`,actionButton('vitality-reflection','Korte terugblik')+actionButton('vitality-share','Deel een moment')+`<button type="button" class="vitality-quiet" data-action="vitality-restart" data-routine="${id}">Opnieuw starten</button>`,{routineId:id});
  }
  function step(id,position){
    const r=routineById(id);if(!r?.seconds)return;
    const saved=routineState(id),index=position??saved.currentStep,e=EXERCISES[index];if(!e)return;
    display(r.title,`<form id="vitality-step-form" data-vitality-form><div class="vitality-step-heading"><span>Stap ${index+1}/5</span><span>${durationLabel(r.seconds[index])}</span></div><div class="vitality-step-progress" role="img" aria-label="Stap ${index+1} van 5">${EXERCISES.map((_,i)=>`<span class="${i===index?'current':saved.completed.includes(i)?'complete':''}"></span>`).join('')}</div><div class="vitality-exercise-mark">${icon(e.icon,34)}</div><h3 class="vitality-step-title">${e.title}</h3><p class="vitality-intro">${e.description}</p><dl class="vitality-exercise-meta"><div><dt>Focus</dt><dd>${e.focus}</dd></div><div><dt>Niveau</dt><dd>${e.level}</dd></div></dl><p class="vitality-hint">In deze routine: ${durationLabel(r.seconds[index])}.${r.seconds[index]!==e.seconds?` Losse oefening: ${durationLabel(e.seconds)}.`:''}</p>${r.id==='dressage'?'<p class="vitality-hint">Focus: rust en houding. Je volgt de algemene basisroutine.</p>':''}${safety()}<div class="vitality-step-links">${actionButton('vitality-video','Bekijk video')}${actionButton('vitality-exercises','Alle oefeningen')}</div>${errorSlot()}<footer class="modal-footer">${index?`<button type="button" class="button-secondary" data-action="vitality-previous">Vorige</button>`:''}<button type="submit" class="button-primary">${index===4?'Klaar':'Volgende'}</button><button type="button" class="vitality-quiet" data-action="vitality-pause">Later verder</button></footer></form>`, '',{routineId:id,step:index,screen:'step'});
  }
  function start(id){
    const routine=routineById(id);if(!routine){toast('Kies een routine uit de lijst.');return;}
    if(!routine.seconds){display(routine.title,`<p class="vitality-badge">Binnenkort</p><p class="vitality-intro">${routine.description} Je kunt nu de algemene basisroutine bekijken.</p>`,actionButton('vitality-warmup','Terug naar routines'));return;}
    if(routineState(id).status==='done')completion(id);else step(id);
  }
  function library(returnContext=null,scrollTop=0){
    display('Oefeningen',`<p class="vitality-intro">Vijf algemene oefeningen om je voorbereiding te verkennen. De losse oefentijden verschillen van de korte basisroutine.</p>${safety()}<div class="vitality-exercise-list">${EXERCISES.map(e=>`<article class="vitality-exercise-card"><div class="vitality-exercise-top"><span>${icon(e.icon,27)}</span><div><h3>${e.title}</h3><p>${durationLabel(e.seconds)} · ${e.level}</p></div></div><p>${e.description}</p><p class="vitality-exercise-focus">Focus: ${e.focus}</p><button type="button" class="vitality-video-placeholder" data-action="vitality-video" data-exercise="${e.id}">${icon('roles',20)}<span>Bekijk video<small>Video volgt later</small></span>${icon('chevron-right',16)}</button></article>`).join('')}</div>`,returnContext?actionButton('vitality-return',`Terug naar stap ${returnContext.step+1}`):actionButton('vitality-warmup','Warming-up kiezen'),{screen:'library',returnContext});
    if(owned()&&Number.isFinite(scrollTop))active.modal.scrollTop=Math.max(0,scrollTop);
  }
  function video(exerciseId){
    const e=EXERCISES.find(e=>e.id===exerciseId)||EXERCISES[active?.step];if(!e){toast('Kies een oefening.');return;}
    const returnContext=active.screen==='step'?{routineId:active.routineId,step:active.step}:active.returnContext;
    const back=active.screen==='step'?'step':'library',libraryScrollTop=back==='library'&&owned()?active.modal.scrollTop:0;
    display('Video volgt later',`<p class="vitality-eyebrow">${e.title}</p><p class="vitality-intro">Hier komen korte voorbeeldvideo’s zodat je de oefening veilig en duidelijk kunt volgen.</p><p class="vitality-hint">De video is nog niet beschikbaar. Je kunt verder met de uitleg in tekst.</p>`,actionButton('vitality-return',back==='step'?`Terug naar stap ${returnContext.step+1}`:'Terug naar oefeningen'),{screen:'video',back,returnContext,libraryScrollTop});
  }
  function saveProgress(id,progress,form){
    const r=routineById(id);
    return persist(day=>({...day,routines:{...day.routines,[id]:progress},warmup:{minutes:r.seconds.reduce((a,b)=>a+b,0)/60,status:progress.status==='done'?'done':'later',steps:progress.completed.map(i=>legacyOrder[i])}}),form);
  }
  function reflection(){
    const saved=readVitality(getState(),{storage}).reflection||{};
    display('Trainingsterugblik',`<p class="vitality-intro">Een moment voor je eigen beleving. Je bewaart één terugblik per dag; aanpassen vervangt je eerdere tekst van vandaag.</p><form id="vitality-reflection-form" data-vitality-form>${feelingField('person','Hoe voelde jij je?',saved.person)}${feelingField('horse','Hoe voelde je paard?',saved.horse)}<label class="form-field">Focus voor volgende keer<textarea name="focus" maxlength="500" placeholder="Wat wil je meenemen naar je volgende rit?">${esc(saved.focus||'')}</textarea></label><label class="form-field">Wat wil je met deze terugblik?<select name="sharingIntent"><option value="private"${saved.sharingIntent!=='later'?' selected':''}>Privé houden</option><option value="later"${saved.sharingIntent==='later'?' selected':''}>Misschien later delen</option></select></label><p class="vitality-hint">Je bewaart alleen je intentie. Er wordt niets gedeeld. Beleving en reflectie, geen medische meting; alle velden zijn optioneel.</p>${privateCopy()}${errorSlot()}${footer(savedCopy('Terugblik lokaal bewaren','Terugblik bewaren'))}</form>`);
  }
  function focus(){
    const saved=readVitality(getState(),{storage});
    display('Jouw focuspunt',`<p class="vitality-intro">Wat wil je meenemen naar je volgende rit?</p><form id="vitality-focus-form" data-vitality-form><label class="form-field">Mijn focuspunt<textarea name="focus" maxlength="500" placeholder="Bijvoorbeeld rustig beginnen en aandacht houden">${esc(saved.focus)}</textarea></label>${privateCopy()}${errorSlot()}${footer(savedCopy('Focuspunt lokaal bewaren','Focuspunt bewaren'))}</form>`);
  }
  function section(name){
    if(name==='warmup')return warmup();if(['exercises','mobility'].includes(name))return library();if(['feeling','journal'].includes(name))return reflection();if(name==='focus')return focus();
    const content={cooldown:['Cooling-down','Neem na je rit een rustig moment. Sta kort stil bij hoe jij en je paard de training hebben ervaren.','vitality-reflection','Een terugblik toevoegen'],mobility:['Mobiliteit','Je warming-up bevat vijf eenvoudige aandachtspunten voor je voorbereiding. Kies zelf hoeveel tijd je eraan wilt geven.','vitality-warmup','Warming-up openen'],goals:['Trainingsdoelen','Doelen en voortgang bijhouden volgt later. Een persoonlijk focuspunt kun je alvast alleen in deze browser bewaren.','vitality-focus','Focuspunt toevoegen']}[name];
    if(!content){toast('Dit onderdeel is nog niet beschikbaar.');return;}
    display(content[0],`<p class="vitality-intro">${content[1]}</p>${name==='goals'?'<p class="vitality-badge">Binnenkort</p>':''}${privateCopy()}`,actionButton(content[2],content[3]));
  }
  function share(){display('Deel een moment','<p class="vitality-intro">Een fijne rit of een klein moment samen: bepaal zelf wat je later wilt delen.</p><p class="vitality-privacy"><strong>Prototype · er wordt niets verstuurd.</strong> Dit is alleen een deelvoorstel. Er is geen upload of publicatie en je persoonlijke terugblik wordt niet overgenomen.</p><p class="vitality-hint">Vrienden zien alleen wat jij deelt. Stalrechten blijven apart.</p>',actionButton('vitality-moments','Momenten bekijken'));}
  function handleAction(action,button){
    if(!ACTIONS.has(action))return false;
    if(pending)return true;
    const captured=buttons.get(button);if(!allowed())return true;
    if(captured&&(!owned()||captured.generation!==generation||captured.viewId!==active.viewId||!button.isConnected)){toast('Open dit onderdeel opnieuw voor je huidige account en dag.');return true;}
    if(['vitality-previous','vitality-pause','vitality-video','vitality-return','vitality-restart'].includes(action)&&(!captured||!owned())){toast('Open de oefening opnieuw.');return true;}
    if(action==='vitality-open'){section(button?.dataset.section);return true;}
    if(action==='vitality-warmup')warmup();
    else if(action==='vitality-start')start(button?.dataset.routine||'basic');
    else if(action==='vitality-exercises')library(owned()?(active.screen==='step'?{routineId:active.routineId,step:active.step}:active.returnContext||null):null);
    else if(action==='vitality-video')video(button.dataset.exercise);
    else if(action==='vitality-return'){const back=active.back,context=active.returnContext,scrollTop=active.libraryScrollTop;if(back==='library')library(context,scrollTop);else if(context)step(context.routineId,context.step);else warmup();}
    else if(action==='vitality-restart'){const id=active.routineId;if(routineById(id)?.seconds)commit(saveProgress(id,routineEmpty()),()=>{render();step(id,0);});}
    else if(action==='vitality-previous'||action==='vitality-pause'){
      const form=globalThis.document?.getElementById('vitality-step-form');if(!formCurrent(form))return true;
      const id=active.routineId,position=active.step,progress={...routineState(id),currentStep:action==='vitality-previous'?Math.max(0,position-1):position,status:action==='vitality-pause'?'later':'in_progress'};
      commit(saveProgress(id,progress,form),()=>{if(action==='vitality-pause'){active=null;closeModal();render();toast(savedCopy('Je voortgang is alleen in deze browser bewaard.','Je voortgang is bewaard in je account.'));}else step(id,progress.currentStep);});
    }
    else if(action==='vitality-reflection')reflection();
    else if(action==='vitality-focus')focus();
    else if(action==='vitality-share')share();
    else if(action==='vitality-moments'){active=null;navigate('moments');}
    else if(action==='vitality-skip'||action==='vitality-later'){
      const form=action==='vitality-later'?globalThis.document?.getElementById('vitality-warmup-form'):null;
      if(action==='vitality-later'&&!formCurrent(form)){toast('Open de warming-up opnieuw voor je huidige account en dag.');return true;}
      const minutes=form?Number(new FormData(form).get('minutes')):5;
      const steps=form?new FormData(form).getAll('step').map(Number):[];
      commit(persist(day=>({...day,warmup:{minutes:[5,10].includes(minutes)?minutes:5,status:action==='vitality-later'?'later':'skipped',steps}}),form),()=>{
        if(owned()){active=null;closeModal();}render();toast(savedCopy(action==='vitality-later'?'Bewaard voor later in deze browser.':'Voor vandaag overgeslagen in deze browser.','Je keuze is bewaard in je account.'));
      });
    }
    return true;
  }
  function handleSubmit(form,event){
    const id=form?.getAttribute?.('id')||form?.id;if(!FORM_IDS.has(id))return false;event.preventDefault();
    if(!formCurrent(form)){toast('Deze invoer hoort bij een eerdere context. Open het formulier opnieuw.');return true;}
    if(id==='vitality-step-form'){
      const captured=forms.get(form),routineId=captured.routineId,index=captured.step,saved=routineState(routineId),completed=[...new Set([...saved.completed,index])];
      if(index===4&&completed.length!==5){showError(form,'Doorloop eerst de eerdere stappen. Je kunt terug met Vorige.');return true;}
      const progress={currentStep:Math.min(4,index+1),completed,status:index===4?'done':'in_progress'};
      commit(saveProgress(routineId,progress,form),()=>{render();if(index===4)completion(routineId);else step(routineId,progress.currentStep);});return true;
    }
    const values=new FormData(form);let update;
    if(id==='vitality-warmup-form'){
      const minutes=Number(values.get('minutes')),steps=[...new Set(values.getAll('step').map(Number))];
      if(![5,10].includes(minutes)||steps.some(i=>!Number.isInteger(i)||i<0||i>=5)){showError(form,'Controleer je tijdkeuze en checklist.');return true;}
      if(steps.length!==5){showError(form,'Vink de vijf onderdelen af, of kies Later om je voorbereiding te bewaren.');return true;}
      update=day=>({...day,warmup:{minutes,steps,status:'done'}});
    }else if(id==='vitality-reflection-form'){
      const person=String(values.get('person')||''),horse=String(values.get('horse')||'');
      if((person&&!VITALITY_FEELINGS.includes(person))||(horse&&!VITALITY_FEELINGS.includes(horse))){showError(form,'Kies een gevoel uit de lijst.');return true;}
      const sharingIntent=values.get('sharingIntent')||'private';if(!['private','later'].includes(sharingIntent)){showError(form,'Kies Privé houden of Misschien later delen.');return true;}
      update=day=>({...day,reflection:{person,horse,focus:cleanText(values.get('focus')),sharingIntent}});
    }else update=day=>({...day,focus:cleanText(values.get('focus'))});
    commit(persist(update,form),()=>{
      const wasWarmup=id==='vitality-warmup-form';
      const wasReflection=id==='vitality-reflection-form';
      if(!wasWarmup&&!wasReflection){active=null;closeModal();}render();
      if(wasWarmup){display('Even voorbereid',`<p class="vitality-intro">Je checklist is afgevinkt. Na je rit kun je kort terugblikken, of gewoon verder met je dag.</p>${privateCopy()}`,actionButton('vitality-reflection','Korte terugblik')+actionButton('vitality-share','Deel een moment'));}
      if(wasReflection)display('Terugblik bewaard',`<p class="vitality-intro">Je terugblik blijft persoonlijk. Ook bij Misschien later delen is er niets gedeeld.</p>${privateCopy()}`,actionButton('vitality-share','Deel een moment')+'<button type="button" class="button-primary" data-action="close-modal">Verder met mijn dag</button>');
      toast(savedCopy(wasWarmup?'Warming-up afgevinkt in deze browser.':'Persoonlijk bewaard in deze browser.','Persoonlijk bewaard in je account.'));
    });
    return true;
  }
  return {handleAction,handleSubmit,syncContext};
}
