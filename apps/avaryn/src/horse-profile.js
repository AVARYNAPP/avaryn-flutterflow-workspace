const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MIME=new Set(['image/jpeg','image/png','image/webp']);
const FIELDS={display_name:'Roepnaam',official_name:'Officiële naam',birth_date:'Geboortedatum',sex:'Geslacht',breed:'Ras',discipline:'Discipline',level:'Niveau',color:'Kleur',notes:'Goed om te weten',chip_number:'Chipnummer',passport_number:'Paspoortnummer'};
const LIMITS={display_name:160,official_name:200,breed:160,discipline:120,level:120,color:120,notes:2000,chip_number:200,passport_number:200};
const nullable=value=>String(value??'').trim()||null;
const one=value=>Array.isArray(value)&&value.length===1?value[0]:value;
const error=(code,message,extra={})=>Object.assign(new Error(message),{code,userMessage:message,...extra});
const stale=()=>error('STALE_CONTEXT','Je account of paardenlijst is veranderd. Open dit paard opnieuw.');
const invalid=(uncertain=false)=>error('INVALID_RESPONSE','De opslag is nog niet bevestigd. Controleer de actuele gegevens.',{uncertain});
const version=value=>Number.isSafeInteger(value)&&value>0;
const denied=()=>error('HORSE_EDIT_REQUIRED','Je kunt de gegevens van dit paard niet meer wijzigen.',{status:403,accessLost:true});
const same=(a,b)=>Object.keys(FIELDS).every(key=>nullable(a[key])===nullable(b[key]))&&nullable(a.passport_valid_until)===nullable(b.passport_valid_until)&&a.lifecycle_status===b.lifecycle_status;

/** Decode a real image, retaining its MIME for the existing two-variant contract. */
export async function makeHorseThumbnail(file){
 if(!MIME.has(file?.type)||file.size<=0||file.size>10*1024*1024)throw error('PHOTO_INPUT_INVALID','Kies een JPG-, PNG- of WebP-foto van maximaal 10 MB.');
 const bitmap=await createImageBitmap(file);
 try{
  if(!bitmap.width||!bitmap.height||bitmap.width*bitmap.height>40000000)throw error('PHOTO_INPUT_INVALID','Deze foto is te groot. Kies een kleinere afbeelding.');
  const ratio=Math.min(1,640/Math.max(bitmap.width,bitmap.height)),canvas=document.createElement('canvas');
  canvas.width=Math.max(1,Math.round(bitmap.width*ratio));canvas.height=Math.max(1,Math.round(bitmap.height*ratio));
  canvas.getContext('2d').drawImage(bitmap,0,0,canvas.width,canvas.height);
  const blob=await new Promise(resolve=>canvas.toBlob(resolve,file.type,.82));
  if(!blob||blob.type!==file.type||blob.size>1024*1024)throw error('PHOTO_INPUT_INVALID','De kleine foto kon niet worden gemaakt. Probeer een andere afbeelding.');
  return blob;
 }finally{bitmap.close();}
}

/**
 * Integration: route actions edit-horse, horse-photo, horse-profile-review here;
 * call capture(form) immediately after showModal renders; delegate submissions.
 * Forward close-modal/navigation to cancelOpen(), and logout/ACL purge to dispose().
 * getBackend supplies apiRequest(name,params,{write}), mediaRequest(body,{write}),
 * uploadHorseMedia(EdgeUploadDescriptor,Blob), downloadHorseMedia({media_asset_id,
 * variant:'thumbnail'}) -> Blob. The latter performs canonical_download and a
 * pinned signed-URL fetch inside the session-gated client/BFF. No bearer, service
 * key or signed URL is retained in application state or this module's public API.
 * All transport methods must bound time and reject stale session/load generations.
 * perform owns write/readback/close; this module never commits optimistic state.
 * loadPhotos(snapshot) returns a new authorized snapshot; call it inside the
 * existing generation-guarded load before commit. Revoke blobs on logout/purge.
 */
export function createHorseProfile({getState,getBackend,showModal,perform,esc,makeThumbnail=makeHorseThumbnail,objectUrls=URL,nativePhoto}){
 const forms=new WeakMap();let pending=null,openEpoch=0,photoEpoch=0,urls=new Set();
 const api=(name,args={},write=false)=>getBackend().apiRequest(name,args,{write});
 const input=(key,label,value,extra='')=>`<label class="form-field">${label}<input name="${key}" value="${esc(value??'')}" ${extra}></label>`;
 const footer=(label,review=false)=>`${review?'<button type="button" class="text-link" data-action="horse-profile-review">Actuele gegevens vergelijken</button>':''}<footer class="modal-footer"><button type="button" class="button-secondary" data-action="close-modal">Annuleren</button><button type="submit" class="button-primary">${label}</button></footer>`;
 const context=()=>({backend:getState().backend,epoch:openEpoch});
 function current(ticket){return ticket.epoch===openEpoch&&getState().backend===ticket.backend&&ticket.backend?.connected===true;}
 function requireCurrent(ticket,isCurrent=()=>true){if(!current(ticket)||!isCurrent())throw stale();}
 function canEdit(id){return getState().backend?.connected===true&&getState().backend.horseCapabilities?.[id]?.edit===true;}
 async function read(id,ticket,isCurrent=()=>true){
  requireCurrent(ticket,isCurrent);const rows=await api('list_c010_horses');requireCurrent(ticket,isCurrent);
  if(!Array.isArray(rows))throw invalid();
  const found=rows.filter(row=>row.horse_id===id);
  if(found.length!==1)throw denied();const row=found[0];
  if(!version(row.row_version)||typeof row.can_edit!=='boolean'||typeof row.display_name!=='string')throw invalid();
  if(!row.can_edit||row.lifecycle_status!=='active')throw denied();
  return {...row};
 }
 function showFailure(e,ticket){if(current(ticket))showModal('Paardgegevens',`<p role="alert">${esc(e.userMessage||'De gegevens konden niet worden opgehaald. Open het paard opnieuw.')}</p>`,'<button type="button" class="button-secondary" data-action="close-modal">Sluiten</button>','Jouw paard');}
 async function open(id,photo=false){
  if(!UUID.test(id||'')||!canEdit(id))return;
  ++openEpoch;pending=null;const ticket=context(),raw=await read(id,ticket);requireCurrent(ticket);
  const formId=photo?'core-horse-photo-form':'core-horse-edit-form';
  pending={formId,ticket,raw,attempt:null,media:null};
  if(photo){
   const connected=['mediaRequest','uploadHorseMedia','downloadHorseMedia'].every(name=>typeof getBackend()[name]==='function');
   const camera=typeof nativePhoto?.takePhoto==='function'?`<button type="button" class="button-secondary" data-action="horse-camera">Foto maken</button><p class="horse-muted" data-native-photo-label aria-live="polite">${esc(nativePhoto.getRecoveryNotice?.()||'Je kunt ook een bestaande foto kiezen.')}</p>`:'';
   showModal('Een foto van je paard',connected?`<form id="${formId}"><label class="form-field">Foto van ${esc(raw.display_name)}<input type="file" name="photo" accept="image/jpeg,image/png,image/webp" required></label>${camera}<p class="horse-muted">JPG, PNG of WebP, maximaal 10 MB. Alleen mensen met toegang tot dit paard kunnen de opgeslagen foto bekijken.</p><p class="horse-muted">De huidige foto blijft staan totdat de nieuwe foto is bevestigd.</p>${footer('Foto opslaan')}</form>`:'<p role="status">Foto’s opslaan is nog niet verbonden. Je bestaande paardgegevens blijven beschikbaar.</p>','',raw.display_name);
   return;
  }
  showModal('Paardgegevens aanpassen',`<form id="${formId}">${input('display_name','Roepnaam',raw.display_name,'required maxlength="160"')}${input('official_name','Officiële naam, optioneel',raw.official_name,'maxlength="200"')}<div class="form-grid">${input('birth_date','Geboortedatum, optioneel',raw.birth_date,'type="date"')}<label class="form-field">Geslacht<select name="sex">${[['unknown','Onbekend'],['mare','Merrie'],['gelding','Ruin'],['stallion','Hengst']].map(([v,t])=>`<option value="${v}"${raw.sex===v?' selected':''}>${t}</option>`).join('')}</select></label></div><div class="form-grid">${input('breed','Ras, optioneel',raw.breed,'maxlength="160"')}${input('color','Kleur, optioneel',raw.color,'maxlength="120"')}</div><div class="form-grid">${input('discipline','Discipline, optioneel',raw.discipline,'maxlength="120"')}${input('level','Niveau, optioneel',raw.level,'maxlength="120"')}</div><div class="form-grid">${input('chip_number','Chipnummer, optioneel',raw.chip_number,'maxlength="200"')}${input('passport_number','Paspoortnummer, optioneel',raw.passport_number,'maxlength="200"')}</div><label class="form-field">Goed om te weten<textarea name="notes" maxlength="2000">${esc(raw.notes??'')}</textarea></label><section class="horse-profile-review" aria-live="polite"></section>${footer('Paardgegevens opslaan',true)}</form>`,'',raw.display_name);
 }
 function capture(form){
  if(pending?.formId!==form.id||!current(pending.ticket))return;
  const entry=pending;forms.set(form,entry);pending=null;
  if(form.id==='core-horse-photo-form'&&typeof nativePhoto?.takePhoto==='function'){
   entry.viewId=document.querySelector('#modal')?.dataset.viewId;
   const input=form.querySelector('[name="photo"]');
   input.addEventListener('change',()=>{
    if(!ownsPhoto(form,entry)||entry.capturing)return;
    entry.nativeFile=null;input.required=true;
    form.querySelector('[data-native-photo-label]').textContent=input.files?.[0]?`Gekozen foto: ${input.files[0].name}`:'Kies een foto of maak een nieuwe foto.';
   });
  }
 }
 function ownsPhoto(form,entry){
  const modal=document.querySelector('#modal');
  return current(entry.ticket)&&form.isConnected===true&&entry.viewId&&modal?.open&&modal.dataset.viewId===entry.viewId&&modal.querySelector('form')===form;
 }
 async function capturePhoto(form){
  const entry=forms.get(form);
  if(typeof nativePhoto?.takePhoto!=='function'||!entry||!ownsPhoto(form,entry)||entry.capturing||form.dataset.busy==='true')return;
  if(entry.media){inlineError(form,error('PHOTO_CHANGED','Open het fotoformulier opnieuw om een andere foto te kiezen.'));return;}
  const input=form.querySelector('[name="photo"]'),controls=[...form.querySelectorAll('input, button[type=submit], button[data-action="horse-camera"]')].map(el=>({el,disabled:el.disabled}));
  entry.capturing=true;for(const {el} of controls)el.disabled=true;
  try{
   const file=await nativePhoto.takePhoto({isCurrent:()=>ownsPhoto(form,entry)});
   if(!ownsPhoto(form,entry)||!file)return;
   if(!(file instanceof File)||!MIME.has(file.type)||file.size<=0||file.size>10*1024*1024)throw error('PHOTO_INPUT_INVALID','Kies een JPG-, PNG- of WebP-foto van maximaal 10 MB.');
   input.value='';entry.nativeFile=file;input.required=false;
   form.querySelector('[data-native-photo-label]').textContent=`Gekozen foto: ${file.name} (camera). Druk op ‘Foto opslaan’ om deze te bewaren.`;
   const alert=form.querySelector('.form-error');if(alert)alert.textContent='';
  }catch(e){if(ownsPhoto(form,entry))inlineError(form,e);}
  finally{entry.capturing=false;for(const {el,disabled} of controls)el.disabled=disabled;}
 }
 function draft(form,raw){
  const values=Object.fromEntries(new FormData(form));const out={...raw};
  for(const key of Object.keys(FIELDS))out[key]=nullable(values[key]);
  if(!out.display_name)throw error('NAME_REQUIRED','Vul de roepnaam van je paard in.');
  for(const [key,max] of Object.entries(LIMITS))if(Array.from(out[key]||'').length>max)throw error('FIELD_TOO_LONG',`${FIELDS[key]} mag maximaal ${max} tekens bevatten.`);
  if(!['unknown','mare','gelding','stallion'].includes(out.sex))throw error('SEX_INVALID','Kies het geslacht van je paard.');
  return out;
 }
 function inlineError(form,e){let el=form.querySelector('.form-error');if(!el){el=document.createElement('p');el.className='form-error';el.setAttribute('role','alert');form.prepend(el);}el.textContent=e.userMessage||e.message;}
 async function review(form){
  const entry=forms.get(form);if(!entry||form.dataset.busy==='true')return;
  try{
   requireCurrent(entry.ticket);const latest=await read(entry.raw.horse_id,entry.ticket);requireCurrent(entry.ticket);
   if(form.isConnected===false)return;
   const desired=draft(form,entry.raw),changes=Object.keys(FIELDS).filter(key=>nullable(latest[key])!==nullable(desired[key]));
   const panel=form.querySelector('.horse-profile-review');if(!panel)return;
   panel.innerHTML=`<h3>Jouw invoer blijft staan</h3><p>Controleer de verschillen. Met ‘Mijn invoer opnieuw opslaan’ gebruik je jouw invoer voor deze velden.</p>${changes.length?`<dl>${changes.map(key=>`<dt>${FIELDS[key]}</dt><dd>Nu opgeslagen: ${esc(latest[key]??'Niet ingevuld')}<br>Jouw invoer: ${esc(desired[key]??'Niet ingevuld')}</dd>`).join('')}</dl>`:'<p>Deze velden komen overeen met de opgeslagen gegevens.</p>'}`;
   entry.raw=latest;entry.attempt=null;delete form.dataset.requestId;form.dataset.uncertain='false';
   for(const control of form.querySelectorAll('input, textarea, select, button[type=submit]'))control.disabled=false;
   const submit=form.querySelector('button[type=submit]');if(submit)submit.textContent='Mijn invoer opnieuw opslaan';
  }catch(e){if(current(entry.ticket))inlineError(form,e);}
 }
 async function saveProfile(desired,entry,requestId,isCurrent){
  requireCurrent(entry.ticket,isCurrent);
  if(entry.attempt&&!same(entry.attempt.desired,desired))throw error('DRAFT_CHANGED','Controleer eerst de actuele gegevens voordat je jouw invoer wijzigt.');
  const latest=await read(entry.raw.horse_id,entry.ticket,isCurrent);
  // Correlation is not an idempotency receipt. Reconcile authoritative fields
  // before every retry; never adopt a newer version without explicit review.
  if(entry.attempt&&latest.row_version>entry.raw.row_version&&same(latest,desired))return;
  if(latest.row_version!==entry.raw.row_version)throw error('HORSE_PROFILE_CHANGED','Dit paard is intussen gewijzigd. Je invoer blijft staan. Kies ‘Actuele gegevens vergelijken’.');
  entry.attempt={desired,requestId};
  const params={p_horse_id:entry.raw.horse_id,p_expected_row_version:entry.raw.row_version,p_status:entry.raw.lifecycle_status,p_correlation_id:requestId,p_passport_valid_until:entry.raw.passport_valid_until??null};
  for(const key of Object.keys(FIELDS))params[`p_${key}`]=desired[key];
  try{
   const result=one(await api('update_canonical_horse_profile',params,true));requireCurrent(entry.ticket,isCurrent);
   if(!result||result.row_version!==entry.raw.row_version+1||result.status!=='active'||result.applied!==true)throw invalid(true);
  }catch(e){
   requireCurrent(entry.ticket,isCurrent);
   if(e.accessLost||e.status===401||e.status===403)throw e;
   if(e.uncertain||e.code==='40001'||e.code==='STALE_HORSE_VERSION'||e.code==='PT409'){
    let actual;
    try{actual=await read(entry.raw.horse_id,entry.ticket,isCurrent);}
    catch(readError){if(readError.accessLost||[401,403].includes(readError.status)||readError.code==='STALE_CONTEXT')throw readError;throw invalid(true);}
    if(actual.row_version>entry.raw.row_version&&same(actual,desired))return;
    if(actual.row_version!==entry.raw.row_version)throw error('HORSE_PROFILE_CHANGED','Dit paard is intussen gewijzigd. Je invoer blijft staan. Kies ‘Actuele gegevens vergelijken’.');
   }
   throw e;
  }
 }
 async function savePhoto(file,entry,isCurrent){
  requireCurrent(entry.ticket,isCurrent);
  if(!MIME.has(file?.type)||file.size<=0||file.size>10*1024*1024)throw error('PHOTO_INPUT_INVALID','Kies een JPG-, PNG- of WebP-foto van maximaal 10 MB.');
  const backend=getBackend();
  if(!['mediaRequest','uploadHorseMedia'].every(name=>typeof backend[name]==='function'))throw error('PHOTO_NOT_CONNECTED','Foto’s opslaan is nog niet verbonden.');
  if(entry.media&&entry.media.file!==file)throw error('PHOTO_CHANGED','Open het fotoformulier opnieuw om een andere foto te kiezen.');
  if(!entry.media)entry.media={file,createId:crypto.randomUUID(),finalizeId:crypto.randomUUID(),selectId:crypto.randomUUID(),uploaded:new Set()};
  const m=entry.media;
  const latest=await read(entry.raw.horse_id,entry.ticket,isCurrent);
  if(m.assetId&&latest.profile_media_asset_id===m.assetId)return;
  if(latest.row_version!==entry.raw.row_version)throw error('HORSE_PROFILE_CHANGED','Dit paard is intussen gewijzigd. Open het fotoformulier opnieuw. De huidige foto blijft bewaard.');
  if(!m.thumbnail){m.thumbnail=await makeThumbnail(file);requireCurrent(entry.ticket,isCurrent);}
  if(!m.session){
   const session=await backend.mediaRequest({action:'canonical_create',horse_id:entry.raw.horse_id,original_filename:file.name||'paardenfoto',mime_type:file.type,request_id:m.createId},{write:true});requireCurrent(entry.ticket,isCurrent);
   if(!UUID.test(session?.media_asset_id||'')||!version(session.row_version)||!['pending','ready'].includes(session.status)||!Array.isArray(session.uploads))throw invalid(true);
   if(session.status==='pending'&&(session.uploads.length!==2||new Set(session.uploads.map(u=>u.variant)).size!==2||!session.uploads.every(u=>['original','thumbnail'].includes(u.variant)&&u.expected_mime_type===file.type&&Number.isSafeInteger(u.max_byte_size)&&u.max_byte_size>0)))throw invalid(true);
   m.session=session;m.assetId=session.media_asset_id;m.ready=session.status==='ready';
  }
  if(!m.ready){
   // An upload with an unknown result must not be blindly repeated or removed.
   // A subsequent submit can only ask finalization to verify the stored bytes.
   if(!m.unknownUpload)for(const upload of m.session.uploads){
    if(m.uploaded.has(upload.variant))continue;
    const blob=upload.variant==='original'?file:m.thumbnail;
    if(blob.type!==upload.expected_mime_type||blob.size>upload.max_byte_size)throw error('PHOTO_INPUT_INVALID','Deze foto past niet binnen de toegestane bestandsgrootte.');
    requireCurrent(entry.ticket,isCurrent);
    try{await backend.uploadHorseMedia(upload,blob);requireCurrent(entry.ticket,isCurrent);m.uploaded.add(upload.variant);}
    catch(e){m.unknownUpload=true;throw e;}
   }
   requireCurrent(entry.ticket,isCurrent);
   let final;
   try{final=await backend.mediaRequest({action:'canonical_finalize',media_asset_id:m.assetId,expected_row_version:m.session.row_version,request_id:m.finalizeId},{write:true});requireCurrent(entry.ticket,isCurrent);}
   catch(e){if(m.unknownUpload&&!e.accessLost&&![401,403].includes(e.status))throw error('PHOTO_UNCONFIRMED','De foto is nog niet bevestigd. Open het fotoformulier opnieuw om het nogmaals te proberen. De huidige foto blijft bewaard.');throw e;}
   if(final?.media_asset_id!==m.assetId||final.status!=='ready'||!version(final.row_version))throw invalid(true);
   m.ready=true;
  }
  requireCurrent(entry.ticket,isCurrent);
  const result=await api('set_canonical_horse_profile_media',{p_horse_id:entry.raw.horse_id,p_media_asset_id:m.assetId,p_expected_row_version:entry.raw.row_version,p_request_id:m.selectId},true);requireCurrent(entry.ticket,isCurrent);
  if(result?.horse_id!==entry.raw.horse_id||result.profile_media_asset_id!==m.assetId||result.row_version!==entry.raw.row_version+1)throw invalid(true);
 }
 function handleAction(action,button){
  if(action==='close-modal'){cancelOpen();return false;}
  if(action==='horse-camera'){void capturePhoto(button?.closest?.('form'));return true;}
  if(action==='horse-profile-review'){void review(button?.closest?.('form'));return true;}
  if(!['edit-horse','horse-photo'].includes(action))return false;
  const id=button?.dataset?.horse||button?.dataset?.id||getState().horseId;
  const promise=open(id,action==='horse-photo');const ticket=context();promise.catch(e=>showFailure(e,ticket));return true;
 }
 function handleSubmit(form,event){
  if(!['core-horse-edit-form','core-horse-photo-form'].includes(form.id))return false;
  event.preventDefault();const entry=forms.get(form);
  if(!entry||!current(entry.ticket)){inlineError(form,stale());return true;}
  if(entry.capturing)return true;
  if(entry.nativeFile&&!ownsPhoto(form,entry)){inlineError(form,stale());return true;}
  // Capture before perform disables successful controls: disabled form inputs
  // are intentionally omitted by native FormData.
  let captured;
  try{captured=form.id==='core-horse-edit-form'?draft(form,entry.raw):(entry.nativeFile||form.querySelector('[name="photo"]')?.files?.[0]||new FormData(form).get('photo'));}
  catch(e){inlineError(form,e);return true;}
  perform(form,async(requestId,isCurrent=()=>true)=>{
   if(form.id==='core-horse-edit-form')await saveProfile(captured,entry,requestId,isCurrent);else await savePhoto(captured,entry,isCurrent);
   requireCurrent(entry.ticket,isCurrent);form.dataset.resultHorseId=entry.raw.horse_id;
  },form.id==='core-horse-edit-form'?'Je paardgegevens zijn opgeslagen.':'De foto is opgeslagen.');
  return true;
 }
 function cancelOpen(){++openEpoch;pending=null;}
 function clearPhotos(){++photoEpoch;for(const url of urls)objectUrls.revokeObjectURL(url);urls=new Set();}
 async function loadPhotos(snapshot){
  const serial=++photoEpoch,initial=getState().backend,created=new Set(),backend=getBackend();
  const valid=()=>serial===photoEpoch&&getState().backend===initial;
  const horses=(snapshot.horses||[]).map(h=>({...h,image:'',imageIsPlaceholder:false,photoStatus:'none'}));
  try{
   if(snapshot.backend?.connected&&typeof backend.downloadHorseMedia==='function'){
    const rows=await backend.apiRequest('list_c010_horses',{}, {write:false});if(!valid())throw stale();
    if(!Array.isArray(rows))throw invalid();
    // Sequential reads bound resource use and preserve the transport's session gate.
    for(const horse of horses){
     const row=rows.find(r=>r.horse_id===horse.id),asset=row?.profile_media_asset_id;
     if(!UUID.test(asset||''))continue;
     try{
      const blob=await backend.downloadHorseMedia({media_asset_id:asset,variant:'thumbnail'});if(!valid())throw stale();
      if(!(blob instanceof Blob)||!MIME.has(blob.type)||blob.size<=0||blob.size>1024*1024)throw invalid();
      const url=objectUrls.createObjectURL(blob);created.add(url);horse.image=url;horse.photoStatus='ready';
     }catch(e){if(!valid()||e.accessLost||e.status===401||e.status===403)throw e;horse.photoStatus='unavailable';}
    }
   }
   if(!valid())throw stale();
   for(const url of urls)objectUrls.revokeObjectURL(url);urls=created;
   return {...snapshot,horses};
  }catch(e){for(const url of created)objectUrls.revokeObjectURL(url);throw e;}
 }
 function dispose(){cancelOpen();clearPhotos();}
 return {handleAction,handleSubmit,capture,open,review,loadPhotos,clearPhotos,cancelOpen,dispose};
}
