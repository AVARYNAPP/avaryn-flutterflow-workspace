import {esc} from './components.js';
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TOKEN=/^[a-f0-9]{64}$/;
const one=v=>Array.isArray(v)?v[0]:v;
const rows=v=>{if(!Array.isArray(v))throw Error('De verantwoordelijkheden konden niet worden gecontroleerd.');return v;};
const validKind=v=>['organization','horse'].includes(v);
const footer=label=>`<footer class="modal-footer"><button type="button" class="button-secondary" data-action="close-modal">Later</button><button type="submit" class="button-primary">${label}</button></footer>`;
const unknown=()=>Object.assign(Error('De overdracht is nog niet bevestigd. Probeer dezelfde aanvraag opnieuw of controleer het actuele hoofdbeheer.'),{uncertain:true});
const when=v=>{const date=new Date(v);return Number.isFinite(date.getTime())?date.toLocaleString('nl-NL',{dateStyle:'medium',timeStyle:'short'}):'onbekend';};
const readError=error=>['TRANSFER_NOT_AVAILABLE','TRANSFER_NOT_FOUND'].includes(error?.code)?'Deze code hoort niet bij je bevestigde account, is verlopen of is al gebruikt.':error?.code==='PRIMARY_ORGANIZATION_ADMIN_REQUIRED'||error?.code==='PRIMARY_HORSE_AUTHORITY_REQUIRED'?'Alleen de huidige hoofdbeheerder kan deze overdracht starten.':'De gegevens konden niet worden gecontroleerd. Open dit overzicht opnieuw.';

/** Existing canonical transfers only. Tokens are kept in the originating form's
 * memory; never URLs/storage/logs. Integrate syncContext before every app render
 * and afterSave only inside perform's existing mayFollowUp/owned-modal gate. */
export function createAuthorityTransfer({getState,getBackend,showModal,closeModal,perform,toast}){
 const captures=new WeakMap(),drafts=new WeakMap(),results=new WeakMap();
 let scope='',generation=0,active=null,resources=new Map();
 const context=()=>{const b=getState().backend;return b?.connected&&UUID.test(b.actor?.id||'')?`${b.actor.id}:${b.organizationId||''}`:'';};
 const modal=()=>document.getElementById('modal');
 const owns=view=>!!view&&modal()?.open&&modal()?.dataset.viewId===view.viewId;
 function syncContext(){const next=context();if(next===scope)return;const old=active;scope=next;generation++;resources=new Map();active=null;if(owns(old)){modal().replaceChildren();if(closeModal)closeModal();else modal().close();}}
 const current=view=>{syncContext();return !!scope&&view?.scope===scope&&view.generation===generation;};
 function open(title,body,caption='Hoofdbeheer'){
  showModal(title,body,'',caption);active={scope,generation,viewId:modal().dataset.viewId,form:modal().querySelector('form')};
  if(active.form)captures.set(active.form,active);return active;
 }
 const rpc=(name,params={},write=false)=>getBackend().apiRequest(name,params,{write});
 const key=(kind,id)=>`${kind}:${id}`;
 function error(view,value){if(!current(view)||!owns(view))return;const el=modal().querySelector('[data-authority-message]');if(el){el.hidden=false;el.textContent=readError(value);}else toast(readError(value));}
 function intro(){return '<p>Alleen jij kunt je hoofdbeheer overdragen. De ontvanger kiest zelf of die het overneemt. Tot acceptatie blijf jij verantwoordelijk.</p><p class="horse-muted">Je deelt een eenmalige code zelf; AVARYN verstuurt hier geen e-mail.</p>';}
 const archiveNote=resource=>!resource.archived?'':resource.kind==='horse'?' blijft gearchiveerd. De ontvanger neemt het bestaande hoofdbeheer over.':' blijft een gesloten stal; er ontstaat geen operationele toegang.';
 function option(resource){return `<button class="button-secondary" data-action="authority-transfer-start" data-kind="${resource.kind}" data-id="${esc(resource.id)}">${esc(resource.name)}${resource.archived?(resource.kind==='horse'?' · Gearchiveerd paard':' · Gesloten stal'):''}</button>`;}
 async function hub(){
  syncContext();if(!scope){open('Hoofdbeheer','<p>Meld je aan met je eigen account om verantwoordelijkheden te bekijken.</p>');return;}
  const view=open('Je hoofdverantwoordelijkheden','<p>Je verantwoordelijkheden worden gecontroleerd…</p><p class="form-error" data-authority-message hidden></p>');
  try{
   const [stables,archived,archivedHorses]=await Promise.all([rpc('list_stable_accounts'),rpc('list_c010_my_archived_organizations'),rpc('list_c010_my_archived_horses')]);
   if(!current(view)||!owns(view))return;
   const horseArchive=rows(archivedHorses),archivedIds=new Set(horseArchive.map(h=>h.horse_id));
   const values=[...rows(stables).filter(s=>s.is_primary_authority===true&&s.lifecycle_status==='active').map(s=>({kind:'organization',id:s.organization_id,name:s.name})),...rows(archived).map(s=>({kind:'organization',id:s.organization_id,name:s.name,archived:true})),...(getState().horses||[]).filter(h=>h.capabilities?.primary===true&&h.lifecycleStatus!=='archived'&&!archivedIds.has(h.id)).map(h=>({kind:'horse',id:h.id,name:h.name})),...horseArchive.map(h=>({kind:'horse',id:h.horse_id,name:h.display_name,archived:true}))].filter(r=>UUID.test(r.id));
   resources=new Map(values.map(r=>[key(r.kind,r.id),r]));
   open('Je hoofdverantwoordelijkheden',intro()+`<div class="scope-options">${values.map(option).join('')||'<p>Hier staan geen overdraagbare hoofdverantwoordelijkheden.</p>'}</div><p class="horse-muted">Een gesloten stal blijft gesloten na overdracht. Een gearchiveerd paard blijft gearchiveerd.</p><button class="button-secondary" data-action="authority-transfer-receive">Een overdracht ontvangen</button><p class="form-error" data-authority-message hidden></p>`);
  }catch(e){error(view,e);}
 }
 function resolve(kind,id){
  if(!validKind(kind)||!UUID.test(id||''))return null;
  const s=getState(),saved=resources.get(key(kind,id));if(saved)return saved;
  if(kind==='horse'){const h=s.horses?.find(h=>h.id===id&&h.capabilities?.primary===true&&h.lifecycleStatus!=='archived');return h?{kind,id,name:h.name}:null;}
  const org=s.backend?.organization;return s.backend?.organizationId===id&&org?.primary_authority_profile_id===s.backend.actor.id?{kind,id,name:org.name}:null;
 }
 async function start(kind,id){
  syncContext();if(!scope)return;const resource=resolve(kind,id);if(!resource){toast('Open je actuele hoofdverantwoordelijkheden om een overdracht te starten.');return;}
  const view=open('Hoofdbeheer controleren','<p>Het actuele hoofdbeheer wordt gecontroleerd…</p><p class="form-error" data-authority-message hidden></p>');
  try{
   let pending;
   if(resource.archived){
    const value=rows(await rpc(kind==='horse'?'list_c010_my_archived_horses':'list_c010_my_archived_organizations')).find(s=>s[kind==='horse'?'horse_id':'organization_id']===id);
    if(!current(view)||!owns(view))return;
    if(!value)throw Error('Unavailable');pending=value.pending_transfer;resource.name=value[kind==='horse'?'display_name':'name'];
   }
   else{
    const [workspace,horseRows]=kind==='horse'?await Promise.all([rpc('get_canonical_horse_workspace',{p_horse_id:id}),rpc('list_c010_horses')]):[await rpc('get_stable_account_workspace',{p_organization_id:id}),null];
    if(!current(view)||!owns(view))return;
    const entity=kind==='horse'?rows(horseRows).find(h=>h.horse_id===id&&h.lifecycle_status==='active'):workspace?.organization;
    if(!entity||(entity.primary_authority_profile_id!==getState().backend?.actor?.id&&entity.is_primary_authority!==true))throw Error('Unavailable');
    pending=workspace[kind==='horse'?'pending_transfer':'pending_authority_transfer'];
   }
   if(!current(view)||!owns(view))return;
   if(pending?.status==='pending'&&UUID.test(pending.id)&&Number.isSafeInteger(pending.row_version)&&pending.row_version>0){
    const next=open('Overdracht wacht op acceptatie',`<p>Voor ${esc(resource.name)} staat een overdracht naar ${esc(pending.recipient_name||'de gekozen ontvanger')} open.</p><p>Geldig tot ${esc(when(pending.expires_at))}. Jij blijft hoofdbeheerder totdat de ontvanger accepteert.</p>${resource.archived?`<p class="horse-muted">${esc(resource.name)}${archiveNote(resource)}</p>`:''}<p class="horse-muted">Een al uitgegeven code wordt niet opnieuw getoond. Ben je die kwijt, trek de aanvraag eerst in en maak daarna een nieuwe.</p><form id="core-authority-revoke-form"><p>Wil je deze overdracht intrekken?</p>${footer('Overdracht intrekken')}</form>`,resource.name);
    Object.assign(next,{kind,id,resource,pending});return;
   }
   const next=open('Hoofdbeheer overdragen',intro()+`<p><strong>${esc(resource.name)}</strong>${archiveNote(resource)}</p><form id="core-authority-start-form"><label class="form-field">Bevestigd e-mailadres van de ontvanger<input name="email" type="email" autocomplete="email" required></label><label class="form-field"><span><input name="confirm" type="checkbox" value="yes" required> Ik wil het hoofdbeheer aan deze persoon aanbieden.</span></label>${footer('Overdracht aanbieden')}</form>`,resource.name);Object.assign(next,{kind,id,resource});
  }catch(e){error(view,e);}
 }
 function receive(kind='organization'){
  syncContext();if(!scope)return;
  open('Overdracht ontvangen',`<form id="core-authority-preview-form"><label class="form-field">Waarvoor is de code?<select name="kind"><option value="organization"${kind==='organization'?' selected':''}>Stal</option><option value="horse"${kind==='horse'?' selected':''}>Paard</option></select></label><label class="form-field">Eenmalige overdrachtcode<input name="token" autocomplete="off" autocapitalize="none" spellcheck="false" required></label><p class="horse-muted">Gebruik het account met het bevestigde e-mailadres waarvoor de overdracht is bedoeld. Controleren accepteert nog niets.</p><p class="form-error" data-authority-message hidden></p>${footer('Code controleren')}</form>`);
 }
 async function preview(view,f){
  if(view.checking)return;
  if(!validKind(f.kind)||!TOKEN.test(f.token||'')){toast('Kies stal of paard en plak de volledige eenmalige code.');return;}
  view.checking=true;const controls=[...view.form.querySelectorAll('input,select,button[type="submit"]')].map(c=>[c,c.disabled]);for(const [c] of controls)c.disabled=true;
  try{
   const p=one(await rpc(f.kind==='horse'?'preview_horse_authority_transfer':'preview_organization_authority_transfer',{p_transfer_token:f.token}));
   if(!current(view)||!owns(view))return;
   const id=p?.[f.kind==='horse'?'horse_id':'organization_id'];if(!UUID.test(id||'')||!UUID.test(p?.transfer_id||''))throw Object.assign(Error('Unavailable'),{code:'TRANSFER_NOT_AVAILABLE'});
   const name=p[f.kind==='horse'?'horse_name':'organization_name'];
   const next=open('Hoofdbeheer overnemen?',`<p>Wil je hoofdbeheerder van <strong>${esc(name)}</strong> worden? Na acceptatie draag jij de hoofdverantwoordelijkheid. ${f.kind==='horse'?'Is dit paard gearchiveerd, dan blijft het gearchiveerd.':'Een gesloten stal blijft gesloten.'}</p><p>De code is geldig tot ${esc(when(p.expires_at))}.</p><form id="core-authority-response-form"><label class="form-field">Jouw keuze<select name="response" required><option value="">Kies wat je wilt doen</option><option value="accept">Hoofdbeheer accepteren</option><option value="decline">Overdracht weigeren</option></select></label>${footer('Keuze bevestigen')}</form>`);
   Object.assign(next,{kind:f.kind,id,token:f.token,transferId:p.transfer_id,name});
  }catch(e){error(view,e);}finally{view.checking=false;for(const [c,disabled] of controls)if(c.isConnected)c.disabled=disabled;}
 }
 function handleAction(action,button={dataset:{}}){
  if(!['authority-transfer','authority-transfer-start','authority-transfer-receive'].includes(action))return false;
  syncContext();if(action==='authority-transfer')void hub();else if(scope){if(action==='authority-transfer-start')void start(button.dataset.kind,button.dataset.id);else receive(button.dataset.kind);}return true;
 }
 function handleSubmit(form,event){
  if(!['core-authority-start-form','core-authority-preview-form','core-authority-response-form','core-authority-revoke-form'].includes(form.getAttribute('id')))return false;
  event.preventDefault();const view=captures.get(form);if(!current(view)||!owns(view)||form!==view.form||!form.isConnected)return true;
  const f=form.dataset.uncertain==='true'?drafts.get(form):Object.fromEntries(new FormData(form));if(!f)return true;drafts.set(form,f);
  if(form.id==='core-authority-preview-form'){void preview(view,{kind:f.kind,token:f.token?.trim()});return true;}
  if(form.id==='core-authority-start-form'&&(f.confirm!=='yes'||!/^\S+@\S+\.\S+$/.test(f.email?.trim()||''))){toast('Vul het bevestigde e-mailadres in en bevestig je keuze.');return true;}
  if(form.id==='core-authority-response-form'&&!['accept','decline'].includes(f.response)){toast('Kies eerst accepteren of weigeren.');return true;}
  perform(form,async(requestId,isCurrent=()=>true)=>{
   if(!current(view)||!isCurrent())throw Error('Open dit formulier opnieuw voor je huidige account.');
   if(results.has(form))return;
   let result;
   if(form.id==='core-authority-start-form'){
    result=one(await rpc(view.kind==='horse'?'initiate_horse_authority_transfer_by_email':'initiate_organization_authority_transfer_by_email',{[view.kind==='horse'?'p_horse_id':'p_organization_id']:view.id,p_recipient_email:f.email.trim(),p_correlation_id:requestId},true));
    if(!UUID.test(result?.transfer_id||'')||!Number.isSafeInteger(result.row_version)||result.row_version<1)throw unknown();
   }else if(form.id==='core-authority-response-form'){
    result=one(await rpc(view.kind==='horse'?'respond_horse_authority_transfer':'respond_stable_authority_transfer',{p_transfer_token:view.token,p_action:f.response,p_correlation_id:requestId},true));
    if(result?.transfer_id!==view.transferId||!Number.isSafeInteger(result.row_version)||result.row_version<1||!['accepted','declined','expired'].includes(result?.status)||(result.status!=='expired'&&result.status!==(f.response==='accept'?'accepted':'declined')))throw unknown();
   }else{
    result=one(await rpc(view.kind==='horse'?'revoke_horse_authority_transfer':'revoke_organization_authority_transfer',{p_transfer_id:view.pending.id,p_expected_row_version:view.pending.row_version,p_correlation_id:requestId},true));
    if(!Number.isSafeInteger(result?.row_version)||result.row_version<1||!['revoked','expired'].includes(result?.status))throw unknown();
   }
   if(current(view)&&isCurrent())results.set(form,{...result,view});
  },form.id==='core-authority-start-form'?'De overdrachtsaanvraag is gecontroleerd.':'De overdracht is gecontroleerd.');return true;
 }
 function afterSave(form){
  const result=results.get(form);if(!result)return;results.delete(form);drafts.delete(form);const view=result.view;
  if(!current(view)||(modal()?.open&&!owns(view)))return;
  if(form.id==='core-authority-start-form'){
   open('Overdracht aangeboden',TOKEN.test(result.transfer_token||'')?`<p>De ontvanger moet nog accepteren. Deel deze eenmalige code zelf met de gekozen persoon. Er is geen e-mail verstuurd. Na sluiten tonen we de code niet opnieuw.</p><label class="form-field">Eenmalige overdrachtcode<textarea readonly autocomplete="off">${esc(result.transfer_token)}</textarea></label><p>Geldig tot ${esc(when(result.expires_at))}.</p>`:'<p>De bestaande aanvraag is teruggevonden. De code wordt niet opnieuw getoond. Controleer de open overdracht; trek die zo nodig eerst in voordat je een nieuwe maakt.</p>');
  }else open('Overdracht verwerkt',`<p>${result.status==='accepted'?'Je hebt het hoofdbeheer overgenomen.':result.status==='declined'?'Je hebt de overdracht geweigerd.':result.status==='revoked'?'De overdracht is ingetrokken.':'De overdracht is verlopen; er is geen hoofdbeheer overgenomen.'}</p><button class="button-secondary" data-action="authority-transfer">Hoofdverantwoordelijkheden bekijken</button>`);
 }
 return {handleAction,handleSubmit,syncContext,afterSave};
}
