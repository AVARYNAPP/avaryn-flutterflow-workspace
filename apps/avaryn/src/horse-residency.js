import {esc,icon} from './components.js';

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const version=value=>Number.isSafeInteger(value)&&value>0;
const footer=label=>`<footer class="modal-footer"><button type="button" class="button-secondary" data-action="close-modal">Annuleren</button><button type="submit" class="button-primary">${icon('check',17)} ${label}</button></footer>`;
const close='<button class="button-primary" data-action="close-modal">Gereed</button>';
const uncertain=()=>Object.assign(Error('Opslaan is nog niet bevestigd. Controleer de actuele verblijfplaats en probeer opnieuw.'),{code:'INVALID_RESPONSE',uncertain:true});
const stale=()=>Object.assign(Error('Je account of stal is veranderd. Open de verblijfplaats opnieuw.'),{code:'STALE_CONTEXT'});
const messages={STALE_RESIDENCY_VERSION:'De verblijfplaats is intussen gewijzigd. Sluit dit formulier en open de actuele verblijfplaats.',C010_PLACE_VERSION_STALE:'De stalplaats is intussen gewijzigd. Sluit dit formulier en open de actuele stalplaats.',C010_PLACE_OCCUPIED:'Deze stalplaats is al in gebruik. Kies een andere beschikbare plek.',C010_FACILITY_UNAVAILABLE:'Deze plek is niet meer beschikbaar. Open de actuele stalplaatsen.',C010_HORSE_CONTEXT_REQUIRED:'Dit paard heeft hier geen actuele verblijfplaats of je hebt geen toegang tot het paard.',C010_PLACE_MANAGE_REQUIRED:'De stalbeheerder wijst een stalplaats toe. Je hebt daarvoor nu geen rechten.'};

/** Informative residency and a separate, authorized box assignment. No grants.
 * perform is the existing controller's write/authoritative-load gate. Form IDs
 * start with core- so uncertain retries keep their original values/request ID.
 */
export function createHorseResidency({getState,showModal,perform,apiRequest,toast}){
 const captures=new WeakMap(),drafts=new WeakMap(),acknowledgements=new WeakMap();
 let pending=0;
 const visibleHorse=id=>getState().horses?.find(h=>h.id===id&&h.lifecycleStatus!=='archived');
 const placePermission=()=>getState().backend?.permissionCodes?.['organization.residencies.manage']===true;
 const scope=()=>{const b=getState().backend;return {backend:b,actor:b?.actor?.id,organization:b?.organizationId??null};};
 const sameScope=c=>getState().backend===c.backend&&scope().actor===c.actor&&scope().organization===c.organization&&getState().backend?.connected===true;
 const current=c=>sameScope(c)&&Boolean(visibleHorse(c.horseId));
 function formCurrent(form,c){const modal=document.querySelector('#modal');return c&&current(c)&&form.isConnected&&document.getElementById(form.id)===form&&modal?.open&&modal.dataset.viewId===c.viewId&&modal.contains(form);}
 const rpc=async(name,args,write=false)=>{try{return await apiRequest(name,args,{write});}catch(error){if(messages[error?.code])error.message=error.userMessage=messages[error.code];throw error;}};
 function error(form,message){let el=form.querySelector('.form-error');if(!el){el=document.createElement('p');el.className='form-error';el.setAttribute('role','alert');form.prepend(el);}el.textContent=message;el.scrollIntoView?.({block:'nearest'});}
 function readCollaboration(value,horseId){
  const r=value?.current_residency;
  if(value?.horse_id!==horseId||typeof value.can_manage!=='boolean'||!Array.isArray(value.stable_options)||
   !Object.hasOwn(value,'current_residency')||(r!==null&&(!UUID.test(r?.id||'')||!UUID.test(r?.organization_id||'')||!version(r.row_version)))||
   value.stable_options.some(o=>!UUID.test(o.organization_id||'')))throw Error('De actuele verblijfplaats kon niet worden geladen. Probeer opnieuw.');
  return value;
 }
 function readPlaces(value,c){
  if(value?.profile_id!==c.actor||value.organization_id!==c.organization||!Array.isArray(value.resources)||!Array.isArray(value.placements)||!value.placementVersions||typeof value.placementVersions!=='object')throw Error('De actuele stalplaatsen konden niet worden geladen. Probeer opnieuw.');
  return value;
 }
 function openForm(title,body,c){
  showModal(title,body,'',visibleHorse(c.horseId)?.name||'Verblijfplaats');
  const form=document.querySelector('#modal form'),modal=document.querySelector('#modal');
  if(form)captures.set(form,{...c,viewId:modal.dataset.viewId});
 }
 function renderResidency(c){
  const data=c.collaboration,r=data.current_residency,horse=visibleHorse(c.horseId);
  const placeAction=r&&r.organization_id===c.organization&&placePermission()?`<button type="button" class="text-link" data-action="horse-placement" data-horse="${esc(c.horseId)}">${icon('box',17)} Stalplaats kiezen</button>`:'';
  if(!data.can_manage){showModal('Verblijfplaats',`<p><strong>${esc(horse.name)}</strong> verblijft ${r?`bij ${esc(r.organization_name)}`:'nog niet op een gekoppelde stal'}.</p><p class="horse-muted">De paardbeheerder kiest de verblijfstal. Een verblijfplaats geeft geen toegang tot het paard of de stal.</p>${placeAction}`,close,'Verblijfplaats');return;}
  const options=[...data.stable_options];
  if(r&&!options.some(o=>o.organization_id===r.organization_id))options.unshift({organization_id:r.organization_id,name:r.organization_name,location_name:r.location_name});
  openForm('Verblijfplaats',`<form id="core-residency-form"><p>Waar verblijft <strong>${esc(horse.name)}</strong>?</p><label class="form-field">Stal<select name="organizationId"><option value=""${!r?' selected':''}>Geen stal gekoppeld</option>${options.map(o=>`<option value="${esc(o.organization_id)}"${o.organization_id===r?.organization_id?' selected':''}>${esc(o.name)}${o.location_name?` · ${esc(o.location_name)}`:''}</option>`).join('')}</select></label>${!data.stable_options.length?'<p class="horse-muted">Er zijn geen andere toegankelijke stallen om te kiezen. Vraag de stalbeheerder om je uit te nodigen als je wilt aansluiten.</p>':''}<p class="horse-muted">De verblijfplaats verleent geen toegang tot het paard of de stal. Een stalplaats of box wordt apart toegewezen door iemand met stalplaatsrechten.${r?' Bij wijzigen of verwijderen van de verblijfstal vervalt de bestaande stalplaats.':''}</p>${placeAction}${footer('Verblijfplaats opslaan')}</form>`,c);
 }
 function availablePlaces(workspace,horseId){return workspace.resources.filter(r=>UUID.test(r.id||'')&&r.kind==='stall'&&r.status==='available'&&!workspace.placements.some(p=>p.resourceId===r.id&&p.horseId!==horseId)&&(!r.occupied||workspace.placements.some(p=>p.resourceId===r.id&&p.horseId===horseId&&!p.redacted)));}
 function renderPlacement(c){
  const w=c.workspace,old=w.placements.find(p=>p.horseId===c.horseId&&!p.redacted),options=availablePlaces(w,c.horseId);
  if(!options.length&&!old){showModal('Stalplaats', '<p>Er is nu geen beschikbare stalplaats. De stalbeheerder kan plekken toevoegen of een plek vrijmaken.</p>',close,visibleHorse(c.horseId)?.name);return;}
  openForm('Stalplaats kiezen',`<form id="core-horse-place-form"><p>Een plek voor <strong>${esc(visibleHorse(c.horseId).name)}</strong> bij ${esc(c.collaboration.current_residency.organization_name)}.</p><label class="form-field">Stalplaats<select name="resourceId"${old?'':' required'}><option value=""${!old?' selected':''}>${old?'Stalplaats vrijmaken':'Kies een beschikbare plek'}</option>${old&&!options.some(o=>o.id===old.resourceId)?`<option value="${esc(old.resourceId)}" selected>Huidige plek is niet beschikbaar; kies opnieuw</option>`:''}${options.map(r=>`<option value="${esc(r.id)}"${old?.resourceId===r.id?' selected':''}>${esc(r.name)}</option>`).join('')}</select></label><label class="form-field">Instructie voor deze plek<textarea name="note" maxlength="2000">${esc(old?.note||'')}</textarea></label><p class="horse-muted">Dit verandert geen paard- of stalrechten. Vrijmaken beëindigt alleen de stalplaats, niet de verblijfstal.</p>${footer('Stalplaats opslaan')}</form>`,{...c,oldPlacement:old||null,available:options});
 }
 async function open(horseId,placement=false){
  if(!getState().backend?.connected||!UUID.test(horseId||'')||!visibleHorse(horseId))return;
  const c={...scope(),horseId},ticket=++pending;
  showModal(placement?'Stalplaats':'Verblijfplaats','<p role="status">Actuele gegevens laden…</p>',close,visibleHorse(horseId).name);
  const modal=document.querySelector('#modal'),viewId=modal?.dataset.viewId;
  const owns=()=>ticket===pending&&current(c)&&modal?.open&&modal.dataset.viewId===viewId;
  try{
   const value=await rpc('list_c010_horse_collaboration',{p_horse_id:horseId});
   if(!owns())return;c.collaboration=readCollaboration(value,horseId);
   if(!placement){renderResidency(c);return;}
   const r=c.collaboration.current_residency;
   if(!r){showModal('Stalplaats','<p>Kies eerst de verblijfstal van dit paard.</p>',`<button class="button-primary" data-action="horse-residency" data-horse="${esc(horseId)}">Verblijfplaats bekijken</button>`);return;}
   if(r.organization_id!==c.organization||!placePermission()){
    showModal('Stalplaats','<p>Een stalplaats toewijzen kan alleen in de actuele verblijfstal, met toegang tot dit paard en rechten om stalplaatsen te beheren. Vraag de stalbeheerder om de plek toe te wijzen.</p>',r.organization_id!==c.organization&&getState().backend.organizations?.some(o=>o.id===r.organization_id)?`<button class="button-primary" data-action="select-stable" data-id="${esc(r.organization_id)}">Verblijfstal openen</button>`:close);return;
   }
   const workspace=await rpc('get_c010_facility_workspace',{p_organization_id:c.organization,p_on_date:null});
   if(!owns())return;c.workspace=readPlaces(workspace,c);renderPlacement(c);
  }catch(e){if(owns())showModal('Gegevens niet geladen',`<p role="alert">${esc(e.userMessage||'De actuele gegevens zijn tijdelijk niet beschikbaar. Probeer opnieuw.')}</p>`,close);}
 }
 function handleAction(action,button){if(!['horse-residency','horse-placement'].includes(action)||!getState().backend?.connected)return false;void open(button?.dataset?.horse||getState().horseId,action==='horse-placement');return true;}
 function handleSubmit(form,event){
  if(!['core-residency-form','core-horse-place-form'].includes(form.id))return false;
  event.preventDefault();const c=captures.get(form);
  if(!formCurrent(form,c)){toast('Open dit formulier opnieuw voor je huidige account en stal.');return true;}
  const values=form.dataset.uncertain==='true'?drafts.get(form):Object.fromEntries(new FormData(form));
  if(!values){error(form,'Open het formulier opnieuw om de actuele gegevens te laden.');return true;}
  const residency=form.id==='core-residency-form',r=c.collaboration.current_residency;
  let params;
  if(residency){
   const chosen=values.organizationId||null;
   if(!c.collaboration.can_manage||!Object.hasOwn(values,'organizationId')||(chosen!==r?.organization_id&&chosen&&!c.collaboration.stable_options.some(o=>o.organization_id===chosen))){error(form,'Kies een toegankelijke stal uit de lijst.');return true;}
   if(chosen===(r?.organization_id||null)){error(form,'Dit is al de huidige verblijfplaats.');return true;}
   params={p_horse_id:c.horseId,p_stable_organization_id:chosen,p_expected_residency_row_version:r?.row_version??null};
  }else{
   const chosen=values.resourceId||null,expected=c.workspace.placementVersions[c.horseId]??null;
   if(!placePermission()||r?.organization_id!==c.organization){error(form,'Je kunt hier geen stalplaats toewijzen. Open de actuele verblijfplaats.');return true;}
   if(!Object.hasOwn(values,'resourceId')||(chosen&&!c.available.some(p=>p.id===chosen))||(!chosen&&!c.oldPlacement)){error(form,'Kies een beschikbare stalplaats.');return true;}
   if(expected!==null&&!version(expected)){error(form,'De versie van deze plek ontbreekt. Open het formulier opnieuw.');return true;}
   if(String(values.note||'').length>2000){error(form,'Gebruik maximaal 2000 tekens voor de instructie.');return true;}
   params={p_organization_id:c.organization,p_horse_id:c.horseId,p_stable_place_id:chosen,p_expected_row_version:expected,p_note:values.note||''};
  }
  drafts.set(form,values);
  void perform(form,async(requestId,isCurrent=()=>true)=>{
   const active=()=>isCurrent()&&current(c);
   if(!active())throw stale();
   let ack=acknowledgements.get(form);
   if(!ack||ack.requestId!==requestId){
    const result=await rpc(residency?'set_c010_horse_residency':'set_c010_horse_place',{...params,p_request_id:requestId},true);
    if(!active())throw stale();
    const valid=residency?(result?.horse_id===c.horseId&&result.organization_id===params.p_stable_organization_id&&(params.p_stable_organization_id?(result.status==='active'&&UUID.test(result.residency_id||'')&&version(result.row_version)):(result.status==='unlinked'&&result.residency_id===null))):(result?.horse_id===c.horseId&&result.resource_id===params.p_stable_place_id&&result.status===(params.p_stable_place_id?'active':'ended')&&version(result.row_version)&&result.row_version>(params.p_expected_row_version??0));
    if(!valid)throw uncertain();
    ack={requestId,result};acknowledgements.set(form,ack);
   }
   // Keep an acknowledged write in memory if its own readback fails. A retry
   // then repeats only the read before perform's full authoritative core load.
   try{
    if(residency){
     const actual=readCollaboration(await rpc('list_c010_horse_collaboration',{p_horse_id:c.horseId}),c.horseId);
     if(!active())throw stale();const rr=actual.current_residency;
     if(params.p_stable_organization_id?(!rr||rr.organization_id!==ack.result.organization_id||rr.id!==ack.result.residency_id||rr.row_version!==ack.result.row_version):rr!==null)throw uncertain();
    }else{
     const actual=readPlaces(await rpc('get_c010_facility_workspace',{p_organization_id:c.organization,p_on_date:null}),c);
     if(!active())throw stale();const place=actual.placements.find(p=>p.horseId===c.horseId&&!p.redacted);
     if(actual.placementVersions[c.horseId]!==ack.result.row_version||(params.p_stable_place_id?(!place||place.resourceId!==params.p_stable_place_id||place.rowVersion!==ack.result.row_version||place.note!==params.p_note):Boolean(place)))throw uncertain();
    }
   }catch(e){e.uncertain=true;throw e;}
   form.dataset.resultHorseId=c.horseId;
  },residency?'De verblijfplaats is opgeslagen en opnieuw gecontroleerd.':'De stalplaats is opgeslagen en opnieuw gecontroleerd.','horse-overview');
  return true;
 }
 return {handleAction,handleSubmit,open};
}
