import {esc,icon} from './components.js';
import {canPlan} from './horse-access.js';
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const KINDS={training:'Training',care:'Verzorging',farrier:'Hoefsmid',veterinary:'Dierenarts',competition:'Wedstrijd',feeding:'Voeding',task:'Taak',transport:'Vervoer',other:'Overig'};
const validDay=value=>/^\d{4}-\d{2}-\d{2}$/.test(value||'')&&Number.isFinite(Date.parse(value))&&new Date(value).toISOString().slice(0,10)===value;
const ids=value=>Array.isArray(value)?[...new Set(value.filter(v=>UUID.test(v)))]:[];
const stale=()=>Object.assign(Error('Open de afspraak opnieuw voor je huidige account en paard.'),{code:'STALE_CONTEXT'});
const invalid=message=>Object.assign(Error(message),{code:'INPUT_INVALID'});

/** Existing schedule RPC only. Candidate identity comes exclusively from the
 * horse collaboration read, never a role preference or a broad team list.
 * Call syncContext from the controller's render/getScreen gate. */
export function createActivityEditor({getState,showModal,closeModal,perform,client,formError,toast=()=>{},onAccessLost=()=>{}}){
 const captures=new WeakMap();let scope='',generation=0,active=null;
 const context=()=>{const s=getState(),b=s.backend;return b?.connected===true&&UUID.test(b.actor?.id||'')?`${b.userId||''}:${b.actor.id}:${b.organizationId||''}:${s.selectedDay||''}:${b.calendar?.time_zone||''}`:'';};
 const modal=()=>globalThis.document?.getElementById('modal');
 const owned=c=>!!c&&modal()?.open===true&&modal().dataset.viewId===c.viewId&&c.form.isConnected&&modal().contains(c.form);
 function syncContext(){const next=context();if(next===scope)return;const previous=active;scope=next;generation++;active=null;if(owned(previous))closeModal();}
 const current=c=>{syncContext();return !!scope&&c.scope===scope&&c.generation===generation;};
 const horses=()=>getState().horses.filter(h=>UUID.test(h.id)&&canPlan(getState(),h.id));
 const allowed=c=>current(c)&&owned(c)&&horses().some(h=>h.id===c.horseId);
 const showError=(c,error)=>{if(current(c)&&owned(c))formError(c.form,error);};
 const field=(name,label,value,extra='')=>`<label class="form-field">${label}<input name="${name}" value="${esc(value??'')}" ${extra}></label>`;
 function participantMarkup(c){
  if(!c.manage)return `<p>Je kunt de betrokkenen hier niet wijzigen. ${c.old?'De bestaande betrokkenen blijven behouden.':'Je wordt zelf aan deze afspraak gekoppeld.'}</p>`;
  return `<p class="horse-muted">Kies wie bij deze afspraak betrokken is. Dit geeft geen extra toegang tot het paard. Zonder keuze word je zelf gekoppeld.</p><div class="scope-options">${c.options.map(p=>`<label class="form-field"><span><input type="checkbox" name="participantProfileIds" value="${esc(p.id)}"${c.selected.includes(p.id)?' checked':''}> ${esc(p.name)}</span></label>`).join('')}</div>`;
 }
 async function loadCandidates(c){
  const lookup=++c.lookup,horseId=c.horseId;c.loading=true;c.ready=false;c.manage=false;c.options=[];
  const box=c.form.querySelector('[data-activity-participants]'),submit=c.form.querySelector('button[type="submit"]');
  box.innerHTML='<p role="status">Betrokkenen worden opgehaald…</p>';submit.disabled=true;
  try{
   const result=await client.requestRpc('list_c010_horse_collaboration',{p_horse_id:horseId},{write:false});
   if(!allowed(c)||lookup!==c.lookup||c.horseId!==horseId)return;
   if(result?.horse_id!==horseId||typeof result.can_manage!=='boolean'||!Array.isArray(result.candidates))throw invalid('De betrokkenen konden niet worden gecontroleerd. Probeer opnieuw.');
   c.manage=result.can_manage;
   const options=new Map();
   if(c.manage){
    for(const p of result.candidates){if(!UUID.test(p?.profile_id||'')||typeof p.profile_name!=='string')throw invalid('De betrokkenen konden niet worden gecontroleerd.');options.set(p.profile_id,{id:p.profile_id,name:p.profile_name});}
    const actor=getState().backend.actor;options.set(actor.id,{id:actor.id,name:`Jij · ${actor.name||'Mijn account'}`});
    // A historical participant can disappear from today's candidate list. Keep
    // it selected until an explicit edit; the server still validates on save.
    for(const [index,id] of c.selected.entries())if(!options.has(id))options.set(id,{id,name:`Bestaande betrokkene ${index+1}`});
   }
   c.options=[...options.values()];c.ready=true;box.innerHTML=participantMarkup(c);
  }catch(error){
   if(!current(c)||!owned(c)||lookup!==c.lookup)return;
   if(error?.accessLost||[401,403].includes(error?.status)){
    // Do not disguise an authoritative visibility refusal as a list failure.
    closeModal();try{await onAccessLost(error);}catch{if(current(c))toast('Je toegang kon niet worden gecontroleerd. Meld je opnieuw aan.');}return;
   }
   box.innerHTML='<p>De betrokkenen zijn niet beschikbaar. Je invoer blijft staan.</p><button type="button" class="button-secondary" data-action="activity-retry-participants">Opnieuw ophalen</button>';
   showError(c,invalid('De betrokkenen konden niet worden opgehaald. Probeer opnieuw.'));
  }finally{if(current(c)&&owned(c)&&lookup===c.lookup){c.loading=false;submit.disabled=!c.ready;}}
 }
 function open(id,type){
  syncContext();if(!scope)return;
  const s=getState(),old=id?s.activities.find(a=>a.id===id):null,choices=horses();
  if((id&&!old)||!choices.length||(old&&!choices.some(h=>h.id===old.horseId))){toast('Je kunt deze afspraak niet beheren.');return;}
  const horseId=old?.horseId||(choices.some(h=>h.id===s.horseId)?s.horseId:choices[0].id);
  const a=old?structuredClone(old):{horseId,itemKind:Object.keys(KINDS).find(k=>KINDS[k]===type)||'training',title:'',note:'',date:s.selectedDay||s.today,time:'15:00',end:'16:00',endDate:s.selectedDay||s.today};
  const selected=old?ids(old.participantProfileIds):[s.backend.actor.id];
  showModal(old?'Afspraak aanpassen':'Een nieuwe afspraak',`<form id="core-activity-form"><label class="form-field">Paard<select name="horseId"${old?' disabled':''}>${choices.map(h=>`<option value="${esc(h.id)}"${h.id===horseId?' selected':''}>${esc(h.name)}</option>`).join('')}</select></label><div class="form-grid"><label class="form-field">Activiteit<select name="itemKind">${Object.entries(KINDS).map(([value,label])=>`<option value="${value}"${value===a.itemKind?' selected':''}>${label}</option>`).join('')}</select></label>${field('date','Datum',a.date,'type="date" required')}</div>${field('title','Titel',a.title,'required maxlength="160"')}<div class="form-grid">${field('time','Van',a.time,'type="time" required')}${field('end','Tot, optioneel',a.end,'type="time"')}</div>${field('endDate','Einddatum',a.endDate||a.date,'type="date" required')}<label class="form-field">Plaats en instructie<textarea name="note" maxlength="2000">${esc(a.note||'')}</textarea></label><section class="form-block"><h3>Betrokkenen</h3><div data-activity-participants></div></section><footer class="modal-footer"><button type="button" class="button-secondary" data-action="close-modal">Annuleren</button><button type="submit" class="button-primary" disabled>${icon('check',17)} Afspraak opslaan</button></footer></form>`,'','Planning');
  const form=modal().querySelector('form'),c={scope,generation,form,viewId:modal().dataset.viewId,horseId,old:old?structuredClone(old):null,selected,options:[],lookup:0,ready:false,loading:true,manage:false,draft:null};
  active=c;captures.set(form,c);
  form.addEventListener('change',event=>{
   if(event.target.name!=='horseId'||!allowed(c)||c.old||form.dataset.busy==='true'||form.dataset.uncertain==='true')return;
   const value=event.target.value;if(!horses().some(h=>h.id===value))return;
   c.horseId=value;c.selected=[getState().backend.actor.id];void loadCandidates(c);
  });
  void loadCandidates(c);
 }
 function handleAction(action,button){
  if(action==='new-activity'||action==='edit-activity'){open(action==='edit-activity'?button?.dataset.id:undefined,button?.dataset.type);return true;}
  if(action==='activity-retry-participants'){
   const c=captures.get(button.closest('form'));if(c&&allowed(c)&&!c.loading&&c.form.dataset.busy!=='true'&&c.form.dataset.uncertain!=='true')void loadCandidates(c);return true;
  }return false;
 }
 function handleSubmit(form,event){
  if(form.getAttribute('id')!=='core-activity-form')return false;event.preventDefault();
  const c=captures.get(form);if(!c||!allowed(c)||c.loading||!c.ready||form.dataset.busy==='true')return true;
  try{
   let input=c.draft;
   if(form.dataset.uncertain!=='true'){
    const data=new FormData(form),value=name=>String(data.get(name)||'');
    const selected=c.manage?data.getAll('participantProfileIds').map(String):c.selected;
    const available=new Set(c.options.map(p=>p.id));
    if(selected.length>50||selected.some(id=>!UUID.test(id)||(c.manage&&!available.has(id))))throw invalid('Kies de betrokkenen uit de opgehaalde lijst.');
    input={horseId:c.horseId,itemKind:value('itemKind'),title:value('title'),note:value('note'),date:value('date'),time:value('time'),end:value('end'),endDate:value('endDate'),participantProfileIds:[...new Set(selected)]};
    if(!KINDS[input.itemKind]||!input.title.trim()||input.title.trim().length>160||input.note.length>2000||!validDay(input.date)||!validDay(input.endDate)||!/^([01]\d|2[0-3]):[0-5]\d$/.test(input.time)||input.end&&!/^([01]\d|2[0-3]):[0-5]\d$/.test(input.end))throw invalid('Controleer de titel, datum, tijd en notitie.');
    if(input.end&&`${input.endDate}T${input.end}`<=`${input.date}T${input.time}`)throw invalid('Kies een einddatum en tijd na het begin.');
    if(c.old)Object.assign(input,{id:c.old.id,rowVersion:c.old.rowVersion});
    c.draft=structuredClone(input);
   }
   if(!input)throw stale();
   const captured=structuredClone(input);form.dataset.resultDay=captured.date;
   perform(form,(requestId,isCurrent=()=>true)=>{if(!current(c)||!isCurrent()||!horses().some(h=>h.id===c.horseId))throw stale();return client.saveActivity(structuredClone(captured),requestId);},'Afspraak opgeslagen en opnieuw opgehaald.','planning');
  }catch(error){showError(c,error);}return true;
 }
 return {handleAction,handleSubmit,syncContext};
}
