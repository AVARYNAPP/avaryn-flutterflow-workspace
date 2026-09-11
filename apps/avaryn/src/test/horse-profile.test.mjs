import test from 'node:test';
import assert from 'node:assert/strict';
import {createHorseProfile,makeHorseThumbnail} from '../horse-profile.js';

const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const horse=id(1),actor=id(2),asset=id(3);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const deferred=()=>{let resolve,reject;const promise=new Promise((r,j)=>{resolve=r;reject=j;});return{promise,resolve,reject};};
const row=()=>({horse_id:horse,display_name:'Luna',official_name:'Luna van de Wilgen',birth_date:'2016-04-05',sex:'mare',breed:'KWPN',discipline:'Dressuur',level:'L',color:'Bruin',notes:'Behoud de hele notitie.',chip_number:'SYNTHETISCH-CHIP',passport_number:'SYNTHETISCH-PAS',passport_valid_until:'2030-01-01',profile_media_asset_id:null,lifecycle_status:'active',row_version:4,can_edit:true,is_primary_authority:true});
const sourceFile=()=>new File([new Uint8Array([1,2,3])],'luna.jpg',{type:'image/jpeg'});
function harness(t){
 let state={horseId:horse,horses:[{id:horse,name:'Luna',image:'assets/orion.png',imageIsPlaceholder:true}],backend:{connected:true,actor:{id:actor},horseCapabilities:{[horse]:{view:true,edit:true}}}},raw=row(),last;
 const calls=[],modals=[],created=[],revoked=[];
 const original=globalThis.FormData;
 globalThis.FormData=class{
  constructor(form){this.rows=form.controlsDisabled?[]:Object.entries(form.fields);}
  *[Symbol.iterator](){yield* this.rows;}
  get(name){return this.rows.find(([key])=>key===name)?.[1]??null;}
 };
 t.after(()=>{globalThis.FormData=original;});
 const backend={
  read:async()=>[{...raw}],
  update:async params=>{for(const [key,val] of Object.entries(params))if(key.startsWith('p_')&&key.slice(2) in raw)raw[key.slice(2)]=val;raw.row_version++;return[{row_version:raw.row_version,status:'active',applied:true}];},
  select:async params=>{raw.profile_media_asset_id=params.p_media_asset_id;raw.row_version++;return{horse_id:horse,profile_media_asset_id:raw.profile_media_asset_id,row_version:raw.row_version,idempotent:false};},
  apiRequest:async(name,params={},opts={})=>{calls.push({kind:'rpc',name,params,opts});if(name==='list_c010_horses')return backend.read();if(name==='update_canonical_horse_profile')return backend.update(params);if(name==='set_canonical_horse_profile_media')return backend.select(params);throw Error(name);},
  media:async body=>body.action==='canonical_create'?{media_asset_id:asset,row_version:1,status:'pending',uploads:['original','thumbnail'].map(variant=>({variant,object_path:`canonical/${horse}/${asset}/${variant}`,expected_mime_type:'image/jpeg',max_byte_size:variant==='original'?10485760:1048576,signed_upload_url:'private-capability-not-rendered',upload_token:'private-upload-token'}))}:{media_asset_id:asset,row_version:2,status:'ready'},
  mediaRequest:async(body,opts)=>{calls.push({kind:'media',body,opts});return backend.media(body);},
  upload:async()=>{},uploadHorseMedia:async(descriptor,blob)=>{calls.push({kind:'upload',descriptor,blob});return backend.upload(descriptor,blob);},
  download:async()=>new Blob(['real-test-bytes'],{type:'image/jpeg'}),downloadHorseMedia:async body=>{calls.push({kind:'download',body});return backend.download(body);}
 };
 let thumbnail=async()=>new Blob(['thumbnail'],{type:'image/jpeg'});
 const module=createHorseProfile({getState:()=>state,getBackend:()=>backend,esc,makeThumbnail:f=>thumbnail(f),objectUrls:{createObjectURL:()=>{const url=`blob:test-${created.length}`;created.push(url);return url;},revokeObjectURL:url=>revoked.push(url)},showModal:(...args)=>modals.push(args),perform:(form,operation)=>{form.controlsDisabled=true;last=Promise.resolve().then(()=>operation(id(90),()=>true)).finally(()=>{form.controlsDisabled=false;});last.catch(()=>{});return last;}});
 function form(photo=false){
  const fields=photo?{photo:sourceFile()}:{...raw},error={textContent:''},panel={innerHTML:''},submit={textContent:'Opslaan',disabled:false},controls=[submit];
  return{id:photo?'core-horse-photo-form':'core-horse-edit-form',fields,dataset:{},error,panel,submit,controls,isConnected:true,querySelector:selector=>selector==='.form-error'?error:selector==='.horse-profile-review'?panel:selector==='button[type=submit]'?submit:selector==='[name="photo"]'&&photo?{files:[fields.photo]}:null,querySelectorAll:()=>controls,prepend(){}};
 }
 async function editor(photo=false){await module.open(horse,photo);const f=form(photo);module.capture(f);return f;}
 function submit(f){assert.equal(module.handleSubmit(f,{preventDefault(){}}),true);return last;}
 return {module,backend,calls,modals,created,revoked,editor,form,submit,get:()=>state,set:s=>state=s,raw:()=>raw,setRaw:r=>raw=r,setThumbnail:fn=>thumbnail=fn,writes:()=>calls.filter(c=>c.opts?.write),done:()=>last};
}

test('production profile callback captures enabled values, preserves unshown metadata and uses server CAS',async t=>{
 const h=harness(t),f=await h.editor();f.fields.display_name='  Nieuwe Luna  ';f.fields.notes='Volledige aangepaste instructie.';const before=structuredClone(h.get());
 await h.submit(f);const write=h.writes()[0];assert.equal(write.name,'update_canonical_horse_profile');assert.equal(write.params.p_expected_row_version,4);assert.equal(write.params.p_display_name,'Nieuwe Luna');assert.equal(write.params.p_notes,'Volledige aangepaste instructie.');assert.equal(write.params.p_passport_valid_until,'2030-01-01');assert.equal(write.params.p_status,'active');assert.equal(write.params.p_chip_number,'SYNTHETISCH-CHIP');assert.ok(!('p_actor_id' in write.params));assert.deepEqual(h.get(),before,'Only parent readback may replace UI data');assert.equal(f.dataset.resultHorseId,horse);
});
test('fresh can_edit false blocks even a cached primary or manager',async t=>{const h=harness(t);h.raw().can_edit=false;await assert.rejects(h.module.open(horse),e=>e.accessLost===true);assert.equal(h.modals.length,0);assert.equal(h.writes().length,0);});
test('delegated horse.edit is sufficient without claiming primary authority',async t=>{const h=harness(t);h.raw().is_primary_authority=false;const f=await h.editor();f.fields.notes='Delegatie';await h.submit(f);assert.equal(h.writes().length,1);});
test('delayed open after account round trip cannot expose a form',async t=>{const h=harness(t),d=deferred();h.backend.read=()=>d.promise;const pending=h.module.open(horse);h.set(structuredClone(h.get()));d.resolve([row()]);await assert.rejects(pending,{code:'STALE_CONTEXT'});assert.equal(h.modals.length,0);});
test('context change during final permission read blocks the write',async t=>{const h=harness(t),f=await h.editor(),d=deferred();h.backend.read=()=>d.promise;const p=h.submit(f);await Promise.resolve();h.set(structuredClone(h.get()));d.resolve([row()]);await assert.rejects(p,{code:'STALE_CONTEXT'});assert.equal(h.writes().length,0);});
test('new server version requires explicit comparison, keeps draft and then uses reviewed version',async t=>{
 const h=harness(t),f=await h.editor();f.fields.notes='Mijn eigen invoer';h.raw().row_version=5;h.raw().notes='Tweede sessie';h.raw().passport_valid_until='2031-01-01';
 await assert.rejects(h.submit(f),{code:'HORSE_PROFILE_CHANGED'});assert.equal(h.writes().length,0);assert.equal(f.fields.notes,'Mijn eigen invoer');
 await h.module.review(f);assert.match(f.panel.innerHTML,/Tweede sessie/);assert.match(f.panel.innerHTML,/Mijn eigen invoer/);assert.equal(h.writes().length,0);
 await h.submit(f);assert.equal(h.writes()[0].params.p_expected_row_version,5);assert.equal(h.writes()[0].params.p_passport_valid_until,'2031-01-01');
});
test('an uncertain committed profile response is reconciled without a second write',async t=>{
 const h=harness(t),f=await h.editor();f.fields.notes='Nieuwe notitie';const update=h.backend.update;h.backend.update=async p=>{await update(p);throw Object.assign(Error('timeout'),{uncertain:true});};await h.submit(f);assert.equal(h.writes().length,1);assert.equal(h.raw().notes,'Nieuwe notitie');assert.equal(f.dataset.resultHorseId,horse);
});
test('uncertain uncommitted write retains captured CAS; retry reads before writing again',async t=>{
 const h=harness(t),f=await h.editor();f.fields.notes='Concept';const update=h.backend.update;h.backend.update=async()=>{throw Object.assign(Error('timeout'),{uncertain:true});};await assert.rejects(h.submit(f),/timeout/);assert.equal(h.raw().row_version,4);h.backend.update=update;await h.submit(f);assert.deepEqual(h.writes().map(c=>c.params.p_expected_row_version),[4,4]);
});
test('malformed profile acknowledgement cannot claim confirmed success',async t=>{const h=harness(t),f=await h.editor();h.backend.update=async()=>({row_version:5});await assert.rejects(h.submit(f),e=>e.code==='INVALID_RESPONSE'&&e.uncertain===true);assert.equal(f.dataset.resultHorseId,undefined);});
test('revoked permission at submit prevents all writes',async t=>{const h=harness(t),f=await h.editor();h.raw().can_edit=false;await assert.rejects(h.submit(f),e=>e.accessLost===true);assert.equal(h.writes().length,0);});
test('HTML fields and comparison content escape stored text',async t=>{const h=harness(t);h.raw().notes='<img src=x onerror=alert(1)>';const f=await h.editor();assert.ok(!h.modals[0][1].includes('<img src=x'));h.raw().notes='<script>no</script>';h.raw().row_version++;await h.module.review(f);assert.ok(!f.panel.innerHTML.includes('<script>'));assert.match(f.panel.innerHTML,/&lt;script&gt;/);});
test('official name and color enforce the existing SQL limits before any write',async t=>{const h=harness(t),f=await h.editor();assert.match(h.modals[0][1],/name="official_name"[^>]*maxlength="200"/);assert.match(h.modals[0][1],/name="color"[^>]*maxlength="120"/);f.fields.official_name='x'.repeat(201);h.submit(f);assert.match(f.error.textContent,/200/);assert.equal(h.writes().length,0);f.fields.official_name='x'.repeat(200);f.fields.color='y'.repeat(121);h.submit(f);assert.match(f.error.textContent,/120/);assert.equal(h.writes().length,0);});

test('photo production path creates two bytes variants, finalizes then selects with captured CAS',async t=>{
 const h=harness(t),f=await h.editor(true),before=structuredClone(h.get());await h.submit(f);
 assert.deepEqual(h.calls.filter(c=>c.kind!=='rpc'||c.opts.write).map(c=>c.kind==='media'?c.body.action:c.kind==='rpc'?c.name:c.kind),['canonical_create','upload','upload','canonical_finalize','set_canonical_horse_profile_media']);
 const select=h.writes().find(c=>c.name==='set_canonical_horse_profile_media');assert.equal(select.params.p_expected_row_version,4);assert.equal(select.params.p_media_asset_id,asset);assert.equal(h.calls.find(c=>c.kind==='upload').blob,f.fields.photo);assert.deepEqual(h.get(),before);assert.ok(!JSON.stringify(h.modals).includes('private-upload-token'));
});
test('thumbnail completion after dispose cannot create an upload session',async t=>{const h=harness(t),f=await h.editor(true),d=deferred();h.setThumbnail(()=>d.promise);const p=h.submit(f);await new Promise(r=>setImmediate(r));h.module.dispose();d.resolve(new Blob(['t'],{type:'image/jpeg'}));await assert.rejects(p,{code:'STALE_CONTEXT'});assert.equal(h.writes().length,0);});
test('late storage response after ABA prevents thumbnail/finalize/profile writes',async t=>{const h=harness(t),f=await h.editor(true),d=deferred();h.backend.upload=()=>d.promise;const p=h.submit(f);await new Promise(r=>setImmediate(r));h.set(structuredClone(h.get()));d.resolve();await assert.rejects(p,{code:'STALE_CONTEXT'});assert.equal(h.calls.filter(c=>c.kind==='upload').length,1);assert.ok(!h.calls.some(c=>c.body?.action==='canonical_finalize'||c.name==='set_canonical_horse_profile_media'));});
test('ambiguous upload retries verification only, never overwrites or deletes storage',async t=>{
 const h=harness(t),f=await h.editor(true);h.backend.upload=async()=>{throw Object.assign(Error('unknown upload'),{uncertain:true});};await assert.rejects(h.submit(f),/unknown upload/);h.backend.media=async body=>{assert.equal(body.action,'canonical_finalize');throw Object.assign(Error('missing thumbnail'),{status:409});};await assert.rejects(h.submit(f),{code:'PHOTO_UNCONFIRMED'});assert.equal(h.calls.filter(c=>c.kind==='upload').length,1);assert.ok(!h.calls.some(c=>/delete|archive/.test(c.name||c.body?.action||'')));
});
test('malformed create or finalization cannot select a profile photo',async t=>{const h=harness(t),f=await h.editor(true);h.backend.media=async()=>({media_asset_id:asset,row_version:1,status:'pending',uploads:[]});await assert.rejects(h.submit(f),{code:'INVALID_RESPONSE'});assert.equal(h.calls.filter(c=>c.kind==='upload').length,0);assert.ok(!h.calls.some(c=>c.name==='set_canonical_horse_profile_media'));});
test('unknown finalization can reuse its receipt and never reupload confirmed variants',async t=>{
 const h=harness(t),f=await h.editor(true),media=h.backend.media;let attempts=0;h.backend.media=async body=>{if(body.action==='canonical_finalize'&&attempts++===0)throw Object.assign(Error('finalize timeout'),{uncertain:true});return media(body);};await assert.rejects(h.submit(f),/finalize timeout/);await h.submit(f);const final=h.calls.filter(c=>c.body?.action==='canonical_finalize');assert.equal(final.length,2);assert.equal(final[0].body.request_id,final[1].body.request_id);assert.equal(h.calls.filter(c=>c.kind==='upload').length,2);
});
test('unknown photo selection is reconciled by authoritative selected media id',async t=>{const h=harness(t),f=await h.editor(true),select=h.backend.select;h.backend.select=async p=>{await select(p);throw Object.assign(Error('selection timeout'),{uncertain:true});};await assert.rejects(h.submit(f),/selection timeout/);await h.submit(f);assert.equal(h.calls.filter(c=>c.name==='set_canonical_horse_profile_media').length,1);assert.equal(f.dataset.resultHorseId,horse);});
test('unsupported file type never makes media writes',async t=>{const h=harness(t),f=await h.editor(true);f.fields.photo=new File(['<svg/>'],'x.svg',{type:'image/svg+xml'});await assert.rejects(h.submit(f),{code:'PHOTO_INPUT_INVALID'});assert.equal(h.writes().length,0);});

test('loadPhotos removes fake fallbacks and returns only actual private blob images',async t=>{
 const h=harness(t);let result=await h.module.loadPhotos(h.get());assert.equal(result.horses[0].image,'');assert.equal(result.horses[0].imageIsPlaceholder,false);assert.equal(result.horses[0].photoStatus,'none');assert.equal(h.get().horses[0].image,'assets/orion.png');h.raw().profile_media_asset_id=asset;result=await h.module.loadPhotos(h.get());assert.equal(result.horses[0].image,'blob:test-0');assert.equal(result.horses[0].photoStatus,'ready');assert.deepEqual(h.calls.find(c=>c.kind==='download').body,{media_asset_id:asset,variant:'thumbnail'});h.module.dispose();assert.deepEqual(h.revoked,['blob:test-0']);
});
test('late image bytes after purge do not create blob URLs or leak into the new actor',async t=>{const h=harness(t),d=deferred();h.raw().profile_media_asset_id=asset;h.backend.download=()=>d.promise;const p=h.module.loadPhotos(h.get());await new Promise(r=>setImmediate(r));h.module.clearPhotos();d.resolve(new Blob(['bytes'],{type:'image/jpeg'}));await assert.rejects(p,{code:'STALE_CONTEXT'});assert.deepEqual(h.created,[]);});
test('photo fetch denied as unavailable produces an honest empty photo, no prior URL',async t=>{const h=harness(t);h.raw().profile_media_asset_id=asset;h.backend.download=async()=>{throw Object.assign(Error('unavailable'),{status:404});};const result=await h.module.loadPhotos(h.get());assert.equal(result.horses[0].image,'');assert.equal(result.horses[0].photoStatus,'unavailable');});
test('blob download with HTML MIME cannot become an image URL',async t=>{const h=harness(t);h.raw().profile_media_asset_id=asset;h.backend.download=async()=>new Blob(['not image'],{type:'text/html'});const result=await h.module.loadPhotos(h.get());assert.equal(result.horses[0].photoStatus,'unavailable');assert.deepEqual(h.created,[]);});
test('new photo read revokes prior private object URLs',async t=>{const h=harness(t);h.raw().profile_media_asset_id=asset;await h.module.loadPhotos(h.get());await h.module.loadPhotos(h.get());assert.deepEqual(h.revoked,['blob:test-0']);h.module.clearPhotos();assert.deepEqual(h.revoked,['blob:test-0','blob:test-1']);});

test('thumbnail rejects unsupported MIME before decoding',async()=>{await assert.rejects(makeHorseThumbnail(new Blob(['svg'],{type:'image/svg+xml'})),{code:'PHOTO_INPUT_INVALID'});});
test('thumbnail uses bounded aspect ratio, matching MIME, and closes decoded bitmap',async t=>{
 const originalBitmap=globalThis.createImageBitmap,originalDocument=globalThis.document;let closed=false,drawn=false;
 const canvas={width:0,height:0,getContext:()=>({drawImage(){drawn=true;}}),toBlob:(callback,type)=>callback(new Blob(['small'],{type}))};
 globalThis.createImageBitmap=async()=>({width:2000,height:1000,close(){closed=true;}});globalThis.document={createElement:()=>canvas};t.after(()=>{globalThis.createImageBitmap=originalBitmap;globalThis.document=originalDocument;});
 const result=await makeHorseThumbnail(sourceFile());assert.equal(result.type,'image/jpeg');assert.equal(canvas.width,640);assert.equal(canvas.height,320);assert.equal(drawn,true);assert.equal(closed,true);
});
