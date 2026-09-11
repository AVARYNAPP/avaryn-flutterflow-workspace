import {esc,icon} from './components.js';
const footer=label=>`<footer class="modal-footer"><button type="button" class="button-secondary" data-action="close-modal">Annuleren</button><button type="submit" class="button-primary">${icon('check',17)} ${label}</button></footer>`;
const input=(name,label,value='',extra='')=>`<label class="form-field">${label}<input name="${name}" value="${esc(value??'')}" ${extra}></label>`;
const one=value=>Array.isArray(value)?value[0]:value;

/** Canonical account/core forms share the existing modal and write/readback gate. */
export function createAccountCore({getState,showModal:renderModal,perform,apiRequest}){
 const drafts=new WeakMap(),captures=new WeakMap();
 const showModal=(...args)=>{renderModal(...args);const form=document.querySelector('#modal form');if(form)captures.set(form,getState().backend);};
 const rpc=(name,args)=>apiRequest(name,args,{write:true});
 function horseForm(){
  showModal('Een paard toevoegen',`<form id="core-horse-form">${input('name','Roepnaam','','required maxlength="160"')}${input('officialName','Officiële naam, optioneel','','maxlength="200"')}<div class="form-grid">${input('birthDate','Geboortedatum, optioneel','','type="date"')}<label class="form-field">Geslacht<select name="sex"><option value="unknown">Onbekend</option><option value="mare">Merrie</option><option value="gelding">Ruin</option><option value="stallion">Hengst</option></select></label></div>${input('breed','Ras, optioneel','','maxlength="160"')}<div class="form-grid">${input('discipline','Discipline, optioneel','','maxlength="120"')}${input('level','Niveau, optioneel','','maxlength="120"')}</div><label class="form-field">Goed om te weten<textarea name="notes" maxlength="2000"></textarea></label><p class="horse-muted">Jij beheert dit paard. Toegang voor anderen regel je daarna afzonderlijk.</p>${footer('Paard toevoegen')}</form>`,'','Jouw paarden');
 }
 function stableForm(edit=false){
  const state=getState(),s=edit?state.backend.organization:{};
  if(edit&&!state.backend.capabilities.canManage)return;
  showModal(edit?'Stalgegevens':'Een stal aanmaken',`<form id="core-stable-form" data-edit="${edit}" data-version="${s?.row_version||''}">${input('name','Naam van de stal',s?.name,'required maxlength="160"')}${input('location','Locatie',s?.location_name,'maxlength="240"')}${edit?`${input('address','Adres, optioneel',s?.address_line,'maxlength="240"')}${input('locality','Plaats',s?.locality,'maxlength="160"')}`:''}<p class="horse-muted">${edit?'Wijzig de gegevens die jouw stalteam ziet.':'Je wordt beheerder van deze stal. Daarna kun je je team uitnodigen.'}</p>${footer(edit?'Stal opslaan':'Stal aanmaken')}</form>`,'','Jouw stal');
 }
 function profileForm(){
  const p=getState().backend.profile;
  showModal('Jouw gegevens',`<form id="core-profile-form" data-version="${p.row_version}"><div class="form-grid">${input('firstName','Voornaam',p.first_name,'required maxlength="120" autocomplete="given-name"')}${input('lastName','Achternaam',p.last_name,'maxlength="160" autocomplete="family-name"')}</div>${input('phone','Telefoon, optioneel',p.phone_e164,'type="tel" autocomplete="tel" placeholder="+31612345678"')}<label class="form-field">Waarvoor gebruik je AVARYN?<select name="intent">${[['individualHorse','Mijn paard(en)'],['createStable','Een stal beheren'],['joinStable','Meedoen op een stal']].map(([v,t])=>`<option value="${v}"${p.onboarding_intent===v?' selected':''}>${t}</option>`).join('')}</select></label><p class="horse-muted">Deze keuze geeft geen extra toegang tot paarden of stallen.</p>${footer('Gegevens opslaan')}</form>`,'','Jouw profiel');
 }
 function handleAction(action){
  if(!getState().backend?.connected)return false;
  if(action==='new-horse'){horseForm();return true;}
  if(action==='create-stable'){stableForm();return true;}
  if(action==='manage-stable'){stableForm(true);return true;}
  if(action==='edit-profile'){profileForm();return true;}
  return false;
 }
 function handleSubmit(form,event){
  if(!['core-horse-form','core-stable-form','core-profile-form'].includes(form.id))return false;
  event.preventDefault();if(captures.get(form)!==getState().backend||!form.isConnected||document.getElementById(form.id)!==form)return true;
  const f=form.dataset.uncertain==='true'?drafts.get(form):Object.fromEntries(new FormData(form)),s=getState();
  if(!f)return true;drafts.set(form,f);
  if(form.id==='core-horse-form')perform(form,async requestId=>{
   const result=one(await rpc('create_canonical_horse_profile',{p_display_name:f.name.trim(),p_official_name:f.officialName||null,p_birth_date:f.birthDate||null,p_sex:f.sex,p_breed:f.breed||null,p_discipline:f.discipline||null,p_level:f.level||null,p_color:null,p_notes:f.notes||null,p_chip_number:null,p_passport_number:null,p_passport_valid_until:null,p_correlation_id:requestId}));
   if(!result?.horse_id)throw Object.assign(Error('Paardaanmaak is nog niet bevestigd. Laad je paarden opnieuw.'),{uncertain:true});
   form.dataset.resultHorseId=result.horse_id;
  },'Je paard is toegevoegd.','horse-overview');
  if(form.id==='core-stable-form')perform(form,async requestId=>{
   const edit=form.dataset.edit==='true';
   const result=await rpc(edit?'update_c010_stable':'create_c010_stable',edit?{p_organization_id:s.backend.organizationId,p_expected_row_version:Number(form.dataset.version),p_name:f.name.trim(),p_location_name:f.location,p_address_line:f.address,p_locality:f.locality,p_request_id:requestId}:{p_name:f.name.trim(),p_location_name:f.location,p_request_id:requestId});
   if(!result?.organization_id)throw Object.assign(Error('Stal opslaan is nog niet bevestigd. Laad je stallen opnieuw.'),{uncertain:true});
   form.dataset.resultOrganizationId=result.organization_id;
  },'Je stal is opgeslagen.','stable');
  if(form.id==='core-profile-form')perform(form,async requestId=>{
   const p=s.backend.profile;
   const result=one(await rpc('update_current_account_profile',{p_expected_row_version:Number(form.dataset.version),p_first_name:f.firstName.trim(),p_last_name:f.lastName.trim(),p_phone_e164:f.phone||null,p_locale:p.locale==='und'?'nl-NL':p.locale,p_time_zone:p.onboarding_completed_at?p.time_zone:Intl.DateTimeFormat().resolvedOptions().timeZone,p_theme_mode:p.theme_mode,p_onboarding_intent:f.intent,p_complete_onboarding:true,p_avatar_object_path:p.avatar_object_path,p_correlation_id:requestId}));
   if(result?.profile_id!==p.profile_id||!Number.isSafeInteger(result.row_version)||result.row_version<Number(form.dataset.version)||result.row_version===Number(form.dataset.version)&&result.result_code!=='no_change')throw Object.assign(Error('Je profielwijziging is nog niet bevestigd. Controleer de actuele gegevens.'),{uncertain:true});
  },'Je gegevens zijn opgeslagen.');
  return true;
 }
 return {handleAction,handleSubmit,profileForm};
}
