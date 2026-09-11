import test from 'node:test';
import assert from 'node:assert/strict';
import {createAccountLifecycle} from '../../../apps/avaryn/src/account-lifecycle.js';
import {handleAccountDeletion} from '../../../supabase/functions/delete-account/handler.ts';
const A='10000000-0000-4000-8000-000000000001',B='10000000-0000-4000-8000-000000000002';
const live=(id=A)=>({backend:{connected:true,actor:{id,name:'Own synthetic actor'}}});
const defer=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
const tick=()=>new Promise(resolve=>setImmediate(resolve));
function fixture(t,{state=live(),edge,clear,onPending}={}){
 let current=state,form=null,html='',seq=0,closed=0;const calls=[],cleared=[],pending=[],routes=[];
 const original={document:globalThis.document,FormData:globalThis.FormData};
 const modal={open:false,dataset:{viewId:''},querySelector:selector=>selector==='#account-delete-form'&&form?.id==='account-delete-form'?form:null};
 globalThis.document={getElementById:id=>id==='modal'?modal:form?.id===id?form:null};
 globalThis.FormData=class{constructor(value){this.values=value.values;}get(name){return this.values[name]??null;}};
 t.after(()=>{globalThis.document=original.document;globalThis.FormData=original.FormData;});
 function disconnect(){if(form){form.isConnected=false;for(const c of form.controls)c.isConnected=false;}}
 function showModal(title,body,footer=''){
  disconnect();html=body+footer;modal.open=true;modal.dataset.viewId=String(++seq);
  const id=body.match(/<form id="([^"]+)"/);form=null;
  if(id){
   const busy=body.includes('type="submit" class="button-primary" disabled');
   form={id:id[1],isConnected:true,values:{confirmation:body.match(/name="confirmation" value="([^"]*)"/)?.[1]||''},message:{hidden:!body.includes('data-deletion-message>'),textContent:''},links:{innerHTML:''},getAttribute(name){return this[name];}};
   form.controls=[{tagName:'INPUT',disabled:busy,isConnected:true},{tagName:'BUTTON',disabled:busy,isConnected:true}];
   form.querySelectorAll=()=>form.controls;
   form.querySelector=selector=>selector==='[data-deletion-message]'?form.message:selector==='[data-deletion-actions]'?form.links:null;
  }
 }
 const controller=createAccountLifecycle({getState:()=>current,getBackend:()=>({edgeRequest:async(name,body)=>{calls.push({name,body:structuredClone(body)});return edge?edge(name,body):{code:'ACCOUNT_DELETED',request_id:body.request_id};}}),showModal,closeModal(){closed++;modal.open=false;disconnect();},navigate:route=>routes.push(route),
  clearSession:async options=>{cleared.push({isCurrent:options.isCurrent(),message:options.message});if(clear)return clear(options);current={backend:{connected:false}};controller.syncContext();},
  onPending:async options=>{pending.push({requestId:options.requestId,isCurrent:options.isCurrent()});if(onPending)return onPending(options);}
 });
 return {controller,calls,cleared,pending,routes,modal,get form(){return form;},get html(){return html;},get closed(){return closed;},setState:value=>{current=value;},
  open(){controller.handleAction('account-delete');return form;},
  submit(value='VERWIJDEREN',target=form){target.values.confirmation=value;let prevented=false;const handled=controller.handleSubmit(target,{preventDefault(){prevented=true;}});return {handled,prevented};},
  dismiss(){modal.open=false;disconnect();},unrelated(){showModal('Other','<form id="unrelated-form"></form>');}
 };
}

test('own account requires explicit typed consent; close/open never sends a request',async t=>{
 const h=fixture(t);h.open();assert.match(h.html,/niet ongedaan/);h.submit('');await tick();assert.equal(h.calls.length,0);assert.match(h.form.message.textContent,/Typ VERWIJDEREN/);
 h.submit('verwijderen');await tick();assert.equal(h.calls.length,0);h.dismiss();h.open();assert.equal(h.calls.length,0);
});
test('confirmed request has only delete action and a fresh UUID, never actor/avatar/resume data',async t=>{
 const h=fixture(t);h.open();const submitted=h.submit();await tick();assert.deepEqual(submitted,{handled:true,prevented:true});
 assert.equal(h.calls.length,1);assert.equal(h.calls[0].name,'delete-account');assert.deepEqual(Object.keys(h.calls[0].body).sort(),['action','request_id']);assert.equal(h.calls[0].body.action,'delete');assert.match(h.calls[0].body.request_id,/^[0-9a-f-]{36}$/);assert.equal(h.cleared.length,1);assert.equal(h.cleared[0].isCurrent,true);
});
for(const state of [{backend:{connected:false}},live(''),{backend:{connected:false,actor:{id:A}}}])test('demo, missing actor and disconnected presentation cannot request deletion '+JSON.stringify(state),t=>{
 const h=fixture(t,{state});h.open();assert.equal(h.form,null);assert.match(h.html,/Meld je aan/);assert.equal(h.calls.length,0);
});
test('unrelated forms are not intercepted; forged detached deletion form is refused',t=>{
 const h=fixture(t);h.open();let prevented=false;assert.equal(h.controller.handleSubmit({getAttribute:()=> 'other-form'},{preventDefault(){prevented=true;}}),false);assert.equal(prevented,false);
 assert.equal(h.controller.handleSubmit({getAttribute:()=> 'account-delete-form'},{preventDefault(){prevented=true;}}),true);assert.equal(h.calls.length,0);
});
test('duplicate submit sends exactly one request and preserves disabled controls until completion',async t=>{
 const gate=defer(),h=fixture(t,{edge:()=>gate.promise});const form=h.open();h.submit();h.submit();assert.equal(h.calls.length,1);assert.ok(form.controls.every(c=>c.disabled));
 gate.resolve({code:'ACCOUNT_DELETION_PENDING',request_id:h.calls[0].body.request_id});await tick();assert.ok(form.controls.every(c=>!c.disabled));assert.equal(h.cleared.length,0);
});
test('primary organization blocker keeps consent and offers real team/switch-stable/stable actions',async t=>{
 const h=fixture(t,{edge:()=>{throw Object.assign(Error('Do not print'),{code:'PRIMARY_ORGANIZATION_ADMIN_REQUIRED',status:409});}});const form=h.open();h.submit();await tick();
 assert.equal(form.values.confirmation,'VERWIJDEREN');assert.match(form.message.textContent,/accepteren/);assert.match(form.message.textContent,/archiveren/);assert.match(form.links.innerHTML,/data-action="team"/);assert.match(form.links.innerHTML,/data-action="switch-stable"/);assert.equal(h.controller.handleAction('team'),false);
 h.controller.handleAction('account-delete-stables');assert.deepEqual(h.routes,['stable']);assert.equal(h.cleared.length,0);
});
test('primary horse blocker links to existing horse route without changing ownership',async t=>{
 const h=fixture(t,{edge:()=>({code:'PRIMARY_HORSE_AUTHORITY_REQUIRED'})});h.open();h.submit();await tick();assert.match(h.form.message.textContent,/paard.*over/i);h.controller.handleAction('account-delete-horses');assert.deepEqual(h.routes,['horses']);assert.equal(h.cleared.length,0);
});
test('production Edge blocked prepare performs no avatar/Auth cleanup when used by module',async t=>{
 const portCalls=[];const h=fixture(t,{edge:async(_,body)=>{
  const response=await handleAccountDeletion(new Request('http://localhost/delete-account',{method:'POST',headers:{Authorization:'Bearer synthetic-only'},body:JSON.stringify(body)}),{
   authenticate:async()=>{portCalls.push('authenticate');return {id:B};},trustedResume:()=>false,prepare:async()=>{portCalls.push('prepare');return {status:'blocked',code:'PRIMARY_ORGANIZATION_ADMIN_REQUIRED'};},
   job:async()=>{portCalls.push('job');return null;},removeAvatars:async()=>{portCalls.push('avatar');},deleteAuth:async()=>{portCalls.push('auth-delete');},finalize:async()=>{portCalls.push('finalize');}
  });assert.equal(response.status,409);return response.json();
 }});h.open();h.submit();await tick();assert.deepEqual(portCalls,['authenticate','prepare']);assert.equal(h.cleared.length,0);assert.match(h.form.message.textContent,/hoofdverantwoordelijkheid/);
});
for(const [code,text] of [['LEGACY_RETENTION_REQUIRED',/migreren/],['APPLE_REVOCATION_NOT_CONFIGURED',/Apple.*niet volledig/],['STORAGE_OWNERSHIP_UNSUPPORTED',/bestanden/]])test(code+' is an honest unresolved limitation, never reported as deletion',async t=>{
 const h=fixture(t,{edge:()=>{throw Object.assign(Error('Raw private payload'),{code,status:409});}});h.open();h.submit();await tick();assert.match(h.form.message.textContent,text);assert.doesNotMatch(h.form.message.textContent,/Raw private/);assert.equal(h.cleared.length,0);assert.equal(h.pending.length,0);
});
test('unknown error never leaks raw server text and exact request ID survives reopen/retry',async t=>{
 let tries=0;const h=fixture(t,{edge:(_,body)=>{if(tries++===0)throw Error('<private secret>');return {code:'ACCOUNT_DELETED',request_id:body.request_id};}});h.open();h.submit();await tick();assert.match(h.form.message.textContent,/nog niet bevestigd/);assert.doesNotMatch(h.form.message.textContent,/secret/);const first=h.calls[0].body.request_id;
 h.dismiss();h.open();assert.equal(h.form.values.confirmation,'VERWIJDEREN');assert.match(h.html,/Dezelfde aanvraag/);h.submit();await tick();assert.equal(h.calls[1].body.request_id,first);assert.equal(h.cleared.length,1);
});
test('pending uses canonical returned request ID, purges through guarded hook, never logs out or claims success',async t=>{
 let tries=0;const h=fixture(t,{edge:()=>{tries++;return {code:'ACCOUNT_DELETION_PENDING',request_id:B};}});h.open();h.submit();await tick();assert.equal(h.cleared.length,0);assert.deepEqual(h.pending,[{requestId:B,isCurrent:true}]);assert.match(h.form.message.textContent,/nog niet bevestigd/);h.submit();await tick();assert.equal(tries,2);assert.deepEqual(h.calls[1].body,{action:'delete',request_id:B});
});
test('expired session after pending is not a false completion and preserves same request',async t=>{
 let tries=0;const h=fixture(t,{edge:(_,body)=>{if(tries++===0)return {code:'ACCOUNT_DELETION_PENDING',request_id:body.request_id};throw Object.assign(Error('Token details'),{code:'INVALID_SESSION',status:401});}});h.open();h.submit();await tick();h.submit();await tick();assert.equal(h.cleared.length,0);assert.match(h.form.message.textContent,/niet meer beschikbaar/);assert.equal(h.calls[0].body.request_id,h.calls[1].body.request_id);
});
for(const result of [{code:'ACCOUNT_DELETED'},{code:'ACCOUNT_DELETED',request_id:'unsafe'},null])test('unverified terminal response cannot clear session '+JSON.stringify(result),async t=>{
 const h=fixture(t,{edge:()=>result});h.open();h.submit();await tick();assert.equal(h.cleared.length,0);assert.match(h.form.message.textContent,/nog niet bevestigd/);
});
test('closing during request does not reopen a pending deletion sheet',async t=>{
 const gate=defer(),h=fixture(t,{edge:()=>gate.promise});h.open();h.submit();h.dismiss();gate.resolve({code:'ACCOUNT_DELETION_PENDING',request_id:B});await tick();assert.equal(h.modal.open,false);assert.equal(h.cleared.length,0);assert.equal(h.pending.length,1);
});
test('unrelated replacement modal is not overwritten by deletion failure',async t=>{
 const gate=defer(),h=fixture(t,{edge:()=>gate.promise});h.open();h.submit();h.unrelated();const view=h.modal.dataset.viewId;gate.reject(Object.assign(Error('private'),{code:'LEGACY_RETENTION_REQUIRED'}));await tick();assert.equal(h.form.id,'unrelated-form');assert.equal(h.modal.dataset.viewId,view);assert.equal(h.closed,0);
});
test('confirmed deletion clears its same actor even if sheet was dismissed; no new sheet is opened',async t=>{
 const gate=defer(),h=fixture(t,{edge:()=>gate.promise});h.open();h.submit();h.dismiss();gate.resolve({code:'ACCOUNT_DELETED',request_id:B});await tick();assert.equal(h.cleared.length,1);assert.equal(h.modal.open,false);
});
test('actor switch invalidates submit and late completion cannot clear the next actor',async t=>{
 const gate=defer(),h=fixture(t,{edge:()=>gate.promise});const old=h.open();h.submit();h.setState(live(B));h.controller.syncContext();assert.equal(h.modal.open,false);h.submit('VERWIJDEREN',old);assert.equal(h.calls.length,1);
 gate.resolve({code:'ACCOUNT_DELETED',request_id:A});await tick();assert.equal(h.cleared.length,0);assert.equal(h.pending.length,0);
});
test('A→B→A generation rejects old response and resets request identity for a fresh consent',async t=>{
 const gate=defer();let tries=0;const h=fixture(t,{edge:(_,body)=>tries++===0?gate.promise:{code:'ACCOUNT_DELETION_PENDING',request_id:body.request_id}});h.open();h.submit();const oldId=h.calls[0].body.request_id;
 h.setState(live(B));h.controller.syncContext();h.setState(live(A));h.controller.syncContext();h.open();assert.equal(h.form.values.confirmation,'');h.submit();await tick();const view=h.modal.dataset.viewId;gate.resolve({code:'ACCOUNT_DELETED',request_id:oldId});await tick();assert.notEqual(h.calls[1].body.request_id,oldId);assert.equal(h.cleared.length,0);assert.equal(h.modal.dataset.viewId,view);
});
test('reopen own sheet while request pending stays busy, then restores current controls',async t=>{
 const gate=defer(),h=fixture(t,{edge:()=>gate.promise});h.open();h.submit();h.dismiss();h.open();assert.ok(h.form.controls.every(c=>c.disabled));h.submit();assert.equal(h.calls.length,1);gate.resolve({code:'ACCOUNT_DELETION_PENDING',request_id:B});await tick();assert.ok(h.form.controls.every(c=>!c.disabled));assert.match(h.form.message.textContent,/in behandeling/);
});
test('local clear failure retries clearing only; it never submits deletion a second time',async t=>{
 let tries=0;const h=fixture(t,{clear:()=>{if(tries++===0)throw Error('Private native storage');}});h.open();h.submit();await tick();assert.match(h.form.message.textContent,/lokaal afmelden/);h.submit();await tick();assert.equal(h.calls.length,1);assert.equal(h.cleared.length,2);
});
test('failure of pending presentation hook preserves authoritative status and truthful retry label',async t=>{
 const h=fixture(t,{edge:()=>({code:'ACCOUNT_DELETION_PENDING',request_id:B}),onPending:()=>{throw Error('Presentation failure');}});h.open();h.submit();await tick();assert.match(h.form.message.textContent,/in behandeling/);assert.equal(h.form.controls[1].textContent,'Dezelfde aanvraag opnieuw proberen');assert.equal(h.cleared.length,0);h.submit();await tick();assert.equal(h.calls[1].body.request_id,B);
});
test('failure clearing local session offers local sign-out retry without another deletion call',async t=>{
 const h=fixture(t,{clear:()=>{throw Error('Synthetic secure storage failure');}});h.open();h.submit();await tick();assert.equal(h.form.controls[1].textContent,'Opnieuw afmelden');assert.equal(h.form.controls[1].disabled,false);h.submit();await tick();assert.equal(h.calls.length,1);
});
test('accepted pending state remains gated after retry loses its session or status response',async t=>{
 let tries=0;const h=fixture(t,{edge:(_,body)=>{if(tries++===0)return {code:'ACCOUNT_DELETION_PENDING',request_id:body.request_id};throw Object.assign(Error('Synthetic session gone'),{code:'INVALID_SESSION',status:401});}});h.open();h.submit();await tick();assert.equal(h.controller.isPending(),true);h.submit();await tick();assert.equal(h.controller.isPending(),true);assert.equal(h.cleared.length,0);h.setState({backend:{connected:false}});h.controller.syncContext();assert.equal(h.controller.isPending(),false);
});
test('confirmed deletion blocks operations while durable local session removal is still pending',async t=>{
 const gate=defer(),h=fixture(t,{clear:()=>gate.promise});h.open();h.submit();await tick();assert.equal(h.controller.isPending(),true);assert.equal(h.form.controls[1].disabled,true);gate.resolve();await tick();assert.equal(h.controller.isPending(),true);h.setState({backend:{connected:false}});h.controller.syncContext();assert.equal(h.controller.isPending(),false);
});
test('durable session removal failure cannot reopen operational access or repeat the Edge mutation',async t=>{
 const h=fixture(t,{clear:()=>{throw Error('Secure removal unavailable');}});h.open();h.submit();await tick();assert.equal(h.controller.isPending(),true);h.submit();await tick();assert.equal(h.controller.isPending(),true);assert.equal(h.calls.length,1);assert.equal(h.cleared.length,2);
});
