import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createAuthorityTransfer} from '../../../apps/avaryn/src/authority-transfer.js';
const A='10000000-0000-4000-8000-000000000001',B='10000000-0000-4000-8000-000000000002',ORG='20000000-0000-4000-8000-000000000001',HORSE='30000000-0000-4000-8000-000000000001',TRANSFER='40000000-0000-4000-8000-000000000001',ARCHIVE='20000000-0000-4000-8000-000000000002',TOKEN='a'.repeat(64);
const tick=()=>new Promise(r=>setImmediate(r));
const defer=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
const state=actor=>({horses:[{id:HORSE,name:'Own horse',lifecycleStatus:'active',capabilities:{primary:true}}],backend:{connected:true,actor:{id:actor||A},organizationId:ORG,organization:{id:ORG,name:'Own stable',primary_authority_profile_id:actor||A}}});
const pending={id:TRANSFER,row_version:3,status:'pending',recipient_name:'Chosen recipient',expires_at:'2026-09-18T12:00:00Z'};
const started={transfer_id:TRANSFER,transfer_token:TOKEN,expires_at:pending.expires_at,row_version:1,applied:true};
const ARCHIVED_HORSE='30000000-0000-4000-8000-000000000002';
const archivedHorse={horse_id:ARCHIVED_HORSE,display_name:'Own archived horse',archived_at:'2026-09-10T10:00:00Z',row_version:4,access_version:2,authority_version:1,pending_transfer:null};
function fixture(t,{initial=state(),api}={}){
 let current=initial,activeForm=null,html='',seq=0,closed=0;const calls=[],operations=[],errors=[],messages=[];
 const original={document:globalThis.document,FormData:globalThis.FormData};
 const modal={open:false,dataset:{viewId:''},querySelector:selector=>selector==='form'?activeForm:selector==='[data-authority-message]'?{hidden:true,set textContent(v){messages.push(v);}}:null,replaceChildren(){html='';disconnect();activeForm=null;},close(){modal.open=false;disconnect();}};
 globalThis.document={getElementById:id=>id==='modal'?modal:activeForm?.id===id?activeForm:null};
 globalThis.FormData=class{constructor(form){this.values=form.values;}[Symbol.iterator](){return Object.entries(this.values)[Symbol.iterator]();}};
 t.after(()=>{globalThis.document=original.document;globalThis.FormData=original.FormData;});
 function disconnect(){if(activeForm){activeForm.isConnected=false;for(const c of activeForm.controls)c.isConnected=false;}}
 function showModal(title,body){disconnect();html=body;modal.open=true;modal.dataset.viewId=String(++seq);const id=body.match(/<form id="([^\"]+)"/);activeForm=null;if(id){const form={id:id[1],dataset:{},isConnected:true,values:{},getAttribute(name){return this[name];},controls:[{tagName:'INPUT',disabled:false,isConnected:true},{tagName:'SELECT',disabled:false,isConnected:true},{tagName:'BUTTON',disabled:false,isConnected:true}]};form.querySelectorAll=()=>form.controls;activeForm=form;}}
 const defaultApi=(name,params)=>{
  if(name==='list_stable_accounts')return [{organization_id:ORG,name:'Own stable',is_primary_authority:true,lifecycle_status:'active'},{organization_id:B,name:'Not owned',is_primary_authority:false,lifecycle_status:'active'}];
  if(name==='list_c010_my_archived_organizations')return [{organization_id:ARCHIVE,name:'Own archive',pending_transfer:null}];
  if(name==='list_c010_my_archived_horses')return [];
  if(name==='list_c010_horses')return [{horse_id:HORSE,is_primary_authority:true,lifecycle_status:'active'}];
  if(name==='get_stable_account_workspace')return {organization:{is_primary_authority:true,primary_authority_profile_id:current.backend.actor.id},pending_authority_transfer:null};
  if(name==='get_canonical_horse_workspace')return {pending_transfer:null};
  if(name.startsWith('initiate_'))return started;
  if(name.startsWith('preview_'))return [{transfer_id:TRANSFER,[name.includes('horse')?'horse_id':'organization_id']:name.includes('horse')?HORSE:ORG,[name.includes('horse')?'horse_name':'organization_name']:'Chosen resource',expires_at:pending.expires_at}];
  if(name.startsWith('respond_'))return [{transfer_id:TRANSFER,row_version:2,status:params.p_action==='accept'?'accepted':'declined'}];
  if(name.startsWith('revoke_'))return [{row_version:4,status:'revoked'}];
  throw Error('Unexpected RPC '+name);
 };
 const controller=createAuthorityTransfer({getState:()=>current,getBackend:()=>({apiRequest:async(name,params,options)=>{calls.push({name,params:structuredClone(params),options});return api?api(name,params,defaultApi):defaultApi(name,params);}}),showModal,closeModal(){closed++;modal.close();},toast:message=>messages.push(message),perform(form,operation,message){
  if(form.dataset.busy==='true')return;form.dataset.busy='true';const id=form.dataset.requestId||=(crypto.randomUUID());operations.push({form,operation,message,id});
  void operation(id,()=>true).catch(error=>{errors.push(error);form.dataset.uncertain=error.uncertain?'true':'false';if(!error.uncertain)delete form.dataset.requestId;}).finally(()=>{form.dataset.busy='false';});
 }});
 return {controller,calls,operations,errors,messages,modal,get form(){return activeForm;},get html(){return html;},get closed(){return closed;},get writes(){return calls.filter(c=>c.options.write);},setState:s=>{current=s;},
  action:(name,data={})=>controller.handleAction(name,{dataset:data}),submit(values={},form=activeForm){Object.assign(form.values,values);let prevented=false;const handled=controller.handleSubmit(form,{preventDefault(){prevented=true;}});return {handled,prevented};},
  afterSave(form=activeForm){modal.close();controller.afterSave(form);},unrelated(){showModal('Other','<form id="other-form"></form>');},dismiss(){modal.close();}
 };
}
async function openStart(h,kind='horse',id=HORSE){h.action('authority-transfer-start',{kind,id});await tick();return h.form;}
async function openResponse(h,kind='horse'){h.action('authority-transfer-receive',{kind});h.submit({kind,token:TOKEN});await tick();return h.form;}

test('responsibility hub shows only explicitly primary resources and archived own stables',async t=>{const h=fixture(t);h.action('authority-transfer');await tick();assert.match(h.html,/Own stable/);assert.match(h.html,/Own archive/);assert.match(h.html,/Own horse/);assert.doesNotMatch(h.html,/Not owned/);assert.equal(h.writes.length,0);});
test('demo never invokes APIs or presents a transfer mutation form',async t=>{const h=fixture(t,{initial:{backend:{connected:false}}});h.action('authority-transfer');await tick();assert.match(h.html,/Meld je aan/);h.action('authority-transfer-start',{kind:'horse',id:HORSE});assert.equal(h.calls.length,0);});
test('function preference or edit rights never substitutes primary authority',async t=>{const s=state();s.horses[0].capabilities={primary:false,edit:true};s.functionProfiles={[A]:['manager']};const h=fixture(t,{initial:s});await openStart(h);assert.equal(h.calls.length,0);assert.equal(h.form,null);});
for(const kind of ['horse','organization'])test(kind+' initiation requires explicit email/consent and sends exact canonical fields',async t=>{
 const h=fixture(t);await openStart(h,kind,kind==='horse'?HORSE:ORG);h.submit({email:'recipient@example.invalid'});assert.equal(h.writes.length,0);h.submit({email:'recipient@example.invalid',confirm:'yes'});await tick();assert.equal(h.writes.length,1);
 const c=h.writes[0];assert.equal(c.name,'initiate_'+kind+'_authority_transfer_by_email');assert.deepEqual(c.params,{[kind==='horse'?'p_horse_id':'p_organization_id']:kind==='horse'?HORSE:ORG,p_recipient_email:'recipient@example.invalid',p_correlation_id:h.operations[0].id});assert.equal(h.html.includes(TOKEN),false);const form=h.form;h.afterSave(form);assert.match(h.html,/ontvanger moet nog accepteren/);assert.ok(h.html.includes(TOKEN));assert.match(h.html,/geen e-mail/);
});
test('closed organization uses narrow owned-archive read and never opens operational workspace',async t=>{
 const h=fixture(t);h.action('authority-transfer');await tick();await openStart(h,'organization',ARCHIVE);assert.match(h.html,/blijft een gesloten stal/);h.submit({email:'recipient@example.invalid',confirm:'yes'});await tick();assert.equal(h.writes[0].params.p_organization_id,ARCHIVE);assert.equal(h.calls.some(c=>c.name==='get_stable_account_workspace'),false);
});
test('current horse primary loss between overview and editor prevents email offer',async t=>{const h=fixture(t,{api:(name,params,base)=>name==='list_c010_horses'?[{horse_id:HORSE,is_primary_authority:false,lifecycle_status:'active'}]:base(name,params)});await openStart(h);assert.equal(h.form,null);assert.equal(h.writes.length,0);assert.ok(h.messages.length);});
test('pending transfer exposes revoke form and exact CAS, never regenerates code automatically',async t=>{
 const h=fixture(t,{api:(name,params,base)=>name==='get_canonical_horse_workspace'?{pending_transfer:pending}:base(name,params)});await openStart(h);assert.equal(h.form.id,'core-authority-revoke-form');assert.match(h.html,/nog|totdat/);h.submit();await tick();assert.deepEqual(h.writes[0],{name:'revoke_horse_authority_transfer',params:{p_transfer_id:TRANSFER,p_expected_row_version:3,p_correlation_id:h.operations[0].id},options:{write:true}});h.afterSave();assert.match(h.html,/ingetrokken/);
});
test('archived transfer revoke uses the same existing organization contract',async t=>{
 const h=fixture(t,{api:(name,params,base)=>name==='list_c010_my_archived_organizations'?[{organization_id:ARCHIVE,name:'Archive',pending_transfer:pending}]:base(name,params)});h.action('authority-transfer');await tick();await openStart(h,'organization',ARCHIVE);h.submit();await tick();assert.equal(h.writes[0].name,'revoke_organization_authority_transfer');assert.equal(h.writes[0].params.p_expected_row_version,3);
});
test('recipient preview is read-only, requires exact one-time code and explicit later acceptance',async t=>{
 const h=fixture(t);h.action('authority-transfer-receive');h.submit({kind:'organization',token:'https://unknown.example/?token='+TOKEN});assert.equal(h.calls.length,0);h.submit({kind:'organization',token:TOKEN});await tick();assert.equal(h.form.id,'core-authority-response-form');assert.equal(h.writes.length,0);h.submit({response:''});assert.equal(h.writes.length,0);assert.match(h.html,/Kies wat/);
});
for(const kind of ['horse','organization'])for(const action of ['accept','decline'])test(kind+' recipient '+action+' uses guarded existing response contract',async t=>{
 const h=fixture(t);await openResponse(h,kind);h.submit({response:action});await tick();const c=h.writes[0];assert.equal(c.name,kind==='horse'?'respond_horse_authority_transfer':'respond_stable_authority_transfer');assert.deepEqual(c.params,{p_transfer_token:TOKEN,p_action:action,p_correlation_id:h.operations[0].id});h.afterSave();assert.match(h.html,action==='accept'?/overgenomen/:/geweigerd/);
});
test('wrong recipient/expired/replayed code returns no confirmation form and no write',async t=>{
 const h=fixture(t,{api:(name,params,base)=>name.startsWith('preview_')?[]:base(name,params)});h.action('authority-transfer-receive');const form=h.form;h.submit({kind:'horse',token:TOKEN});await tick();assert.equal(h.form,form);assert.equal(h.writes.length,0);assert.match(h.messages.at(-1),/hoort niet.*verlopen.*gebruikt/);
});
test('server terminal expired result never becomes accepted UI',async t=>{const h=fixture(t,{api:(name,params,base)=>name.startsWith('respond_')?{transfer_id:TRANSFER,status:'expired',row_version:2}:base(name,params)});await openResponse(h);h.submit({response:'accept'});await tick();h.afterSave();assert.match(h.html,/geen hoofdbeheer overgenomen/);});
test('malformed response is uncertain and cannot generate accepted confirmation',async t=>{const h=fixture(t,{api:(name,params,base)=>name.startsWith('respond_')?{transfer_id:B,status:'accepted',row_version:2}:base(name,params)});await openResponse(h);h.submit({response:'accept'});await tick();assert.equal(h.errors[0].uncertain,true);const html=h.html;h.afterSave();assert.equal(h.html,html);});
test('SQL business error code/status object passes unchanged to existing perform gate',async t=>{const expected=Object.assign(Error('Authoritative refusal'),{code:'PRIMARY_HORSE_AUTHORITY_REQUIRED',status:403,accessLost:true});const h=fixture(t,{api:(name,params,base)=>{if(name.startsWith('initiate_'))throw expected;return base(name,params);}});await openStart(h);h.submit({email:'recipient@example.invalid',confirm:'yes'});await tick();assert.equal(h.errors[0],expected);assert.equal(h.form.values.email,'recipient@example.invalid');});
test('uncertain initiation retries captured email and identical request, with no token duplication claim',async t=>{let attempt=0;const h=fixture(t,{api:(name,params,base)=>{if(name.startsWith('initiate_')){if(attempt++===0)throw Object.assign(Error('Timeout'),{uncertain:true});return {...started,transfer_token:null,applied:false};}return base(name,params);}});await openStart(h);h.submit({email:'first@example.invalid',confirm:'yes'});await tick();h.submit({email:'changed@example.invalid'});await tick();assert.deepEqual(h.writes[0].params,h.writes[1].params);h.afterSave();assert.match(h.html,/bestaande aanvraag/);assert.equal(h.html.includes(TOKEN),false);});
test('acknowledged mutation with failed readback is not repeated before followup',async t=>{const h=fixture(t);await openResponse(h);h.submit({response:'accept'});await tick();h.form.dataset.uncertain='true';h.submit({response:'decline'});await tick();assert.equal(h.writes.length,1);h.afterSave();assert.match(h.html,/overgenomen/);});
test('late preview cannot replace an unrelated modal or reveal its resource name',async t=>{const gate=defer(),h=fixture(t,{api:(name,params,base)=>name.startsWith('preview_')?gate.promise:base(name,params)});h.action('authority-transfer-receive');h.submit({kind:'horse',token:TOKEN});h.unrelated();gate.resolve([{horse_id:HORSE,horse_name:'Private old resource',transfer_id:TRANSFER}]);await tick();assert.equal(h.form.id,'other-form');assert.equal(h.html.includes('Private old resource'),false);});
test('account change scrubs and closes owned token sheet; return to A cannot restore it',async t=>{const h=fixture(t);await openStart(h);h.submit({email:'recipient@example.invalid',confirm:'yes'});await tick();h.afterSave();assert.ok(h.html.includes(TOKEN));h.setState(state(B));h.controller.syncContext();assert.equal(h.html,'');assert.equal(h.modal.open,false);h.setState(state(A));h.controller.syncContext();assert.equal(h.html,'');});
test('A→B→A invalidates old submitted form and late token response',async t=>{const gate=defer(),h=fixture(t,{api:(name,params,base)=>name.startsWith('initiate_')?gate.promise:base(name,params)});const form=await openStart(h);h.submit({email:'recipient@example.invalid',confirm:'yes'});h.setState(state(B));h.controller.syncContext();h.setState(state(A));h.controller.syncContext();h.unrelated();const html=h.html;gate.resolve(started);await tick();h.controller.afterSave(form);assert.equal(h.html,html);assert.equal(h.html.includes(TOKEN),false);});
test('stable context change and detached form cannot submit with retained authority metadata',async t=>{const h=fixture(t);const form=await openStart(h);const next=state();next.backend.organizationId=ARCHIVE;h.setState(next);h.controller.syncContext();h.submit({email:'recipient@example.invalid',confirm:'yes'},form);assert.equal(h.writes.length,0);});
test('resource names and token fields are escaped; no media, URL navigation or automatic sends',async t=>{const h=fixture(t,{api:(name,params,base)=>name.startsWith('preview_')?[{horse_id:HORSE,horse_name:'<img src=x onerror=alert(1)>',transfer_id:TRANSFER,expires_at:pending.expires_at}]:base(name,params)});await openResponse(h);assert.ok(h.html.includes('&lt;img'));assert.equal(h.html.includes('<img'),false);assert.equal(h.writes.length,0);});
test('one-time token is not re-shown by a second afterSave invocation',async t=>{const h=fixture(t);const form=await openStart(h);h.submit({email:'recipient@example.invalid',confirm:'yes'});await tick();h.afterSave();h.unrelated();const html=h.html;h.controller.afterSave(form);assert.equal(h.html,html);});
test('owned afterSave before generic close replaces view ID and keeps the token sheet open',async t=>{const h=fixture(t);const form=await openStart(h);h.submit({email:'recipient@example.invalid',confirm:'yes'});await tick();const previousView=h.modal.dataset.viewId;h.controller.afterSave(form);assert.equal(h.modal.open,true);assert.notEqual(h.modal.dataset.viewId,previousView);assert.ok(h.html.includes(TOKEN));assert.equal(form.isConnected,false);});

test('owned archived horses come only from the actorless archive projection, not cached primary flags',async t=>{
 const s=state();s.horses.push({id:ARCHIVED_HORSE,name:'Cached archive name',lifecycleStatus:'active',capabilities:{primary:true}},{id:B,name:'Unverified cached archive',lifecycleStatus:'archived',capabilities:{primary:true}});
 const h=fixture(t,{initial:s,api:(name,params,base)=>name==='list_c010_my_archived_horses'?[archivedHorse,{...archivedHorse,horse_id:'bad-id',display_name:'Invalid record'}]:base(name,params)});
 h.action('authority-transfer');await tick();assert.match(h.html,/Own archived horse · Gearchiveerd paard/);assert.doesNotMatch(h.html,/Cached archive name|Unverified cached archive|Invalid record|nog niet aangesloten/);assert.equal(h.html.split(`data-id="${ARCHIVED_HORSE}"`).length-1,1);assert.equal(h.writes.length,0);
 const call=h.calls.find(c=>c.name==='list_c010_my_archived_horses');assert.deepEqual(call.params,{});assert.deepEqual(call.options,{write:false});
});
test('archived horse offer rechecks the narrow current-primary list and uses the unchanged horse contract',async t=>{
 let reads=0;const h=fixture(t,{api:(name,params,base)=>name==='list_c010_my_archived_horses'?(reads++,[{...archivedHorse,display_name:reads===1?'Earlier name':'Current archive name'}]):base(name,params)});
 h.action('authority-transfer');await tick();await openStart(h,'horse',ARCHIVED_HORSE);assert.equal(reads,2);assert.equal(h.form?.id,'core-authority-start-form');assert.match(h.html,/Current archive name.*blijft gearchiveerd/s);assert.doesNotMatch(h.html,/gesloten stal|geen operationele toegang|Earlier name/);
 h.submit({email:'recipient@example.invalid',confirm:'yes'});await tick();assert.deepEqual(h.writes[0],{name:'initiate_horse_authority_transfer_by_email',params:{p_horse_id:ARCHIVED_HORSE,p_recipient_email:'recipient@example.invalid',p_correlation_id:h.operations[0].id},options:{write:true}});
 assert.equal(h.calls.some(c=>['get_canonical_horse_workspace','list_c010_horses'].includes(c.name)),false);h.afterSave();assert.match(h.html,/ontvanger moet nog accepteren/);
});
test('archived horse primary loss after selection prevents both offer and revoke forms',async t=>{
 let reads=0;const h=fixture(t,{api:(name,params,base)=>name==='list_c010_my_archived_horses'?(++reads===1?[{...archivedHorse,pending_transfer:pending}]:[]):base(name,params)});
 h.action('authority-transfer');await tick();await openStart(h,'horse',ARCHIVED_HORSE);assert.equal(h.form,null);assert.equal(h.writes.length,0);assert.ok(h.messages.length);
});
test('archived horse pending revoke uses freshly read transfer ID and CAS, without showing a code',async t=>{
 let reads=0;const h=fixture(t,{api:(name,params,base)=>name==='list_c010_my_archived_horses'?[{...archivedHorse,pending_transfer:++reads===1?pending:{...pending,id:B,row_version:7}}]:base(name,params)});
 h.action('authority-transfer');await tick();await openStart(h,'horse',ARCHIVED_HORSE);assert.equal(h.form?.id,'core-authority-revoke-form');assert.match(h.html,/blijft gearchiveerd/);assert.equal(h.html.includes(TOKEN),false);
 h.submit();await tick();assert.deepEqual(h.writes[0],{name:'revoke_horse_authority_transfer',params:{p_transfer_id:B,p_expected_row_version:7,p_correlation_id:h.operations[0].id},options:{write:true}});h.afterSave();assert.match(h.html,/ingetrokken/);
});
test('revoked archive request can be offered again only after a new authoritative read',async t=>{
 let revoked=false;const h=fixture(t,{api:(name,params,base)=>{if(name==='list_c010_my_archived_horses')return [{...archivedHorse,pending_transfer:revoked?null:pending}];if(name==='revoke_horse_authority_transfer')revoked=true;return base(name,params);}});
 h.action('authority-transfer');await tick();await openStart(h,'horse',ARCHIVED_HORSE);assert.equal(h.form?.id,'core-authority-revoke-form');h.submit();await tick();h.afterSave();assert.equal(h.writes.length,1);await openStart(h,'horse',ARCHIVED_HORSE);assert.equal(h.form?.id,'core-authority-start-form');assert.equal(h.writes.length,1);
});
test('forged direct archive selection never uses cached primary flags to bypass the archive listing',async t=>{
 const s=state();s.horses.push({id:ARCHIVED_HORSE,name:'Cached archive',lifecycleStatus:'archived',capabilities:{primary:true}});const h=fixture(t,{initial:s});await openStart(h,'horse',ARCHIVED_HORSE);assert.equal(h.calls.length,0);assert.equal(h.form,null);
});
test('late archive overview cannot leak a name after A to B to A',async t=>{
 const gate=defer(),h=fixture(t,{api:(name,params,base)=>name==='list_c010_my_archived_horses'?gate.promise:base(name,params)});h.action('authority-transfer');h.setState(state(B));h.controller.syncContext();h.setState(state(A));h.controller.syncContext();h.unrelated();gate.resolve([archivedHorse]);await tick();assert.equal(h.form?.id,'other-form');assert.doesNotMatch(h.html,/Own archived horse/);await openStart(h,'horse',ARCHIVED_HORSE);assert.equal(h.form?.id,'other-form');assert.equal(h.writes.length,0);
});
test('late archived selection cannot replace a newly opened unrelated modal',async t=>{
 const gate=defer();let reads=0;const h=fixture(t,{api:(name,params,base)=>name==='list_c010_my_archived_horses'?(++reads===1?[archivedHorse]:gate.promise):base(name,params)});h.action('authority-transfer');await tick();h.action('authority-transfer-start',{kind:'horse',id:ARCHIVED_HORSE});h.unrelated();gate.resolve([archivedHorse]);await tick();assert.equal(h.form?.id,'other-form');assert.doesNotMatch(h.html,/Own archived horse/);assert.equal(h.writes.length,0);
});
test('invalid archive projection fails closed without falling back to cached archive data',async t=>{
 const h=fixture(t,{api:(name,params,base)=>name==='list_c010_my_archived_horses'?{horse_id:ARCHIVED_HORSE}:base(name,params)});h.action('authority-transfer');await tick();assert.equal(h.form,null);assert.doesNotMatch(h.html,/data-action="authority-transfer-start"/);assert.ok(h.messages.length);assert.equal(h.writes.length,0);
});
test('horse recipient copy describes archive preservation conditionally without inventing preview lifecycle',async t=>{
 const h=fixture(t);await openResponse(h,'horse');assert.match(h.html,/Is dit paard gearchiveerd, dan blijft het gearchiveerd/);assert.doesNotMatch(h.html,/gesloten stal|geen operationele toegang/);assert.equal(h.writes.length,0);
});
test('archived horse display and recipient names are escaped in the current pending view',async t=>{
 const h=fixture(t,{api:(name,params,base)=>name==='list_c010_my_archived_horses'?[{...archivedHorse,display_name:'<script>horse</script>',pending_transfer:{...pending,recipient_name:'<img onerror=bad>'}}]:base(name,params)});h.action('authority-transfer');await tick();await openStart(h,'horse',ARCHIVED_HORSE);assert.match(h.html,/&lt;script&gt;horse/);assert.match(h.html,/&lt;img/);assert.doesNotMatch(h.html,/<script>|<img/);
});
test('public RPC allowlist exposes the exact own archived-horse read once',async()=>{
 const routes=JSON.parse(await readFile(new URL('../../../apps/avaryn/config/rpc-routes.json',import.meta.url),'utf8'));assert.equal(routes.filter(r=>r==='list_c010_my_archived_horses').length,1);assert.equal(routes.includes('initiate_horse_authority_transfer'),false);assert.ok(routes.includes('initiate_horse_authority_transfer_by_email'));
});
