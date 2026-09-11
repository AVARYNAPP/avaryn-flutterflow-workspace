const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const organizationBlocks=new Set(['PRIMARY_ORGANIZATION_ADMIN_REQUIRED','PRIMARY_ORGANIZATION_AUTHORITY_REQUIRES_TRANSFER','ACTIVE_STABLE_OWNER_REQUIRES_TRANSFER','ACTIVE_MEMBERSHIPS_REQUIRE_RESOLUTION']);
const horseBlocks=new Set(['PRIMARY_HORSE_AUTHORITY_REQUIRED','PRIMARY_HORSE_AUTHORITY_REQUIRES_TRANSFER']);
const reviewBlocks=new Set(['LEGACY_RETENTION_REQUIRED','ACCOUNT_HISTORY_REQUIRES_ADMIN_REVIEW','ACCOUNT_LEGACY_HISTORY_REQUIRES_REVIEW','CANONICAL_PROFILE_REQUIRED']);
const storageBlocks=new Set(['STORAGE_OWNERSHIP_UNSUPPORTED','AVATAR_CLEANUP_REQUIRES_ADMIN_REVIEW','STORAGE_OWNERSHIP_REQUIRES_REVIEW']);
const blocked=code=>organizationBlocks.has(code)||horseBlocks.has(code)||reviewBlocks.has(code)||storageBlocks.has(code)||['APPLE_REVOCATION_NOT_CONFIGURED','ACCOUNT_DELETION_STATE_UNSUPPORTED','ACCOUNT_DELETION_LIFECYCLE_NOT_READY','DELETION_REQUEST_CONFLICT','REQUEST_ID_REUSED'].includes(code);
const uncertainText='De verwijdering is nog niet bevestigd. Probeer dezelfde aanvraag opnieuw.';
function explanation(code){
 if(organizationBlocks.has(code))return 'Draag eerst je hoofdverantwoordelijkheid voor de stal over aan een andere actieve beheerder. Die persoon moet de overdracht accepteren. Alleen de stal archiveren is niet voldoende. Controleer ook je andere stallen.';
 if(horseBlocks.has(code))return 'Draag eerst je hoofdverantwoordelijkheid voor je paard over aan een andere actieve persoon. Die persoon moet de overdracht accepteren. Alleen het paard archiveren is niet voldoende.';
 if(reviewBlocks.has(code))return 'Oudere accountkoppelingen of bewaarde historie verhinderen veilige verwijdering. AVARYN-beheer moet dit eerst controleren en waar nodig migreren. Je account is niet verwijderd.';
 if(storageBlocks.has(code))return 'De gekoppelde bestanden kunnen nog niet veilig worden afgehandeld. Laat AVARYN-beheer dit eerst controleren. Je account is niet verwijderd.';
 if(code==='APPLE_REVOCATION_NOT_CONFIGURED')return 'Verwijderen van een account met Apple is nog niet volledig aangesloten. Eerst moet de Apple-koppeling veilig kunnen worden ingetrokken. Je account is niet verwijderd.';
 if(['ACCOUNT_DELETION_STATE_UNSUPPORTED','ACCOUNT_DELETION_LIFECYCLE_NOT_READY'].includes(code))return 'Deze accountstatus kan nog niet veilig worden afgehandeld. Laat AVARYN-beheer de verwijdering controleren. Je account is niet verwijderd.';
 if(['DELETION_REQUEST_CONFLICT','REQUEST_ID_REUSED'].includes(code))return 'Deze aanvraag komt niet overeen met de bestaande verwijderaanvraag. Laat AVARYN-beheer de aanvraag controleren; de verwijdering is niet bevestigd.';
 if(['INVALID_SESSION','AUTHENTICATION_REQUIRED','SESSION_EXPIRED'].includes(code))return 'Je sessie is niet meer beschikbaar. De verwijdering is hiermee niet bevestigd. Meld je opnieuw aan als dat nog kan, of laat AVARYN-beheer de aanvraag controleren.';
 if(code==='ACCOUNT_DELETION_PENDING')return 'Je verwijderaanvraag is in behandeling. Afronding is nog niet bevestigd en je gewone accounttoegang kan al zijn beëindigd. Je kunt dezelfde aanvraag opnieuw proberen; als aanmelden niet meer lukt, moet AVARYN-beheer de bestaande aanvraag afronden.';
 return uncertainText;
}

/** Own-account deletion only. No Storage calls, client resume, or durable token storage.
 * Call syncContext on every app render (including logout). clearSession must clear
 * the captured actor locally; any delayed work in that callback must use isCurrent.
 * onPending can purge operational presentation while retaining the status/session.
 */
export function createAccountLifecycle({getState,getBackend,showModal,closeModal,clearSession,navigate,esc=escape,onPending=()=>{}}){
 let scope='',generation=0,active=null,record=null,flight=null;
 const actor=()=>{const b=getState().backend;return b?.connected===true&&UUID.test(b.actor?.id||'')?`${b.userId||''}:${b.actor.id}`:'';};
 const modal=()=>globalThis.document?.getElementById('modal');
 const owns=view=>!!view&&modal()?.open===true&&modal()?.dataset.viewId===view.viewId&&view.form?.isConnected===true&&modal()?.querySelector('#account-delete-form')===view.form;
 function syncContext(){
  const next=actor();if(next===scope)return;
  const old=active;scope=next;generation++;active=null;record=null;flight=null;
  if(owns(old))closeModal();
 }
 const current=op=>{syncContext();return !!scope&&op.generation===generation&&op.scope===scope;};
 function actions(code){
  if(organizationBlocks.has(code))return '<button type="button" class="button-primary" data-action="authority-transfer">Hoofdbeheer overdragen</button><button type="button" class="button-secondary" data-action="team">Naar het stalteam</button><button type="button" class="button-secondary" data-action="switch-stable">Een andere stal kiezen</button><button type="button" class="text-link" data-action="account-delete-stables">Staloverzicht</button>';
  if(horseBlocks.has(code))return '<button type="button" class="button-primary" data-action="authority-transfer">Hoofdbeheer overdragen</button><button type="button" class="button-secondary" data-action="account-delete-horses">Naar mijn paarden</button>';
  return '';
 }
 function display(view,code){
  if(!owns(view))return;
  const error=view.form.querySelector('[data-deletion-message]'),links=view.form.querySelector('[data-deletion-actions]');
  if(error){error.hidden=false;error.textContent=explanation(code);}
  if(links)links.innerHTML=actions(code);
 }
 function open(){
  syncContext();if(!scope){showModal('Account verwijderen','<p>Meld je aan met je eigen account om verwijdering aan te vragen.</p>','','Je account');return;}
  record??={id:'',confirmation:'',code:'',deleted:false};
  showModal('Je account verwijderen',`<p>Je vraagt verwijdering van je eigen account aan. Je persoonlijke profiel wordt verwijderd of geanonimiseerd. Gedeelde paard- en stalhistorie kan behouden blijven.</p><p>Dit kun je niet ongedaan maken. Eventuele hoofdverantwoordelijkheden moet je eerst overdragen.</p><form id="account-delete-form"><label class="form-field">Typ VERWIJDEREN om te bevestigen<input name="confirmation" value="${esc(record.confirmation)}" autocomplete="off" autocapitalize="characters" spellcheck="false" required></label><p class="form-error" role="status" data-deletion-message${record.code?'':' hidden'}>${record.code?esc(explanation(record.code)):''}</p><div class="scope-options" data-deletion-actions>${actions(record.code)}</div><footer class="modal-footer"><button type="button" class="button-secondary" data-action="close-modal">Sluiten</button><button type="submit" class="button-primary"${flight?' disabled':''}>${flight?'Verwijdering controleren…':record.deleted?'Opnieuw afmelden':record.id?'Dezelfde aanvraag opnieuw proberen':'Mijn account verwijderen'}</button></footer></form>`,'','Je account');
  active={scope,generation,viewId:modal()?.dataset.viewId,form:modal()?.querySelector('#account-delete-form')};
  if(flight)for(const control of active.form?.querySelectorAll('input,button[type="submit"]')||[])control.disabled=true;
 }
 function handleAction(action){
  if(action==='account-delete'){open();return true;}
  if(!['account-delete-stables','account-delete-horses'].includes(action))return false;
  syncContext();if(!scope||!owns(active))return true;
  navigate(action==='account-delete-stables'?'stable':'horses');return true;
 }
 async function submit(view){
  if(!current(view)||!owns(view)||flight)return;
  const confirmation=String(new FormData(view.form).get('confirmation')||'').trim();
  if(confirmation!=='VERWIJDEREN'){
   const error=view.form.querySelector('[data-deletion-message]');if(error){error.hidden=false;error.textContent='Typ VERWIJDEREN om je eigen account te verwijderen.';}return;
  }
  record.confirmation=confirmation;
  record.id||=globalThis.crypto.randomUUID();
  const request=record,op={scope,generation},controls=[...view.form.querySelectorAll('input,button[type="submit"]')].map(control=>[control,control.disabled]);
  let pendingAccepted=false;
  flight=op;for(const [control] of controls)control.disabled=true;
  try{
   if(!request.deleted){
    const result=await getBackend().edgeRequest('delete-account',{action:'delete',request_id:request.id});
    if(!current(op))return;
    if(!['ACCOUNT_DELETED','ACCOUNT_DELETION_PENDING'].includes(result?.code)||!UUID.test(result?.request_id||'')){
     const code=typeof result?.code==='string'?result.code:'';
     request.code=blocked(code)?code:'DELETION_STATUS_UNAVAILABLE';display(active,request.code);return;
    }
    // The service may return the already-authorized job's canonical request ID.
    request.id=result.request_id;request.code=result.code;request.suspended=true;request.deleted=result.code==='ACCOUNT_DELETED';
    if(!request.deleted){
     pendingAccepted=true;
     display(active,request.code);
     await onPending({requestId:request.id,isCurrent:()=>current(op)});
     return;
    }
   }
   if(current(op))await clearSession({isCurrent:()=>current(op),message:'Je account is verwijderd.'});
  }catch(error){
   if(!current(op))return;
   if(request.deleted){
    if(owns(active)){const message=active.form.querySelector('[data-deletion-message]');if(message){message.hidden=false;message.textContent='Je account is verwijderd, maar lokaal afmelden is nog niet bevestigd. Probeer opnieuw af te melden.';}}
   }else if(pendingAccepted){
    // A presentation cleanup failure cannot erase the authoritative pending result.
    display(active,'ACCOUNT_DELETION_PENDING');
   }else{
    request.code=typeof error?.code==='string'?error.code:'DELETION_STATUS_UNAVAILABLE';display(active,request.code);
   }
  }finally{
   if(flight===op){flight=null;for(const [control,disabled] of controls)if(control.isConnected)control.disabled=disabled;
    if(current(op)&&owns(active))for(const control of active.form.querySelectorAll('input,button[type="submit"]')){
     if(active!==view)control.disabled=false;
     if(control.tagName==='BUTTON')control.textContent=request.deleted?'Opnieuw afmelden':'Dezelfde aanvraag opnieuw proberen';
    }
   }
  }
 }
 function handleSubmit(form,event){
  if(form.getAttribute('id')!=='account-delete-form')return false;
  event.preventDefault();syncContext();if(active?.form===form)void submit(active);return true;
 }
 return {handleAction,handleSubmit,syncContext,isPending:()=>{syncContext();return !!scope&&(record?.suspended===true||record?.deleted===true);}};
}
