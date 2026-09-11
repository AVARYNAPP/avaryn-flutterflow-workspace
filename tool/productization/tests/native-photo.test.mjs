import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createNativeHorsePhoto,nativePhotoUrl} from '../../../apps/avaryn/src/native-photo.js';
import {createHorseProfile} from '../../../apps/avaryn/src/horse-profile.js';
const defer=()=>{let resolve,reject;const promise=new Promise((r,j)=>{resolve=r;reject=j;});return{promise,resolve,reject};};
const tick=()=>new Promise(r=>setImmediate(r));
const address='capacitor://localhost/_capacitor_file_/private/var/mobile/photo.jpg';
const jpeg=()=>new Blob([new Uint8Array([0xff,0xd8,0xff,0xd9])],{type:'image/jpeg'});
const photo=()=>new File([jpeg()],'paardenfoto.jpg',{type:'image/jpeg'});
function bridge(overrides={}){
 const calls=[];let valid=true;
 const h={result:{type:0,webPath:address,thumbnail:'must-not-use'},response:{ok:true,blob:async()=>jpeg()},capture:async()=>h.result};
 const instance=createNativeHorsePhoto({platform:'ios',loadCamera:async()=>({Camera:{takePhoto:async options=>{calls.push(['camera',options]);return h.capture();}},EncodingType:{JPEG:0}}),fetchLocal:async(...args)=>{calls.push(['fetch',...args]);return h.response;},...overrides});
 return {...instance,calls,h,run:()=>instance.takePhoto({isCurrent:()=>valid}),invalidate:()=>{valid=false;}};
}
test('pinned iOS and Android local paths work; cross-platform and foreign paths fail closed',()=>{
 assert.equal(nativePhotoUrl(address,'ios'),address);const android=address.replace('capacitor:','https:');assert.equal(nativePhotoUrl(android,'android'),android);
 for(const [raw,platform] of [[address,'android'],[android,'ios'],[address,'web'],['https://remote.invalid/_capacitor_file_/x.jpg','android'],['http://localhost/_capacitor_file_/x.jpg','android'],['https://localhost:444/_capacitor_file_/x.jpg','android'],['https://user@localhost/_capacitor_file_/x.jpg','android'],['file:///private/photo.jpg','ios'],['blob:local','ios'],['capacitor://localhost/photo.jpg','ios'],[address+'?token=x','ios'],[address+'#fragment','ios'],[address.replace('photo.jpg','../photo.jpg'),'ios'],[address.replace('photo.jpg','%2e%2e/photo.jpg'),'ios'],[address.replace('photo.jpg','%252e%252e/photo.jpg'),'ios'],[address.replace('photo.jpg','%5cphoto.jpg'),'ios'],[address.replace('photo.jpg','%00photo.jpg'),'ios']])assert.equal(nativePhotoUrl(raw,platform),null,raw);
});
test('camera uses JPEG, no gallery save or editor; local original fetch has no credentials or headers',async()=>{
 const h=bridge(),file=await h.run();assert.equal(file.name,'paardenfoto.jpg');assert.equal(file.type,'image/jpeg');assert.deepEqual(new Uint8Array(await file.arrayBuffer()),new Uint8Array(await jpeg().arrayBuffer()));
 assert.deepEqual(h.calls,[['camera',{encodingType:0,quality:90,correctOrientation:true,saveToGallery:false,editable:'no'}],['fetch',address,{credentials:'omit',redirect:'error',cache:'no-store'}]]);
});
test('malformed or foreign native response never causes a fetch',async()=>{
 for(const result of [{type:1,webPath:address},{type:0,webPath:'https://remote.invalid/photo.jpg'},{type:0,uri:'file:///photo.jpg'},null]){const h=bridge();h.h.result=result;await assert.rejects(h.run(),{code:'NATIVE_PHOTO_UNAVAILABLE'});assert.equal(h.calls.filter(c=>c[0]==='fetch').length,0);}
});
test('cancel is not a failure and never fetches bytes',async()=>{const h=bridge();h.h.capture=async()=>{throw {code:'OS-PLUG-CAMR-0006'};};assert.equal(await h.run(),null);assert.equal(h.calls.length,1);});
test('denied camera has useful safe text; unavailable camera preserves gallery alternative',async()=>{
 for(const code of ['OS-PLUG-CAMR-0003','OS-PLUG-CAMR-0007','unknown']){const h=bridge();h.h.capture=async()=>{throw {code,message:address};};await assert.rejects(h.run(),e=>e.userMessage.includes('bestaande foto')&&!e.message.includes(address));assert.equal(h.calls.length,1);}
});
test('non-JPEG, empty and oversized returned bytes cannot become selected files',async()=>{
 for(const blob of [new Blob(['x'],{type:'text/html'}),new Blob([],{type:'image/jpeg'}),new Blob([new Uint8Array(10485761)],{type:'image/jpeg'})]){const h=bridge();h.h.response.blob=async()=>blob;await assert.rejects(h.run(),{code:'PHOTO_INPUT_INVALID'});}
});
test('redirected or unsuccessful local resource is rejected',async()=>{for(const response of [{ok:false},{ok:true,redirected:true}]){const h=bridge();h.h.response=response;await assert.rejects(h.run(),{code:'NATIVE_PHOTO_UNAVAILABLE'});}});
test('missing context guard and disposed bridge cannot open camera',async()=>{const h=bridge();await assert.rejects(h.takePhoto(),{code:'STALE_CONTEXT'});h.dispose();await assert.rejects(h.run(),{code:'STALE_CONTEXT'});assert.equal(h.calls.length,0);});
test('late camera module import cannot launch for another form',async()=>{const d=defer();let called=false;const h=bridge({loadCamera:()=>d.promise}),p=h.run();h.invalidate();d.resolve({Camera:{takePhoto(){called=true;}},EncodingType:{JPEG:0}});await assert.rejects(p,{code:'STALE_CONTEXT'});assert.equal(called,false);});
test('late capture cannot read any local bytes after account or modal invalidation',async()=>{const d=defer(),h=bridge();h.h.capture=()=>d.promise;const p=h.run();await tick();h.invalidate();d.resolve(h.h.result);await assert.rejects(p,{code:'STALE_CONTEXT'});assert.equal(h.calls.filter(c=>c[0]==='fetch').length,0);});
test('late local response or blob cannot return a file into changed context',async()=>{
 for(const stage of ['response','blob']){const d=defer();let valid=true;const h=bridge(stage==='response'?{fetchLocal:()=>d.promise}:{});if(stage==='blob')h.h.response.blob=()=>d.promise;const p=h.run();await tick();h.invalidate();d.resolve(stage==='response'?{ok:true,blob:async()=>jpeg()}:jpeg());await assert.rejects(p,{code:'STALE_CONTEXT'});}
});
test('restored Android result is discarded even when it contains unreadable data; only reopen advice',()=>{
 const h=bridge();h.handleRestoredResult({pluginId:'Other',methodName:'takePhoto'});assert.equal(h.getRecoveryNotice(),'');h.handleRestoredResult({pluginId:'Camera',methodName:'takePhoto',get data(){throw Error('Must never access restored bytes');}});assert.match(h.getRecoveryNotice(),/Open het fotoformulier opnieuw/);assert.equal(h.calls.length,0);h.dispose();assert.equal(h.getRecoveryNotice(),'');
});

const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`,horse=id(1),asset=id(2);
function editor(t,nativePhoto){
 let state={horseId:horse,backend:{connected:true,actor:{id:id(3)},horseCapabilities:{[horse]:{edit:true}}}},form,last,html;
 const modal={open:false,dataset:{viewId:''},querySelector:()=>form},calls=[];
 const raw={horse_id:horse,display_name:'Luna',row_version:4,can_edit:true,lifecycle_status:'active',profile_media_asset_id:null};
 const previous=Object.getOwnPropertyDescriptor(globalThis,'document');globalThis.document={querySelector:()=>modal};
 t.after(()=>{if(previous)Object.defineProperty(globalThis,'document',previous);else delete globalThis.document;});
 const backend={apiRequest:async(name,p)=>{calls.push([name,p]);if(name==='list_c010_horses')return[{...raw}];if(name==='set_canonical_horse_profile_media')return{horse_id:horse,profile_media_asset_id:asset,row_version:5};throw Error(name);},mediaRequest:async body=>{calls.push([body.action,body]);return body.action==='canonical_create'?{media_asset_id:asset,row_version:1,status:'pending',uploads:['original','thumbnail'].map(variant=>({variant,object_path:`canonical/${horse}/${asset}/${variant}`,expected_mime_type:'image/jpeg',max_byte_size:variant==='original'?10485760:1048576,signed_upload_url:'synthetic',upload_token:'synthetic'}))}:{media_asset_id:asset,row_version:2,status:'ready'};},uploadHorseMedia:async(d,b)=>calls.push(['upload',d.variant,b]),downloadHorseMedia:async()=>jpeg()};
 const profile=createHorseProfile({getState:()=>state,getBackend:()=>backend,nativePhoto,esc:s=>String(s).replaceAll('<','&lt;'),makeThumbnail:async()=>jpeg(),showModal:(title,body)=>{html=body;modal.dataset.viewId=String(Number(modal.dataset.viewId||0)+1);form=makeForm();profile.capture(form);modal.open=true;},perform:(f,operation)=>{last=operation(id(9),()=>true);last.catch(()=>{});return last;}});
 function makeForm(){
  const input={files:[],required:true,disabled:false,listeners:{},addEventListener(name,fn){this.listeners[name]=fn;}},submit={disabled:false},camera={disabled:false},label={textContent:''},alert={textContent:''};
  const f={id:'core-horse-photo-form',isConnected:true,dataset:{},input,submit,camera,label,alert,querySelector:s=>s==='[name="photo"]'?input:s==='[data-native-photo-label]'?label:s==='.form-error'?alert:null,querySelectorAll:()=>[input,submit,camera]};
  camera.closest=()=>f;return f;
 }
 return{profile,modal,calls,open:()=>profile.open(horse,true),form:()=>form,html:()=>html,get:()=>state,set:v=>{state=v;},capture:()=>profile.handleAction('horse-camera',form.camera),submit:()=>{profile.handleSubmit(form,{preventDefault(){}});return last;},mutations:()=>calls.filter(c=>c[0]!=='list_c010_horses')};
}
test('web photo form keeps existing required input and has no camera action',async t=>{const h=editor(t);await h.open();assert.match(h.html(),/<input type="file" name="photo" accept="image\/jpeg,image\/png,image\/webp" required>/);assert.doesNotMatch(h.html(),/horse-camera|data-native-photo-label/);});
test('native capture uses owned form, shows selected file, bypasses only file required, and uploads only on Save',async t=>{
 let guard;const selected=photo(),h=editor(t,{takePhoto:async args=>{guard=args.isCurrent;return selected;}});await h.open();assert.match(h.html(),/data-action="horse-camera">Foto maken/);h.capture();await tick();const f=h.form();assert.equal(guard(),true);assert.equal(f.input.required,false);assert.match(f.label.textContent,/paardenfoto.jpg.*camera/);assert.equal(f.input.files.length,0,'No DataTransfer/fileinput assignment');assert.equal(h.mutations().length,0);await h.submit();assert.equal(h.calls.find(c=>c[0]==='upload'&&c[1]==='original')[2],selected);assert.deepEqual(h.mutations().map(c=>c[0]),['canonical_create','upload','upload','canonical_finalize','set_canonical_horse_profile_media']);
});
test('camera pending freezes chooser and save; double click and forged submit cannot upload',async t=>{
 const d=defer();let count=0;const h=editor(t,{takePhoto:()=>{count++;return d.promise;}});await h.open();h.capture();assert.ok(h.form().input.disabled&&h.form().submit.disabled&&h.form().camera.disabled);h.capture();h.submit();assert.equal(count,1);assert.equal(h.mutations().length,0);d.resolve(null);await tick();assert.ok(!h.form().input.disabled&&!h.form().submit.disabled&&!h.form().camera.disabled);assert.equal(h.form().input.required,true);
});
test('cancellation keeps previous camera selection and permission denial keeps gallery choice with error',async t=>{
 let take=async()=>photo();const h=editor(t,{takePhoto:()=>take()});await h.open();h.capture();await tick();const prior=h.form().label.textContent;take=async()=>null;h.capture();await tick();assert.equal(h.form().label.textContent,prior);assert.equal(h.form().input.required,false);
 const gallery=new File([jpeg()],'gallery.jpg',{type:'image/jpeg'});h.form().input.files=[gallery];h.form().input.listeners.change();take=async()=>{throw Object.assign(Error('safe'),{userMessage:'Kies een bestaande foto.'});};h.capture();await tick();assert.equal(h.form().input.files[0],gallery);assert.equal(h.form().input.required,true);assert.equal(h.form().input.disabled,false);assert.equal(h.form().alert.textContent,'Kies een bestaande foto.');await h.submit();assert.equal(h.calls.find(c=>c[0]==='upload')[2],gallery);
});
test('explicit gallery replacement wins over camera RAM and label uses textContent',async t=>{
 const h=editor(t,{takePhoto:async()=>photo()});await h.open();h.capture();await tick();const gallery=new File([jpeg()],'<img onerror=bad>.jpg',{type:'image/jpeg'});h.form().input.files=[gallery];h.form().input.listeners.change();assert.equal(h.form().input.required,true);assert.equal(h.form().label.textContent,'Gekozen foto: <img onerror=bad>.jpg');assert.equal(h.form().label.innerHTML,undefined);await h.submit();assert.equal(h.calls.find(c=>c[0]==='upload')[2],gallery);
});
test('old gallery filename is cleared only after successful camera selection; cancel and denial preserve it',async t=>{
 let take=async()=>null;const h=editor(t,{takePhoto:()=>take()});await h.open();const input=h.form().input,gallery=new File([jpeg()],'gallery.jpg',{type:'image/jpeg'});let value='C:\\fakepath\\gallery.jpg',clears=0;input.files=[gallery];
 Object.defineProperty(input,'value',{get:()=>value,set:next=>{assert.equal(next,'','Fileinput may only be cleared, never programmatically populated');value=next;input.files=[];clears++;}});
 h.capture();await tick();assert.equal(clears,0);assert.equal(input.files[0],gallery);
 take=async()=>{throw Object.assign(Error('denied'),{userMessage:'Geen cameratoegang.'});};h.capture();await tick();assert.equal(clears,0);assert.equal(value,'C:\\fakepath\\gallery.jpg');
 const selected=photo();take=async()=>selected;h.capture();await tick();assert.equal(clears,1);assert.equal(value,'');assert.deepEqual(input.files,[]);assert.match(h.form().label.textContent,/paardenfoto.jpg/);await h.submit();assert.equal(h.calls.find(c=>c[0]==='upload')[2],selected);
});
for(const change of ['actor','round-trip','close','replacement'])test('late native capture discarded after '+change,async t=>{
 const d=defer(),h=editor(t,{takePhoto:()=>d.promise});await h.open();const f=h.form();h.capture();
 if(change==='actor')h.set(structuredClone(h.get()));
 if(change==='round-trip'){const old=h.get();h.profile.dispose();h.set(structuredClone(old));h.set(old);}
 if(change==='close')h.modal.open=false;
 if(change==='replacement')h.modal.dataset.viewId='different-view';
 d.resolve(photo());await tick();assert.equal(f.input.required,true);assert.equal(f.label.textContent,'');assert.equal(f.alert.textContent,'');assert.equal(f.submit.disabled,false);assert.equal(h.mutations().length,0);
});
test('selected native file cannot submit from a replaced modal even if actor is unchanged',async t=>{const h=editor(t,{takePhoto:async()=>photo()});await h.open();h.capture();await tick();h.modal.dataset.viewId='replacement';h.submit();assert.equal(h.mutations().length,0);assert.match(h.form().alert.textContent,/Open dit paard opnieuw/);});
test('native restored notice is fixed copy in photo form, never restored bytes',async t=>{const adapter=bridge();adapter.handleRestoredResult({pluginId:'Camera',methodName:'takePhoto'});const h=editor(t,adapter);await h.open();assert.match(h.html(),/Er is niets opgeslagen/);assert.equal(h.mutations().length,0);});
test('invalid injected native file retains required input and does not upload',async t=>{const h=editor(t,{takePhoto:async()=>new File(['<svg/>'],'x.svg',{type:'image/svg+xml'})});await h.open();h.capture();await tick();assert.equal(h.form().input.required,true);assert.equal(h.form().camera.disabled,false);assert.match(h.form().alert.textContent,/maximaal 10 MB/);assert.equal(h.mutations().length,0);});
test('actual app injects optional native adapter once; pinned native camera supports requested API',async()=>{
 const root=new URL('../../../apps/avaryn/',import.meta.url),app=await readFile(new URL('src/app.js',root),'utf8'),pkg=JSON.parse(await readFile(new URL('node_modules/@capacitor/camera/package.json',root))),types=await readFile(new URL('node_modules/@capacitor/camera/dist/esm/definitions.d.ts',root),'utf8');assert.equal((app.match(/nativePhoto:platform\.horsePhoto/g)||[]).length,1);assert.equal(pkg.version,'8.2.4');assert.match(types,/takePhoto\(options\??: TakePhotoOptions\)/);assert.match(types,/saveToGallery\??: boolean/);
});
