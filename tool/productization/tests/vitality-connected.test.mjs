import test from 'node:test';
import assert from 'node:assert/strict';
import {createVitalityBackend} from '../../../apps/avaryn/src/vitality-backend.js';
import {createVitalityController,readVitality} from '../../../apps/avaryn/src/vitality.js';
const A='10000000-0000-4000-8000-000000000001',B='10000000-0000-4000-8000-000000000002',DAY='2026-09-11';
const doc=(focus='')=>({warmup:null,reflection:null,focus,routines:{}});
const projection=(id=A,day=DAY,row=0,document=doc())=>({profile_id:id,on_date:day,row_version:row,document,exists:row>0});
const live=(id=A,day=DAY,value=projection(id,day))=>({today:day,persona:'owner',horses:[],activities:[],functionProfiles:{[id]:['rider']},backend:{connected:true,actor:{id,name:'Synthetic',accessibleHorseIds:[],personalHorseIds:[],assignedHorseIds:[]},calendar:{today_date:day},capabilities:{},vitality:value}});
const defer=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
const tick=()=>new Promise(r=>setImmediate(r));
function ui(t,{state=live(),remote}={}){
 let current=state,activeForm=null,html='',seq=0,closed=0,rendered=0,buttons=[],messages=[];
 const original={document:globalThis.document,FormData:globalThis.FormData};
 const modal={open:false,dataset:{viewId:''},querySelector:()=>activeForm,querySelectorAll:()=>activeForm?.controls||buttons};
 globalThis.document={getElementById:id=>id==='modal'?modal:activeForm?.id===id?activeForm:null};
 globalThis.FormData=class{constructor(form){this.values=form.values;}get(k){return this.values[k]??null;}getAll(k){return this.values[k]??[];}};
 t.after(()=>{globalThis.document=original.document;globalThis.FormData=original.FormData;});
 let storageReads=0,storageWrites=0;
 const storage={getItem(){storageReads++;throw Error('No connected local fallback');},setItem(){storageWrites++;throw Error('No connected local fallback');}};
 const showModal=(title,body,footer='')=>{
  if(activeForm)activeForm.isConnected=false;for(const b of buttons)b.isConnected=false;
  html=body+footer;modal.open=true;modal.dataset.viewId=String(++seq);
  buttons=[...html.matchAll(/<button\b([^>]*)>/g)].map(m=>({tagName:'BUTTON',disabled:false,isConnected:true,dataset:Object.fromEntries([...m[1].matchAll(/data-([a-z-]+)="([^"]*)"/g)].map(a=>[a[1].replace(/-([a-z])/g,(_,c)=>c.toUpperCase()),a[2]]))}));
  const id=body.match(/<form id="([^"]+)"/);
  activeForm=id?{id:id[1],isConnected:true,values:{},error:{hidden:true,textContent:''},getAttribute(k){return this[k];},querySelector(){return this.error;}}:null;
  if(activeForm){activeForm.controls=[{tagName:'TEXTAREA',disabled:false},{tagName:'SELECT',disabled:false},{tagName:'BUTTON',disabled:false}];activeForm.querySelectorAll=()=>activeForm.controls;}
 };
 const controller=createVitalityController({getState:()=>current,remote,storage,showModal,closeModal(){closed++;modal.open=false;if(activeForm)activeForm.isConnected=false;},toast:v=>messages.push(v),render(){rendered++;},navigate(){}});
 return {controller,storage,modal,messages,set(s){current=s;},get state(){return current;},get form(){return activeForm;},get html(){return html;},get closed(){return closed;},get rendered(){return rendered;},get localCalls(){return storageReads+storageWrites;},
  open(action='vitality-focus',data={}){return controller.handleAction(action,{dataset:data});},
  submit(values){const form=activeForm;Object.assign(form.values,values);controller.handleSubmit(form,{preventDefault(){}});return form;},
  dismiss(){modal.open=false;if(activeForm)activeForm.isConnected=false;},unrelated(){showModal('Other','<form id="other-form"></form>');}
 };
}
function adapter(api,{state=live()}={}){let current=state;return {get state(){return current;},set(s){current=s;},remote:createVitalityBackend({getState:()=>current,getBackend:()=>({apiRequest:api})})};}

test('connected read never imports or falls back to a legacy browser document',()=>{
 let called=0;const storage={getItem(){called++;return JSON.stringify({version:1,days:{[DAY]:doc('Old private local')}});}};
 assert.equal(readVitality(live(),{storage}).focus,'');const missing=live();delete missing.backend.vitality;
 assert.equal(readVitality(missing,{storage}).available,false);assert.equal(called,0);
});
test('connected document from another actor or day is unavailable and cannot expose private focus',()=>{
 for(const value of [projection(B),projection(A,'2026-09-10')]){value.document.focus='Other private';const result=readVitality(live(A,DAY,value));assert.equal(result.available,false);assert.equal(result.focus,'');}
});
test('missing remote adapter does not save or fall back locally',async t=>{
 const h=ui(t);h.open();const form=h.submit({focus:'My input'});await tick();assert.equal(h.localCalls,0);assert.equal(h.modal.open,true);assert.equal(form.values.focus,'My input');assert.equal(form.error.hidden,false);assert.equal(h.messages.length,0);
});
test('current actor server load validates profile and exact requested day',async()=>{
 const calls=[],a=adapter(async(name,params)=>{calls.push({name,params});return projection(A,DAY,2,doc('Server focus'));});
 const value=await a.remote.load(a.state);assert.equal(value.backend.vitality.document.focus,'Server focus');assert.deepEqual(calls,[{name:'get_c010_my_vitality_day',params:{p_on_date:DAY}}]);
});
for(const value of [projection(B),projection(A,'2026-09-10')])test('server load refuses mismatched private scope '+(value.profile_id===A?'day':'actor'),async()=>{
 const a=adapter(async()=>value);await assert.rejects(a.remote.load(a.state));assert.equal(a.state.backend.vitality.document.focus,'');
});
test('server save uses exact CAS/document/requestID and verifies readback before publishing',async()=>{
 const gate=defer(),calls=[],document=doc('Server save');const a=adapter(async(name,params,options)=>{calls.push({name,params,options});if(name.startsWith('save'))return {on_date:DAY,row_version:1};return gate.promise;});
 let settled=false;const saving=a.remote.save({document,rowVersion:0,requestId:A}).then(v=>{settled=true;return v;});await tick();assert.equal(settled,false);assert.equal(a.state.backend.vitality.row_version,0);
 gate.resolve(projection(A,DAY,1,document));assert.equal(await saving,true);assert.equal(a.state.backend.vitality.row_version,1);
 assert.deepEqual(calls[0],{name:'save_c010_my_vitality_day',params:{p_on_date:DAY,p_expected_row_version:0,p_document:document,p_request_id:A},options:{write:true}});
});
test('readback older than accepted write cannot report success',async()=>{
 const a=adapter(async name=>name.startsWith('save')?{on_date:DAY,row_version:2}:projection(A,DAY,1));
 await assert.rejects(a.remote.save({document:doc('New'),rowVersion:1,requestId:A}),e=>e.uncertain===true);
});
test('readback failure after accepted mutation remains uncertain for exact request retry',async()=>{
 const a=adapter(async name=>{if(name.startsWith('save'))return {on_date:DAY,row_version:1};throw Object.assign(Error('Read timeout'),{code:'NETWORK',uncertain:false});});
 await assert.rejects(a.remote.save({document:doc('New'),rowVersion:0,requestId:A}),e=>e.uncertain===true);
});
test('actor switch while save is pending publishes no old actor data',async()=>{
 const gate=defer();let reads=0;const a=adapter(async name=>{if(name.startsWith('save'))return gate.promise;reads++;return projection();});
 const pending=a.remote.save({document:doc('A'),rowVersion:0,requestId:A});a.set(live(B));gate.resolve({on_date:DAY,row_version:1});assert.equal(await pending,false);assert.equal(reads,0);assert.equal(a.state.backend.vitality.profile_id,B);
});
test('same actor new day while readback is pending does not publish yesterday',async()=>{
 const gate=defer(),a=adapter(async name=>name.startsWith('save')?{on_date:DAY,row_version:1}:gate.promise);
 const pending=a.remote.save({document:doc('Yesterday'),rowVersion:0,requestId:A});await tick();a.set(live(A,'2026-09-12'));gate.resolve(projection(A,DAY,1,doc('Yesterday')));
 assert.equal(await pending,false);assert.equal(a.state.backend.vitality.on_date,'2026-09-12');assert.equal(a.state.backend.vitality.document.focus,'');
});
test('remote request timeout freezes input and retries exact captured payload/CAS/requestID',async t=>{
 const calls=[];let attempt=0;const h=ui(t,{remote:{save:async request=>{calls.push(structuredClone(request));if(attempt++===0)throw Object.assign(Error('Uncertain'),{uncertain:true});return true;}}});
 h.open();const form=h.submit({focus:'Keep exact draft'});await tick();assert.equal(form.error.hidden,false);assert.equal(form.controls[0].disabled,true);assert.equal(form.controls[2].disabled,false);
 form.values.focus='Synthetic programmatic change';h.submit({});await tick();assert.deepEqual(calls[1],calls[0]);assert.equal(calls.length,2);assert.equal(h.localCalls,0);
});
test('definite server refusal preserves draft and resets request identity for corrected input',async t=>{
 const calls=[];const h=ui(t,{remote:{save:async request=>{calls.push(structuredClone(request));throw Object.assign(Error('Invalid data'),{code:'INPUT_INVALID'});}}});h.open();const form=h.submit({focus:'First'});await tick();h.submit({focus:'Corrected'});await tick();
 assert.equal(form.controls[0].disabled,false);assert.notEqual(calls[0].requestId,calls[1].requestId);assert.equal(calls[1].document.focus,'Corrected');assert.equal(h.modal.open,true);
});
test('duplicate submit while saving sends only one server mutation',async t=>{
 const gate=defer();let writes=0;const h=ui(t,{remote:{save:async()=>{writes++;return gate.promise;}}});h.open();h.submit({focus:'Once'});h.submit({focus:'Twice'});assert.equal(writes,1);gate.resolve(true);await tick();
});
test('save completion after closing its modal cannot reopen a reflection or show success',async t=>{
 const gate=defer();const h=ui(t,{remote:{save:()=>gate.promise}});h.open('vitality-reflection');h.submit({focus:'Private'});h.dismiss();gate.resolve(true);await tick();assert.equal(h.modal.open,false);assert.equal(h.messages.length,0);
});
test('save completion cannot close or overwrite a newer unrelated modal',async t=>{
 const gate=defer();const h=ui(t,{remote:{save:()=>gate.promise}});h.open();h.submit({focus:'Private'});h.unrelated();const viewId=h.modal.dataset.viewId;
 gate.resolve(true);await tick();assert.equal(h.modal.open,true);assert.equal(h.modal.dataset.viewId,viewId);assert.equal(h.form.id,'other-form');assert.equal(h.messages.length,0);
});
test('actor A→B→A invalidates old form completion even when actor ID matches again',async t=>{
 const gate=defer();const h=ui(t,{remote:{save:()=>gate.promise}});h.open();h.submit({focus:'Old A'});h.set(live(B));h.controller.syncContext();h.set(live(A));h.controller.syncContext();h.unrelated();const viewId=h.modal.dataset.viewId;
 gate.resolve(true);await tick();assert.equal(h.modal.open,true);assert.equal(h.modal.dataset.viewId,viewId);assert.equal(h.messages.length,0);assert.equal(h.localCalls,0);
});
test('same actor day change rejects detached old submit without any remote write',async t=>{
 let writes=0;const h=ui(t,{remote:{save:async()=>{writes++;return true;}}});h.open();const old=h.form;h.set(live(A,'2026-09-12'));h.controller.syncContext();old.values.focus='Yesterday';h.controller.handleSubmit(old,{preventDefault(){}});await tick();assert.equal(writes,0);assert.equal(h.localCalls,0);
});

test('LIVE two actual sessions share only the synthetic actor day with CAS and exact retry',{skip:process.env.AVARYN_VITALITY_LIVE!=='1'},async()=>{
 const {createBackendClient}=await import('../../../apps/avaryn/src/backend-client.js');
 const {readFile,writeFile}=await import('node:fs/promises');const {resolve}=await import('node:path');const {randomUUID,createHash}=await import('node:crypto');
 const root=resolve(import.meta.dirname,'../../..'),base=resolve(root,'.avaryn-local/productization-20260911');
 const configBytes=await readFile(resolve(base,'private/dev-vitality-server.json')),config=JSON.parse(configBytes);
 assert.equal(config.projectId,'avaryn-c010-vitality-20260911-a');assert.equal(config.upstream,'http://127.0.0.1:56801');
 const authProof=JSON.parse(await readFile(resolve(base,'evidence/auth-live-http.json'),'utf8'));
 const actor=JSON.parse(await readFile(authProof.privateFixture,'utf8'));assert.equal(actor.target,config.projectId);assert.equal(actor.confirmed,true);assert.equal(actor.email.endsWith('@example.invalid'),true);
 const requests=[],checks=[],clients=[];let failed=false,step='login';
 const check=(name,condition)=>{step=name;assert.equal(Boolean(condition),true,name);checks.push({name,status:'PASS'});};
 const fetchImpl=async(path,options)=>{assert.equal(path.startsWith('/api/'),true);const target=new URL(path.slice(4),config.upstream);assert.equal(target.origin,config.upstream);
  const response=await fetch(target,{...options,redirect:'error',headers:{...options.headers,apikey:config.anonKey,Origin:config.upstream}});const record={method:options.method||'GET',path:target.pathname,status:response.status};if(target.pathname==='/auth/v1/logout'&&!response.ok){const body=await response.clone().json();if(/^[a-z_]+$/.test(body.code||''))record.authCode=body.code;}requests.push(record);return response;
 };
 const client=()=>{const values=new Map();const c=createBackendClient({fetchImpl,storage:{getItem:async k=>values.get(k),setItem:async(k,v)=>values.set(k,v),removeItem:async k=>values.delete(k)}});clients.push({c,values});return c;};
 let day,versionBefore,versionAfter;
 try{
  const one=client(),two=client();await one.login(actor.email,actor.password);await two.login(actor.email,actor.password);
  const state1=await one.load({organizationId:null}),state2=await two.load({organizationId:null});
  check('Both authenticated clients resolve exactly the same synthetic profile',state1.backend.actor.id===actor.profileId&&state2.backend.actor.id===actor.profileId);
  day=state1.backend.calendar.today_date;check('Both clients use the same server calendar day',day===state2.backend.calendar.today_date);
  const a=createVitalityBackend({getState:()=>state1,getBackend:()=>({apiRequest:(...args)=>one.requestRpc(...args)})});
  const b=createVitalityBackend({getState:()=>state2,getBackend:()=>({apiRequest:(...args)=>two.requestRpc(...args)})});
  await a.load(state1);await b.load(state2);versionBefore=state1.backend.vitality.row_version;
  check('Both clients start with the same canonical version',versionBefore===state2.backend.vitality.row_version);
  const first={...state1.backend.vitality.document,focus:'Synthetische Vitality-proef: rustig voorbereiden.'};
  check('Client one saves and verifies its own focus',await a.save({document:first,rowVersion:versionBefore,requestId:randomUUID()}));
  check('Readback increments version once',state1.backend.vitality.row_version===versionBefore+1&&state1.backend.vitality.document.focus===first.focus);
  let stale;try{await b.save({document:{...first,focus:'Verouderde synthetische invoer'},rowVersion:versionBefore,requestId:randomUUID()});}catch(error){stale=error;}
  check('Client two stale CAS is refused without overwrite',stale?.code==='C010_VITALITY_VERSION_STALE'||stale?.status===409);
  await b.load(state2);check('Client two reload sees client one focus',state2.backend.vitality.document.focus===first.focus&&state2.backend.vitality.row_version===versionBefore+1);
  const second={...state2.backend.vitality.document,focus:'Synthetische Vitality-proef: bevestigd op twee clients.'};const request={document:second,rowVersion:versionBefore+1,requestId:randomUUID()};
  check('Client two corrected save succeeds after reload',await b.save(request));versionAfter=state2.backend.vitality.row_version;
  check('Corrected save increments only once',versionAfter===versionBefore+2);
  check('Identical request retry verifies successfully',await b.save(request));check('Idempotent retry does not increment version',state2.backend.vitality.row_version===versionAfter);
  await a.load(state1);check('Client one reload sees client two focus and same version',state1.backend.vitality.document.focus===second.focus&&state1.backend.vitality.row_version===versionAfter);
  await one.logout();check('First device logout clears only its own stored session',clients[0].values.size===0);
  check('Second device session remains valid after first device logout',await two.restore());
  check('Second device can still read its profile', (await two.load({organizationId:null})).backend.actor.id===actor.profileId);
 }catch{failed=true;throw Error('Isolated Vitality gate failed at: '+step);}
 finally{
  for(const {c,values} of clients)if(values.size)try{await c.logout();}catch{failed=true;}
  const paths=['apps/avaryn/src/backend-client.js','apps/avaryn/src/vitality-backend.js','apps/avaryn/src/vitality.js','tool/productization/tests/vitality-connected.test.mjs'];const sha={};for(const p of paths)sha[p]=createHash('sha256').update(await readFile(resolve(root,p))).digest('hex');
  await writeFile(resolve(base,'evidence/vitality-connected-live.json'),JSON.stringify({status:failed?'FAIL':'PASS',checkedAt:new Date().toISOString(),target:config.projectId,apiOrigin:config.upstream,configSha256:createHash('sha256').update(configBytes).digest('hex'),profileId:actor.profileId,onDate:day,versionBefore,versionAfter,checks,checkCount:checks.length,requests,sha256:sha,privateFixture:authProof.privateFixture,sessionsCleared:clients.every(x=>x.values.size===0),limits:['Two real API sessions, not two browsers/devices.','Only the existing isolated synthetic actor day focus is changed; no SQL, grants, other actors or domain data changed.']},null,2)+'\n');
  if(failed)throw Error('Isolated Vitality flow or session cleanup failed; see sanitized receipt.');
 }
});

test('mismatched actor/day cached document cannot be used as the basis of a connected save',async t=>{
 let writes=0;const state=live(A,DAY,projection(B,DAY,3,doc('Other private focus')));
 const h=ui(t,{state,remote:{save:async()=>{writes++;return true;}}});h.open();const form=h.submit({focus:'New current actor focus'});await tick();
 assert.equal(writes,0);assert.equal(form.error.hidden,false);assert.equal(h.localCalls,0);assert.equal(h.modal.open,true);
});
