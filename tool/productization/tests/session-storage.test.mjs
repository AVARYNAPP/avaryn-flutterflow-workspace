import test from 'node:test';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {createBackendClient} from '../../../apps/avaryn/src/backend-client.js';

const KEY='avaryn-v8-real-auth-v1', A='10000000-0000-4000-8000-000000000001', B='10000000-0000-4000-8000-000000000002';
const tick=()=>new Promise(resolve=>setImmediate(resolve));
const deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
const session=(actor=A,expires=Date.now()/1000+3600,revision='')=>({access_token:`synthetic-access-${actor}${revision}`,refresh_token:`synthetic-refresh-${actor}`,user:{id:actor},expires_at:expires});
const saved=value=>JSON.stringify({access_token:value.access_token,refresh_token:value.refresh_token,user_id:value.user.id,expires_at:value.expires_at});
const result=value=>Response.json(value);
function memory(initial=null){
 const values=new Map(initial===null?[]:[[KEY,initial]]),calls=[];
 const hooks={};
 return {values,calls,hooks,
  async getItem(key){calls.push(['get',key]);if(hooks.get)return hooks.get(key);return values.get(key)??null;},
  async setItem(key,value){calls.push(['set',key,value]);if(hooks.set)await hooks.set(key,value);values.set(key,value);},
  async removeItem(key){calls.push(['remove',key]);if(hooks.remove)await hooks.remove(key);values.delete(key);}
 };
}
function harness({storage=memory(),expires,override}={}){
 const calls=[];
 const fetchImpl=async(url,options)=>{
  const body=options.body?JSON.parse(options.body):null,token=options.headers.Authorization||'';
  const actor=token.includes(B)?B:A;const call={url,body,token};calls.push(call);
  if(override){const value=await override(call);if(value!==undefined)return value;}
  if(url.includes('grant_type=password'))return result(session(body.email==='B'?B:A,expires));
  if(url.includes('grant_type=refresh_token'))return result(session(body.refresh_token.includes(B)?B:A,undefined,'-rotated'));
  if(url.endsWith('/auth/v1/user'))return result({id:actor});
  if(url.endsWith('/auth/v1/logout?scope=local'))return new Response(null,{status:204});
  const name=url.split('/').at(-1);
  if(name==='get_current_account_profile')return result([{profile_status:'active',profile_id:actor,display_name:actor===A?'Actor A':'Actor B',row_version:1}]);
  if(name==='get_c010_personal_day')return result({on_date:'2026-09-11',calendar:{today_date:'2026-09-11'},items:[]});
  if(name==='list_c010_horses'||name==='list_c010_stables')return result([]);
  if(name==='read_synthetic_private')return result({actor});
  throw Error('Unexpected fixture route: '+name);
 };
 return {storage,calls,client:createBackendClient({storage,fetchImpl,timeoutMs:1000})};
}

test('login waits for async deletion and durable session write; only session fields are retained',async()=>{
 const store=memory(),remove=deferred(),write=deferred();store.hooks.remove=()=>remove.promise;store.hooks.set=()=>write.promise;
 const h=harness({storage:store});let settled=false;const login=h.client.login('A','synthetic').then(()=>{settled=true;});
 await tick();assert.equal(h.calls.length,0);remove.resolve();await tick();assert.equal(settled,false);assert.equal(store.values.size,0);
 write.resolve();await login;assert.equal(settled,true);assert.deepEqual(Object.keys(JSON.parse(store.values.get(KEY))).sort(),['access_token','expires_at','refresh_token','user_id']);
});
test('logout queues removal after a pending login write and never resurrects that session',async()=>{
 const store=memory(),write=deferred();store.hooks.set=()=>write.promise;const h=harness({storage:store});
 const login=assert.rejects(h.client.login('A','synthetic'),e=>e.code==='STALE_CONTEXT');await tick();
 const logout=h.client.logout();write.resolve();await Promise.all([login,logout]);assert.equal(store.values.size,0);
 await assert.rejects(h.client.load(),e=>e.code==='AUTH_REQUIRED');
});
test('late password response for A cannot overwrite successful B login',async()=>{
 const gate=deferred();const h=harness({override:c=>c.body?.email==='A'?gate.promise:undefined});
 const old=assert.rejects(h.client.login('A','synthetic'),e=>e.code==='STALE_CONTEXT');await tick();await h.client.login('B','synthetic');
 gate.resolve(result(session(A)));await old;assert.equal(JSON.parse(h.storage.values.get(KEY)).user_id,B);
});
test('late async storage read from A cannot replace B',async()=>{
 const gate=deferred(),store=memory(saved(session(A)));store.hooks.get=()=>gate.promise;const h=harness({storage:store});
 const old=assert.rejects(h.client.restore(),e=>e.code==='STALE_CONTEXT');await tick();await h.client.login('B','synthetic');
 gate.resolve(saved(session(A)));await old;assert.equal(JSON.parse(store.values.get(KEY)).user_id,B);
});
test('old restore Auth failure cannot clear a newly persisted B session',async()=>{
 const gate=deferred(),h=harness({storage:memory(saved(session(A))),override:c=>c.url.endsWith('/auth/v1/user')?gate.promise:undefined});
 const restore=assert.rejects(h.client.restore());await tick();await h.client.login('B','synthetic');
 gate.resolve(Response.json({message:'expired'},{status:401}));await restore;assert.equal(JSON.parse(h.storage.values.get(KEY)).user_id,B);
});
test('async restoration verifies Auth identity before reporting success',async()=>{
 const h=harness({storage:memory(saved(session(A)))});assert.equal(await h.client.restore(),true);
 assert.equal(h.calls.filter(c=>c.url.endsWith('/auth/v1/user')).length,1);assert.equal(JSON.parse(h.storage.values.get(KEY)).user_id,A);
});
test('mismatching restored Auth identity removes credentials and blocks domain requests',async()=>{
 const h=harness({storage:memory(saved(session(A))),override:c=>c.url.endsWith('/auth/v1/user')?result({id:B}):undefined});
 await assert.rejects(h.client.restore());assert.equal(h.storage.values.size,0);await assert.rejects(h.client.load(),e=>e.code==='AUTH_REQUIRED');
});
test('async storage read failure performs no network request',async()=>{
 const store=memory();store.hooks.get=async()=>{throw Error('synthetic keychain locked');};const h=harness({storage:store});
 await assert.rejects(h.client.restore());assert.equal(h.calls.length,0);await assert.rejects(h.client.load(),e=>e.code==='AUTH_REQUIRED');
});
test('invalid serialized storage is removed without an Auth request',async()=>{
 const h=harness({storage:memory('not-json')});await assert.rejects(h.client.restore());assert.equal(h.calls.length,0);assert.equal(h.storage.values.size,0);
});
test('failed initial secure removal prevents password exchange',async()=>{
 const store=memory(saved(session(A)));store.hooks.remove=async()=>{throw Error('synthetic remove failure');};const h=harness({storage:store});
 await assert.rejects(h.client.login('B','synthetic'),e=>e.code==='SESSION_STORAGE_UNAVAILABLE');assert.equal(h.calls.length,0);
});
test('failed async login write cannot report authenticated or make domain requests',async()=>{
 const store=memory();store.hooks.set=async()=>{throw Error('synthetic full storage');};const h=harness({storage:store});
 await assert.rejects(h.client.login('A','synthetic'),e=>e.code==='SESSION_STORAGE_UNAVAILABLE');
 await assert.rejects(h.client.load(),e=>e.code==='AUTH_REQUIRED');assert.equal(h.calls.length,1);
});
test('a failed A persistence operation does not poison the serialized B login queue',async()=>{
 const store=memory(),gate=deferred();store.hooks.set=async(_key,value)=>{if(JSON.parse(value).user_id===A)await gate.promise;};const h=harness({storage:store});
 const old=assert.rejects(h.client.login('A','synthetic'));await tick();const fresh=h.client.login('B','synthetic');
 gate.reject(Error('synthetic write failure'));await Promise.all([old,fresh]);assert.equal(JSON.parse(store.values.get(KEY)).user_id,B);
});
test('parallel domain reads share one refresh and await its durable write',async()=>{
 const store=memory(),gate=deferred();const h=harness({storage:store,expires:1});await h.client.login('A','synthetic');
 store.hooks.set=()=>gate.promise;let settled=false;const loading=h.client.load().then(v=>{settled=true;return v;});await tick();
 assert.equal(h.calls.filter(c=>c.url.includes('grant_type=refresh_token')).length,1);assert.equal(h.calls.filter(c=>c.url.includes('/rpc/')).length,0);assert.equal(settled,false);
 gate.resolve();await loading;assert(JSON.parse(store.values.get(KEY)).access_token.endsWith('-rotated'));
});
test('late refresh after logout cannot persist credentials or return a domain view',async()=>{
 const gate=deferred(),h=harness({expires:1,override:c=>c.url.includes('grant_type=refresh_token')?gate.promise:undefined});await h.client.login('A','synthetic');
 const pending=assert.rejects(h.client.load(),e=>e.code==='STALE_CONTEXT');await tick();await h.client.logout();gate.resolve(result(session(A)));await pending;assert.equal(h.storage.values.size,0);
});
test('late refresh for A cannot replace B or send subsequent A domain requests',async()=>{
 const gate=deferred(),h=harness({expires:1,override:c=>c.url.includes('grant_type=refresh_token')?gate.promise:undefined});await h.client.login('A','synthetic');
 const pending=assert.rejects(h.client.load(),e=>e.code==='STALE_CONTEXT');await tick();await h.client.login('B','synthetic');gate.resolve(result(session(A)));await pending;
 assert.equal(JSON.parse(h.storage.values.get(KEY)).user_id,B);assert.equal(h.calls.filter(c=>c.url.includes('/rpc/')).length,0);
});
test('logout clears local credentials even when server logout is unavailable',async()=>{
 const h=harness({override:c=>c.url.endsWith('/auth/v1/logout?scope=local')?Promise.reject(Error('synthetic offline')):undefined});await h.client.login('A','synthetic');
 await assert.rejects(h.client.logout());assert.equal(h.storage.values.size,0);await assert.rejects(h.client.load(),e=>e.code==='AUTH_REQUIRED');
});
test('failed refresh persistence invalidates already pending private actor responses',async()=>{
 const now=Date.now,gate=deferred();let clock=now();Date.now=()=>clock;
 try{
  const store=memory(),h=harness({storage:store,expires:clock/1000+120,override:c=>c.url.endsWith('read_synthetic_private')?gate.promise:undefined});
  await h.client.login('A','synthetic');await h.client.load();
  const old=h.client.requestRpc('read_synthetic_private');const rejected=assert.rejects(old,e=>e.code==='STALE_CONTEXT');await tick();
  clock+=90000;store.hooks.set=async()=>{throw Error('synthetic secure write failure');};
  await assert.rejects(h.client.requestRpc('read_synthetic_private'),e=>e.code==='SESSION_STORAGE_UNAVAILABLE');
  gate.resolve(result({actor:A,privateValue:'synthetic-private'}));await rejected;
 }finally{Date.now=now;gate.resolve(result({}));}
});

let platformImport=0;
async function withPlatform({native=true,apiBase='https://api.example.invalid/api',failSetup=false}={},run){
 const names=['document','window','history','location','sessionStorage','__avarynPlatformTest'];const savedGlobals=Object.fromEntries(names.map(n=>[n,Object.getOwnPropertyDescriptor(globalThis,n)]));
 const calls=[],store=memory(),listeners={};
 const secure={setKeyPrefix:async v=>calls.push(['prefix',v]),setSynchronize:async v=>calls.push(['sync',v]),setDefaultKeychainAccess:async v=>{calls.push(['access',v]);if(failSetup)throw Error('synthetic native unavailable');},getItem:k=>store.getItem(k),setItem:(k,v)=>store.setItem(k,v),removeItem:k=>store.removeItem(k)};
 const mocks={'@capacitor/core':{Capacitor:{isNativePlatform:()=>native,getPlatform:()=> 'ios'}},'@aparajita/capacitor-secure-storage':{SecureStorage:secure,KeychainAccess:{whenUnlockedThisDeviceOnly:1}},'@capacitor/app':{App:{addListener:async(name,fn)=>{listeners[name]=fn;return {remove:async()=>{}};},getLaunchUrl:async()=>undefined,minimizeApp:async()=>{}}},'@capacitor/browser':{Browser:{open:async()=>{throw Error('Unexpected browser call');}}},'./product-config.js':{PRODUCT:{apiBase}}};
 Object.assign(globalThis,{__avarynPlatformTest:mocks,document:{documentElement:{dataset:{}},addEventListener:()=>{},querySelector:()=>null},window:{dispatchEvent:()=>{}},history:{back:()=>{}},location:{href:'capacitor://localhost/',origin:'capacitor://localhost'},sessionStorage:memory()});
 const hooks=registerHooks({resolve(specifier,context,next){if(Object.hasOwn(mocks,specifier))return {url:'avaryn-session-test:'+encodeURIComponent(specifier)+'?'+platformImport,shortCircuit:true};return next(specifier,context);},load(url,context,next){if(url.startsWith('avaryn-session-test:')){const name=decodeURIComponent(url.split(':')[1].split('?')[0]);return {format:'module',source:Object.keys(mocks[name]).map(key=>`export const ${key}=globalThis.__avarynPlatformTest[${JSON.stringify(name)}][${JSON.stringify(key)}];`).join('\n'),shortCircuit:true};}return next(url,context);}});
 try{
  const mod=await import('../../../apps/avaryn/src/platform.js?session-test='+ ++platformImport);await run({initialize:mod.initializePlatform,calls,store,listeners});
 }finally{hooks.deregister();for(const name of names){if(savedGlobals[name])Object.defineProperty(globalThis,name,savedGlobals[name]);else delete globalThis[name];}}
}
test('native platform sets device-only unlocked keychain and disables synchronization before exposing async storage',()=>withPlatform({},async({initialize,calls,store})=>{
 const platform=await initialize();assert.deepEqual(calls,[['prefix','avaryn.session.'],['sync',false],['access',1]]);
 await platform.storage.setItem(KEY,'synthetic');assert.equal(await platform.storage.getItem(KEY),'synthetic');await platform.storage.removeItem(KEY);assert.equal(store.values.size,0);
}));
test('web platform uses browser sessionStorage without loading native secure-storage fallback',()=>withPlatform({native:false,apiBase:'/api'},async({initialize,calls})=>{
 const platform=await initialize();assert.equal(platform.storage,globalThis.sessionStorage);assert.deepEqual(calls,[]);
}));
test('native secure-store initialization failure does not fall back to plain browser storage',()=>withPlatform({failSetup:true},async({initialize})=>{await assert.rejects(initialize(),/synthetic native unavailable/);}));
test('native build blocks an unsecured API before secure store is initialized',()=>withPlatform({apiBase:'http://api.example.invalid/api'},async({initialize,calls})=>{const result=await initialize();assert.equal(result.blocked.code,'NATIVE_API_CONFIGURATION_REQUIRED');assert.equal(result.storage,null);assert.equal(result.apiBase,null);assert.deepEqual(calls,[]);}));

test('logout secure-remove failure is surfaced but still attempts server revocation',async()=>{
 const store=memory(),h=harness({storage:store});await h.client.login('A','synthetic');
 store.hooks.remove=async()=>{throw Error('synthetic locked store');};
 await assert.rejects(h.client.logout(),e=>e.code==='SESSION_STORAGE_UNAVAILABLE');
 assert.equal(h.calls.filter(c=>c.url.endsWith('/auth/v1/logout?scope=local')).length,1);
 await assert.rejects(h.client.load(),e=>e.code==='AUTH_REQUIRED');
});

test('late failed refresh persistence for A cannot invalidate the already started B login',async()=>{
 const gate=deferred(),store=memory(),h=harness({storage:store,expires:1});await h.client.login('A','synthetic');
 store.hooks.set=async(_key,value)=>{if(JSON.parse(value).access_token.endsWith('-rotated'))await gate.promise;};
 const old=assert.rejects(h.client.load(),e=>e.code==='SESSION_STORAGE_UNAVAILABLE');await tick();
 const fresh=h.client.login('B','synthetic');await tick();gate.reject(Error('synthetic late A write failure'));
 await Promise.all([old,fresh]);assert.equal(JSON.parse(store.values.get(KEY)).user_id,B);
 store.hooks.set=null;const view=await h.client.load();assert.equal(view.backend.actor.id,B);
});
