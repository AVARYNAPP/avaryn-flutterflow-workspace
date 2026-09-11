import {browserDay,dashboardClock} from './browser-clock.js';
import {renderTaskForm} from './task-form.js';
import {PRODUCT} from './product-config.js';
import {createAccountCore} from './account-core.js';
import {createTeamCore} from './team-core.js';
import {createHorseResidency} from './horse-residency.js';
import {createActivityEditor} from './activity-form.js';
import {createAuthorityTransfer} from './authority-transfer.js';
import {renderAuth,consumeEmailCallback} from './auth-ui.js';
import {taskToday,taskFormValues} from './task-timing.js';
import {createBackendClient} from './backend-client.js';
import {createFeedingEditor} from './backend-feeding-form.js';
import {renderLogin,loginPending} from './backend-ui.js';
import {getPersona,canPlan,canCreateTask,canEditFeeding} from './horse-access.js';
import {esc,icon} from './components.js';
import {INITIAL_STATE} from './data.js';
import {initFacilities} from './facilities.js';
const clone=value=>JSON.parse(JSON.stringify(value));
const MODE='avaryn-v8-connected-mode';
export function createBackendController({getState,setState,render,save,navigate,showModal,closeModal,toast,restoreRoute,augmentLoad,purgeMedia,clearAuthCallback,clientOptions={}}){
 const client=createBackendClient({baseUrl:PRODUCT.apiBase,...clientOptions});
 const completionRequests=new Map();
 const formControlStates=new WeakMap();
 const acknowledgedRequests=new WeakMap();
 let phase=PRODUCT.demo&&localStorage.getItem(MODE)==='demo'?'demo':'login',message='',busy=false,generation=0;
 let authMode='login',authEmail='',emailCallback=null,resendAfter=0;
 let calendarFlight=null;
 const connected=()=>getState().backend?.connected===true;
 const scopeKey=state=>`avaryn-v8-connected-preferences:${state.backend.actor.id}:${state.backend.organizationId||'personal'}`;
 const contextKey=state=>`avaryn-v8-connected-active-context:${state.backend.actor.id}`;
 function saveLocal(){
  if(!connected())return;const s=getState(),b=s.backend;
  // A suspended account has no operational context to persist.
  if(!b.actor?.id||!Object.hasOwn(b,'organizationId'))return;
  try{
   localStorage.setItem(scopeKey(s),JSON.stringify({theme:s.theme,taskDay:s.selectedDay}));
   localStorage.setItem(contextKey(s),JSON.stringify({organizationId:b.organizationId}));
   return true;
  }catch{return false;}
 }
 function clearCore(){calendarFlight=null;purgeMedia?.();clearAuthCallback?.();const old=getState();setState({theme:old.theme||'light',route:'today',horseFilter:'personal',period:'today',selectedDay:old.today||browserDay(),horses:[],tasks:[],activities:[],feeding:{},team:[],stableName:'Jouw stal',stableLocation:''});}
 async function load(organizationId,day){
  const ticket=generation;let unavailable=false;
  const read=async(id,onDate=day)=>{
   try{return await client.load({organizationId:id,day:onDate});}
   catch(error){
    if(ticket!==generation||id==null||error?.code!=='ORGANIZATION_UNAVAILABLE')throw error;
    unavailable=true;return client.load({organizationId:null,day:onDate});
   }
  };
  let fresh=await read(organizationId);
  if(ticket!==generation)return false;
  if(organizationId===undefined){
   // This preference is only a choice. The current server response grants access.
   let raw,preferred;try{raw=localStorage.getItem(contextKey(fresh));if(raw!=null)preferred=JSON.parse(raw);}catch{unavailable=true;}
   if(raw!=null||unavailable){
    const id=preferred?.organizationId;
    const allowed=id===null||(typeof id==='string'&&fresh.backend.organizations.some(o=>o.id===id));
    if(!allowed)unavailable=true;
    const selected=allowed?id:null;
    if(selected!==fresh.backend.organizationId)fresh=await read(selected);
   }
  }
  if(ticket!==generation)return false;
  if(!day&&getState().route==='tasks'){let previous;try{previous=JSON.parse(localStorage.getItem(scopeKey(fresh))||'null')?.taskDay;}catch{}if(/^\d{4}-\d{2}-\d{2}$/.test(previous||'')&&previous!==fresh.selectedDay)fresh=await read(fresh.backend.organizationId,previous);}
  if(ticket!==generation)return false;
  fresh.today=fresh.backend.todayDate;
  fresh.backend.todayTasks=fresh.backend.todayItems.filter(i=>i.sourceType==='stable_task'&&!['done','completed','cancelled'].includes(i.status));
  fresh.backend.todayActivities=fresh.backend.todayItems.filter(i=>i.sourceType==='horse_activity');
  const current=getState();
  const sameScope=current.backend?.actor?.id===fresh.backend.actor.id&&current.backend?.organizationId===fresh.backend.organizationId;
  let prefs={};try{prefs=JSON.parse(localStorage.getItem(scopeKey(fresh))||'null')||{};}catch{}
  const local=sameScope?current:prefs;
  let next={...fresh,route:current.route||'today',horseFilter:current.horseFilter||'personal',horseId:current.horseId,period:current.period||'today',theme:local.theme||current.theme||'light',facilities:local.facilities,functionProfiles:local.functionProfiles||{},facilityDate:sameScope?current.facilityDate:day||fresh.selectedDay};
  initFacilities(next);
  if(augmentLoad){next=await augmentLoad(next);if(ticket!==generation)return false;}
  // A P2 read must not restore presentation from before a navigation or new draft.
  const latest=getState();
  Object.assign(next,{route:latest.route||next.route,horseFilter:latest.horseFilter||next.horseFilter,horseId:latest.horseId||next.horseId,period:latest.period||next.period,theme:latest.theme!==current.theme?latest.theme:next.theme});
  if(!next.horses.some(h=>h.id===next.horseId))next.horseId=next.horses[0]?.id;
  setState(next);const persisted=saveLocal();phase='connected';message='';
  if(unavailable)toast('Je vorige stalkeuze is niet meer beschikbaar. Je bekijkt nu je persoonlijke paarden.');
  else if(persisted===false)toast('Je stalkeuze kon niet op dit apparaat worden bewaard.');
  return true;
 }
 function errorMessage(error){return error?.userMessage||error?.message||'De verbinding is tijdelijk niet beschikbaar. Je wijziging is niet bevestigd.';}
 function formError(form,error){let el=form.querySelector('.form-error');if(!el){el=document.createElement('p');el.className='form-error';el.setAttribute('role','alert');form.prepend(el);}el.textContent=errorMessage(error);if(form.id.startsWith('backend-feed')&&(error?.uncertain||/STALE|Laad|laden/i.test(errorMessage(error))))el.insertAdjacentHTML('beforeend','<br><button type="button" class="text-link" data-action="backend-feed-reload">Actuele voeding laden (invoer vervalt)</button>');el.scrollIntoView({block:'nearest'});}
 async function perform(form,operation,success,route){
  if(busy)return;
  const retryForm=form.id.startsWith('core-')||form.id==='backend-task-form'||form.id.startsWith('backend-feed')||['role-profile-form','fac-config-form','fac-resource-form','fac-placement-form','fac-booking-form','fac-release-form','arena-reserve-form','arena-review-form','arena-cancel-form'].includes(form.id);
  const ticket=generation,modal=document.querySelector('#modal'),viewId=modal?.dataset.viewId;
  const ownsModal=()=>ticket===generation&&modal?.open&&modal.dataset.viewId===viewId&&(form===modal||modal.contains(form));
  const ownsInlineRoleForm=()=>ticket===generation&&form.id==='role-profile-form'&&form.isConnected===true&&document.getElementById('role-profile-form')===form;
  if(!ownsModal()&&!ownsInlineRoleForm()){toast('Open dit formulier opnieuw voor je huidige account.');return;}
  busy=true;form.dataset.busy='true';
  const originalControls=formControlStates.get(form)||new Map();formControlStates.set(form,originalControls);
  const controls=[...form.querySelectorAll('input, textarea, select, button[type=submit], button[data-action="complete-task"], button[data-action="complete-activity"]')].map(el=>{if(!originalControls.has(el))originalControls.set(el,el.disabled);return {el,disabled:originalControls.get(el)};});
  controls.forEach(({el})=>el.disabled=true);
  const requestId=form.dataset.requestId||(form.dataset.requestId=crypto.randomUUID());
  const purge=()=>{clearCore();closeModal();phase='login';message='Je toegang is veranderd. Log opnieuw in om je actuele gegevens te bekijken.';render();};
  let acknowledged=false;
  try{
   if(acknowledgedRequests.get(form)!==requestId){
    await operation(requestId,()=>ticket===generation);
    if(ticket!==generation)return;
    acknowledgedRequests.set(form,requestId);
   }
   acknowledged=true;
   if(ticket!==generation)return;
   const s=getState();
   if(!await load(form.dataset.resultOrganizationId||s.backend.organizationId,form.dataset.resultDay||s.selectedDay)||ticket!==generation)return;
   if(form.dataset.resultHorseId&&getState().horses.some(h=>h.id===form.dataset.resultHorseId))getState().horseId=form.dataset.resultHorseId;
   const mayFollowUp=ownsModal();
   // Replace a saved form in place before closing it; a pending history.back()
   // would otherwise dismiss the new one-time-link sheet as soon as it opens.
   if(mayFollowUp){core.afterSave?.(form);teamCore.afterSave(form);authority.afterSave(form);}
   if(form.id==='core-profile-form'&&mayFollowUp)teamCore.resume();
   if(ownsModal()){
    if(form.dataset.resultDay)getState().period=form.dataset.resultDay===getState().today?'today':'week';
    if(route)navigate(route);else{closeModal();render();}
   }else render();
   toast(success);
   acknowledgedRequests.delete(form);
  }catch(error){
   if(ticket!==generation)return;
   if(acknowledged)error.uncertain=true;
   if(form.id==='backend-task-form'&&error?.code==='CROSS_STABLE_HORSE_DENIED'){
    try{
     const s=getState();
     if(!await load(s.backend.organizationId,s.selectedDay)||ticket!==generation)return;
     if(!canCreateTask(getState())){purge();return;}
     if(ownsModal()){
      const fresh=getState(),horseSelect=form.querySelector('[name="horseId"]'),assigneeSelect=form.querySelector('[name="assigneeProfileId"]');
      if(horseSelect){const chosen=horseSelect.value;horseSelect.innerHTML=pickHorse(chosen,true,h=>fresh.backend.stableHorseIds.includes(h.id));if(!fresh.backend.stableHorseIds.includes(chosen))horseSelect.value='';}
      if(assigneeSelect){const chosen=assigneeSelect.value;assigneeSelect.innerHTML=(fresh.backend.taskCandidates||[]).map(p=>`<option value="${esc(p.id||p.userId)}"${(p.id||p.userId)===chosen?' selected':''}>${esc(p.name)}</option>`).join('');if(!(fresh.backend.taskCandidates||[]).some(p=>(p.id||p.userId)===chosen))assigneeSelect.value='';}
      formError(form,error);
     }else toast(errorMessage(error));
     render();
    }catch{if(ticket===generation)purge();}
   }else if(error?.accessLost||error?.status===401||error?.status===403)purge();
   else if(ownsModal()||ownsInlineRoleForm()){
    if(retryForm){form.dataset.uncertain=error?.uncertain?'true':'false';if(!error?.uncertain)delete form.dataset.requestId;}
    formError(form,error);
    if(form.dataset.uncertain==='true'){const el=form.querySelector('.form-error');el.append(' Je invoer blijft staan. Opnieuw opslaan herhaalt dezelfde aanvraag veilig.');}
   }else toast(errorMessage(error));
  }finally{
   if(ticket===generation)busy=false;
   delete form.dataset.busy;
   controls.forEach(({el,disabled})=>el.disabled=disabled||(form.dataset.uncertain==='true'&&['INPUT','TEXTAREA','SELECT'].includes(el.tagName)));
  }
 }
 function completion(kind,id){const row=getState()[kind==='task'?'tasks':'activities'].find(r=>r.id===id)||getState().backend.todayItems.find(r=>r.id===id);if(!row)return;const host=document.querySelector('#modal'),key=`${getPersona(getState()).id}:${kind}:${id}:${row.rowVersion}`;if(!completionRequests.has(key))completionRequests.set(key,crypto.randomUUID());host.dataset.requestId=completionRequests.get(key);perform(host,rid=>kind==='task'?client.completeTask(id,row.rowVersion,rid):client.completeActivity(id,row.rowVersion,rid),kind==='task'?'Taak afgerond en opnieuw opgehaald.':'Activiteit afgerond en opnieuw opgehaald.');}
 function pickHorse(selected,optional=false,predicate=()=>true){return (optional?'<option value="">Algemene staltaak</option>':'')+getState().horses.filter(predicate).map(h=>`<option value="${esc(h.id)}"${h.id===selected?' selected':''}>${esc(h.name)}</option>`).join('');}
 const footer=label=>`<footer class="modal-footer"><button type="button" class="button-secondary" data-action="close-modal">Annuleren</button><button type="submit" class="button-primary">${icon('check',17)} ${label}</button></footer>`;
 function taskForm(){if(!canCreateTask(getState()))return;const s=getState(),candidates=s.backend.taskCandidates||[];showModal('Een nieuwe taak',renderTaskForm(s,{id:'backend-task-form',horseOptions:pickHorse('',true,h=>s.backend.stableHorseIds.includes(h.id)),assigneeName:'assigneeProfileId',assigneeOptions:candidates.map(p=>`<option value="${esc(p.id||p.userId)}"${(p.id||p.userId)===s.backend.actor.id?' selected':''}>${esc(p.name)}</option>`).join(''),locations:[...(s.backend.places||[]),...(s.facilities?.resources||[])].map(p=>p.name)}),'','Stalwerk');}
 const feedingEditor=createFeedingEditor({getState,showModal,perform,client,formError,reload:()=>{closeModal();return reload();}});
 const core=createAccountCore({getState,showModal,perform,apiRequest:(name,params,options)=>client.requestRpc(name,params,options)});
 const teamCore=createTeamCore({getState,showModal,perform,toast,apiRequest:(name,params,options)=>client.requestRpc(name,params,options)});
 const residency=createHorseResidency({getState,showModal,perform,toast,apiRequest:client.requestRpc});
 const activityEditor=createActivityEditor({getState,showModal,closeModal,perform,client,formError,toast,onAccessLost:()=>reload()});
 const authority=createAuthorityTransfer({getState,showModal,closeModal,perform,toast,getBackend:()=>({apiRequest:client.requestRpc})});
 function getScreen(){authority.syncContext();activityEditor.syncContext();if(phase==='loading')return loginPending();if(phase==='login')return renderAuth({mode:authMode,message,busy,email:authEmail,tokenHash:Boolean(emailCallback?.tokenHash)});return null;}
 async function init(){
  teamCore.consumeLink();
  emailCallback=consumeEmailCallback(globalThis.location,globalThis.history);
  if(emailCallback){phase='login';authMode=emailCallback.type==='recovery'?'recovery':'verify';if(emailCallback.invalid){authMode='login';message='Deze bevestigingslink is niet geldig. Vraag een nieuwe e-mail aan.';}render();return;}
  if(phase==='demo')return;const ticket=generation;phase='loading';render();
  try{const restored=await client.restore();if(ticket!==generation)return;
   if(restored){if(!await load()||ticket!==generation)return;restoreRoute?.();render();teamCore.resume();}
   else{phase='login';render();}
  }catch(error){if(ticket!==generation)return;clearCore();phase='login';message=errorMessage(error);render();}
 }
 async function handleNativeEmailCallback(value){
  if(!['email','recovery'].includes(value?.type)||!/^[-a-zA-Z0-9_]{16,2048}$/.test(value?.tokenHash||''))return;
  const ticket=++generation;busy=true;clearCore();phase='loading';closeModal();render();
  try{await client.clearLocalSession();if(ticket!==generation)return;emailCallback=value;authMode=value.type==='recovery'?'recovery':'verify';message='';}
  catch(error){if(ticket!==generation)return;emailCallback=null;authMode='login';message=errorMessage(error);}
  finally{if(ticket===generation){busy=false;phase='login';render();}}
 }
 function handleAction(action,button){
  if(['auth-login','auth-signup','auth-recover'].includes(action)){if(busy)return true;authMode=action.slice(5);emailCallback=null;message='';phase='login';render();return true;}
  if(action==='auth-resend'){
   if(busy||Date.now()<resendAfter)return true;
   if(!authEmail){message='Vul eerst je e-mailadres in via Account aanmaken.';render();return true;}
   const ticket=generation;busy=true;render();client.resend(authEmail).then(()=>{if(ticket!==generation)return;resendAfter=Date.now()+60000;message='Als bevestiging nodig is, ontvang je een nieuwe e-mail.';}).catch(e=>{if(ticket===generation)message=errorMessage(e);}).finally(()=>{if(ticket===generation){busy=false;render();}});return true;
  }
  if(!PRODUCT.demo&&['enter-demo','reset-demo','set-persona'].includes(action))return true;
  if(action==='login-open'){generation++;busy=false;emailCallback=null;authMode='login';authEmail='';clearCore();phase='login';message='';localStorage.setItem(MODE,'backend');closeModal();render();return true;}
  if(action==='enter-demo'||action==='logout'){busy=false;generation++;emailCallback=null;authMode='login';authEmail='';client.logout().catch(()=>{});if(action==='enter-demo'){localStorage.setItem(MODE,'demo');phase='demo';setState(clone(INITIAL_STATE));initFacilities(getState());save();navigate('today');}else{clearCore();phase='login';message='';closeModal();render();}return true;}
  if(!connected())return false;
  if(residency.handleAction(action,button)||activityEditor.handleAction(action,button))return true;
  if(authority.handleAction(action,button))return true;
  if(teamCore.handleAction(action,button))return true;
  if(core.handleAction(action,button))return true;
  if(action==='set-persona'||action==='reset-demo')return true;
  if(action==='switch-stable'){showModal('Kies je stal',`<div class="scope-options"><button class="button-secondary" data-action="select-stable" data-id="personal">Mijn paarden · persoonlijk</button>${getState().backend.organizations.map(o=>`<button class="button-secondary" data-action="select-stable" data-id="${esc(o.id)}">${esc(o.name)}</button>`).join('')}<button class="button-primary" data-action="create-stable">Een stal aanmaken</button></div>`,'','Jouw stallen');return true;}
  if(action==='select-stable'){
   const id=button.dataset.id==='personal'?null:button.dataset.id;if(id!==null&&!getState().backend.organizations.some(o=>o.id===id))return true;
   const ticket=++generation;saveLocal();clearCore();phase='loading';closeModal();render();
   load(id).then(loaded=>{if(loaded&&ticket===generation)navigate('stable');}).catch(e=>{if(ticket!==generation)return;clearCore();phase='login';message=errorMessage(e);render();});return true;
  }
  if(action==='new-task'){taskForm();return true;}
  if(action==='complete-task'){completion('task',button.dataset.id);return true;}
  if(action==='complete-activity'){completion('activity',button.dataset.id);return true;}
  if(feedingEditor.handleAction(action,button))return true;
  if(action==='manage-stable'){showModal('Stalgegevens',`<p>${esc(getState().stableName)}</p><p class="horse-muted">Je bekijkt de bestaande stalgegevens. Het bewerken hiervan wordt later in deze nieuwe vormgeving aangesloten.</p>`,`<button class="button-primary" data-action="close-modal">Verder kijken</button>`,'Beheer');return true;}
  return false;
 }
 function handleSubmit(form,event){
  if(/^auth-(login|signup|recover|verify|recovery|reset)-form$/.test(form.id)){
   event.preventDefault();if(busy)return true;
   const data=new FormData(form),mode=authMode,ticket=++generation;
   const email=String(data.get('email')||authEmail).trim(),password=String(data.get('password')||'');authEmail=email;
   const callback=emailCallback;busy=true;message='';render();
   (async()=>{
    try{
     if(mode==='signup'){await client.signUp(email,password);if(ticket!==generation)return;authMode='verify';resendAfter=Date.now()+60000;message='Controleer je inbox en eventueel je ongewenste e-mail.';}
     else if(mode==='recover'){await client.recover(email);if(ticket!==generation)return;authMode='recovery';message='Als dit account bestaat, ontvang je een herstelmail.';}
     else{
      if(mode==='login')await client.login(email,password);
      else if(mode==='reset')await client.updatePassword(password);
      else await client.verifyEmail({email,token:String(data.get('token')||''),tokenHash:callback?.tokenHash,type:mode==='recovery'?'recovery':callback?'email':'signup'});
      if(ticket!==generation)return;
      emailCallback=null;
      if(mode==='recovery'){authMode='reset';return;}
      clearCore();phase='loading';render();if(!await load()||ticket!==generation)return;
      localStorage.setItem(MODE,'backend');navigate('today');
      if(!getState().backend.profile?.onboarding_completed_at)core.profileForm();else teamCore.resume();
     }
    }catch(error){if(ticket!==generation)return;clearCore();phase='login';message=errorMessage(error);}
    finally{if(ticket===generation){busy=false;render();}}
   })();return true;
  }
  if(!connected())return false;
  if(residency.handleSubmit(form,event)||activityEditor.handleSubmit(form,event))return true;
  if(authority.handleSubmit(form,event))return true;
  if(teamCore.handleSubmit(form,event))return true;
  if(core.handleSubmit(form,event))return true;
  if(feedingEditor.handleSubmit(form,event))return true;
  if(!['backend-task-form','backend-activity-form'].includes(form.id))return false;
  event.preventDefault();const raw=Object.fromEntries(new FormData(form)),f=form.id==='backend-task-form'?taskFormValues(raw,taskToday(getState())):raw;if(f.date)form.dataset.resultDay=f.date;else delete form.dataset.resultDay;
  if(form.id==='backend-task-form')perform(form,id=>client.saveTask(f,id),'Taak opgeslagen en opnieuw opgehaald.','tasks');
  if(form.id==='backend-activity-form'){if(f.end<=f.time){formError(form,new Error('Kies een eindtijd na de begintijd.'));return true;}f.id=form.dataset.editId||undefined;if(f.id)f.rowVersion=getState().activities.find(a=>a.id===f.id)?.rowVersion;perform(form,id=>client.saveActivity(f,id),'Afspraak opgeslagen en opnieuw opgehaald.','planning');}

  return true;
 }
 function suspendAccount(){
  const b=getState().backend;if(!b?.connected)return;
  generation++;busy=false;client.invalidateData();clearCore();
  setState({...getState(),backend:{connected:true,actor:b.actor,userId:b.userId}});phase='connected';render();
 }
 async function clearDeletedSession({isCurrent,message:success}){
  if(!isCurrent())return;
  const ticket=++generation;busy=false;
  await client.clearLocalSession();
  if(ticket!==generation||!isCurrent())return;
  clearCore();phase='login';message=success;closeModal();render();
 }
 function reload(day=getState().selectedDay){
  if(!connected())return;const org=getState().backend.organizationId,ticket=++generation;phase='loading';render();
  return load(org,day).then(loaded=>{if(loaded&&ticket===generation)render();}).catch(e=>{if(ticket!==generation)return;clearCore();phase='login';message=errorMessage(e);render();});
 }
 function refreshToday(now=new Date()){
  const s=getState(),b=s.backend;
  // A day change refreshes authoritative projections, never an open draft.
  if(!connected()||phase!=='connected'||busy||calendarFlight||b.profile?.profile_status!=='active'||!b.todayDate||document.querySelector('#modal')?.open||(s.route==='function-profile'&&document.querySelector('#app form')))return false;
  const day=dashboardClock(now,s).day;if(day===b.todayDate)return false;
  const flight={};calendarFlight=flight;
  const selectedDay=s.selectedDay===b.todayDate?day:s.selectedDay;
  void reload(selectedDay).finally(()=>{if(calendarFlight===flight)calendarFlight=null;});
  return true;
 }
 return {getScreen,init,handleNativeEmailCallback,suspendAccount,clearDeletedSession,handleAction,handleSubmit,saveLocal,connected,reload,refreshToday,perform,apiRequest:(name,params,options)=>client.requestRpc(name,params,options),edgeRequest:client.edgeRequest,mediaRequest:client.mediaRequest,uploadHorseMedia:client.uploadHorseMedia,downloadHorseMedia:client.downloadHorseMedia};
}
