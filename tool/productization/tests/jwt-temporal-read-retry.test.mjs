import test from 'node:test';
import assert from 'node:assert/strict';
import {createBackendClient} from '../../../apps/avaryn/src/backend-client.js';

const ACTOR='10000000-0000-4000-8000-000000000001';
const token='synthetic-temporal-read-token';
const fail=(message='JWT issued at future',status=401,code='PGRST303')=>Response.json({message,code},{status});
const tick=()=>new Promise(resolve=>setImmediate(resolve));
function harness({reply,timeoutMs=5000,loginReply}={}){
 const calls=[];
 const storage={getItem:()=>null,setItem:()=>{},removeItem:()=>{}};
 const fetchImpl=async(url,options)=>{
  const name=url.split('/').at(-1);calls.push({url,name,...options});
  if(url.includes('grant_type=password'))return loginReply?.()||Response.json({access_token:token,refresh_token:'synthetic-refresh',user:{id:ACTOR},expires_at:Date.now()/1000+3600});
  if(url.includes('/auth/v1/logout'))return new Response(null,{status:204});
  if(name==='get_current_account_profile')return Response.json([{profile_id:ACTOR,profile_status:'active',display_name:'Synthetic',row_version:1}]);
  if(name==='get_c010_personal_day')return Response.json({on_date:'2026-09-12',calendar:{},items:[]});
  if(name==='list_c010_horses'||name==='list_c010_stables')return Response.json([]);
  return reply(calls.filter(c=>c.name===name).length,name);
 };
 const client=createBackendClient({storage,fetchImpl,timeoutMs});
 return {client,calls,async start(){await client.login('synthetic','synthetic');await client.load();},probeCalls(){return calls.filter(c=>c.name==='get_synthetic_probe');}};
}

for(const message of ['JWT issued at future','JWT not yet valid'])test('one same-bearer read retry for '+message,async()=>{
 const h=harness({reply:n=>n===1?fail(message):Response.json({accepted:true})});await h.start();
 assert.deepEqual(await h.client.requestRpc('get_synthetic_probe',{same:'parameters'}),{accepted:true});
 const calls=h.probeCalls();assert.equal(calls.length,2);assert.equal(calls[0].headers.Authorization,'Bearer '+token);
 assert.deepEqual(calls[0].headers,calls[1].headers);assert.equal(calls[0].body,calls[1].body);
 assert.equal(calls[0].signal,calls[1].signal);assert.equal(h.calls.filter(c=>c.url.includes('/auth/')).length,1);
});
test('repeated temporal refusal stops at two requests and retains access-loss handling',async()=>{
 const h=harness({reply:()=>fail()});await h.start();
 await assert.rejects(h.client.requestRpc('get_synthetic_probe'),e=>e.status===401&&e.accessLost);
 assert.equal(h.probeCalls().length,2);
});
test('retry preserves the original serialized body when caller parameters change during delay',async()=>{
 const h=harness({reply:n=>n===1?fail():Response.json({accepted:true})});await h.start();
 const params={filter:{day:'2026-09-12'}};
 const result=h.client.requestRpc('get_synthetic_probe',params);
 await tick();assert.equal(h.probeCalls().length,1);
 params.filter.day='2026-09-13';
 assert.deepEqual(await result,{accepted:true});
 const calls=h.probeCalls();assert.equal(calls.length,2);
 assert.equal(calls[0].body,JSON.stringify({filter:{day:'2026-09-12'}}));
 assert.equal(calls[1].body,calls[0].body);
});
for(const [message,status,code] of [['JWT expired',401,'PGRST303'],['JWT signature verification failed',401,'PGRST301'],['JWT issued at future',401,'OTHER_CODE'],['JWT issued at future ',401,'PGRST303'],['JWT issued at future',403,'PGRST303'],['Permission denied',401,'42501']])test('no retry for other denial: '+[message,status,code].join('/'),async()=>{
 const h=harness({reply:()=>fail(message,status,code)});await h.start();
 await assert.rejects(h.client.requestRpc('get_synthetic_probe'));assert.equal(h.probeCalls().length,1);
});
test('never replay a write even on a read-shaped RPC name',async()=>{
 const h=harness({reply:()=>fail()});await h.start();
 await assert.rejects(h.client.requestRpc('get_synthetic_probe',{}, {write:true}));assert.equal(h.probeCalls().length,1);
});
test('never replay mutation-shaped RPC with omitted write flag',async()=>{
 const h=harness({reply:()=>fail()});await h.start();
 await assert.rejects(h.client.requestRpc('upsert_synthetic_probe'));assert.equal(h.calls.filter(c=>c.name==='upsert_synthetic_probe').length,1);
});
test('never retry Auth or Edge requests',async()=>{
 const auth=harness({loginReply:()=>fail()});await assert.rejects(auth.client.login('synthetic','synthetic'));assert.equal(auth.calls.length,1);
 const edge=harness({reply:()=>fail()});await edge.start();await assert.rejects(edge.client.edgeRequest('media-assets',{}, {write:false}));assert.equal(edge.calls.filter(c=>c.name==='media-assets').length,1);
});
test('logout during delay prevents the second request',async()=>{
 const h=harness({reply:()=>fail()});await h.start();
 const result=assert.rejects(h.client.requestRpc('get_synthetic_probe'),e=>e.code==='STALE_CONTEXT');
 await tick();await h.client.logout();await result;assert.equal(h.probeCalls().length,1);
});
test('account switch during delay prevents the old request from repeating',async()=>{
 const h=harness({reply:()=>fail()});await h.start();
 const result=assert.rejects(h.client.requestRpc('get_synthetic_probe'),e=>e.code==='STALE_CONTEXT');
 await tick();await h.client.login('synthetic-second','synthetic');await result;assert.equal(h.probeCalls().length,1);
});
test('the original request deadline also bounds the retry delay',async()=>{
 const h=harness({reply:()=>fail(),timeoutMs:40});await h.start();
 await assert.rejects(h.client.requestRpc('get_synthetic_probe'),e=>e.code==='TIMEOUT');
 await new Promise(resolve=>setTimeout(resolve,1250));assert.equal(h.probeCalls().length,1);assert.equal(h.probeCalls()[0].signal.aborted,true);
});
test('no session sends no request',async()=>{
 const h=harness({reply:()=>fail()});await assert.rejects(h.client.load());assert.equal(h.calls.length,0);
});
