import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve,dirname,extname,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {Readable} from 'node:stream';
import {horseMediaPath} from '../../../apps/avaryn/src/media-path.js';
import {createBackendClient} from '../../../apps/avaryn/src/backend-client.js';

const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const horse=id(1),asset=id(2),actor=id(3),other=id(4),origin='http://127.0.0.1:56860';
const signed=(operation='download',variant='thumbnail')=>`/storage/v1/object/${operation==='upload'?'upload/sign':'sign'}/horse-media/canonical/${horse}/${asset}/${variant}?token=synthetic.capability.signature`;
const descriptor=(variant='original')=>({signed_upload_url:signed('upload',variant),expected_mime_type:'image/jpeg',max_byte_size:variant==='thumbnail'?1048576:10485760});
const defer=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return{resolve,reject,promise};};
const tick=()=>new Promise(r=>setImmediate(r));
const json=(body,status=200)=>new Response(status===204?null:JSON.stringify(body),{status,headers:{'Content-Type':'application/json'}});
function clientHarness({timeoutMs=1000}={}){
 const calls=[],memory=new Map();let user=actor,override=async()=>undefined;
 const fetchImpl=async(path,options)=>{
  calls.push({path,options});const custom=await override(path,options);if(custom!==undefined)return custom;
  if(path.includes('grant_type=password')){user=JSON.parse(options.body).email==='second'?other:actor;return json({access_token:'synthetic.'+user,refresh_token:'synthetic.refresh',expires_at:Date.now()/1000+3600,user:{id:user}});}
  if(path.endsWith('/auth/v1/logout?scope=local'))return json(null,204);
  if(path.endsWith('get_current_account_profile'))return json([{profile_id:user,profile_status:'active',display_name:'Test',row_version:1}]);
  if(path.endsWith('get_c010_personal_day'))return json({on_date:'2026-09-11',calendar:{today_date:'2026-09-11'},items:[]});
  if(path.includes('/rest/v1/'))return json([]);
  if(path.endsWith('/functions/v1/media-assets'))return json({signed_download_url:signed(),expires_in:60,mime_type:'image/jpeg'});
  if(path.includes('/storage/'))return options.method==='PUT'?json({Key:'synthetic'}):new Response(new Blob(['bytes'],{type:'image/jpeg'}),{headers:{'Content-Type':'image/jpeg'}});
  return json({code:'NOT_FOUND'},404);
 };
 const client=createBackendClient({fetchImpl,timeoutMs,storage:{getItem:k=>memory.get(k),setItem:(k,v)=>memory.set(k,v),removeItem:k=>memory.delete(k)}});
 return{client,calls,override:fn=>override=fn,ready:async()=>{await client.login('first','synthetic');await client.load();}};
}

// Execute the exact server module in a dependency harness. Only imports and
// import.meta.url are substituted; no duplicate implementation and no listening
// socket, private configuration or real upstream is used in these unit cases.
async function bff(){
 const filename=new URL('../../../apps/avaryn/scripts/dev-server.mjs',import.meta.url);
 const original=await readFile(filename,'utf8');
 const code=original.replace(/^import .*;\n/gm,'').replaceAll('import.meta.url',JSON.stringify(filename.href));
 const AsyncFunction=Object.getPrototypeOf(async function(){}).constructor;
 let handler,fetchReply=async()=>json({ok:true});const calls=[];
 const createServer=fn=>{handler=fn;return{listen(port,host){assert.equal(host,'127.0.0.1');assert.equal(port,56860);},close(){}};};
 const fakeRead=async p=>String(p).endsWith('version.json')?JSON.stringify({candidate:'test-only'}):String(p).endsWith('rpc-routes.json')?'["list_c010_horses"]':String(p).endsWith('test-only-config.json')?JSON.stringify({projectId:'avaryn-c010-vitality-20260911-a',upstream:'http://127.0.0.1:56801',anonKey:'synthetic-public-key',allowAuthRegistration:true}):Promise.reject(Error('unexpected file'));
 // Config ownership/fingerprint validation has its own real-file tests. This
 // routing harness injects only its result, without private disk or Docker use.
 const loadDevelopmentConfig=async(path,context)=>{assert.equal(context.origin,origin);assert.equal(context.release.candidate,'test-only');return JSON.parse(await fakeRead(path));};
 await new AsyncFunction('createServer','readFile','stat','resolve','dirname','extname','sep','fileURLToPath','horseMediaPath','loadDevelopmentConfig','process','console','fetch',code)(createServer,fakeRead,()=>{throw Error('unexpected stat');},resolve,dirname,extname,sep,fileURLToPath,horseMediaPath,loadDevelopmentConfig,{env:{AVARYN_DEV_PORT:'56860',AVARYN_DEV_CONFIG:'/private/test-only-config.json'},on(){}},{log(){}},async(url,options)=>{calls.push({url,options});return fetchReply(url,options);});
 async function request(path,{method='POST',headers={},body='{}'}={}){
  const req=Readable.from(body===null?[]:[Buffer.isBuffer(body)?body:Buffer.from(body)]);Object.assign(req,{url:'/api'+path,method,headers:{host:'127.0.0.1:56860',origin,...headers}});
  const res={status:0,headers:{},body:null,setHeader(k,v){this.headers[k.toLowerCase()]=v;},writeHead(status,head){this.status=status;for(const[k,v]of Object.entries(head||{}))this.setHeader(k,v);},end(value){this.body=value===undefined?Buffer.alloc(0):Buffer.from(value);}};
  await handler(req,res);return res;
 }
 return{request,calls,reply:fn=>fetchReply=fn};
}

test('signed capability is rebased to its exact local bucket, never fetched at its supplied host',()=>{const p=signed();assert.equal(horseMediaPath('https://untrusted.invalid'+p,'download'),p);assert.equal(horseMediaPath(signed('upload'),'upload'),signed('upload'));});
for(const [name,value,operation] of [
 ['other bucket',signed().replace('/horse-media/','/avatars/'),'download'],['other variant',signed().replace('/thumbnail?','/other?'),'download'],['credentials','https://user:pass@host.invalid'+signed(),'download'],['fragment',signed()+'#secret','download'],['extra query',signed()+'&foo=1','download'],['duplicate token',signed()+'&token=other','download'],['oversize token',signed().split('?')[0]+'?token='+'x'.repeat(8193),'download'],['encoded slash',signed().replace('/canonical/','/canonical%2f'),'download'],['wrong method',signed(),'upload'],['unknown operation',signed(),'delete'],['dot traversal',signed().replace('/canonical/','/x/../canonical/'),'download'],['encoded traversal',signed().replace('/canonical/','/x/%2e%2e/canonical/'),'download'],['backslash traversal',signed().replace('/canonical/','/x\\..\\canonical/'),'download']
])test('path rejects '+name,()=>assert.equal(horseMediaPath(value,operation),null));

test('Edge request requires a current session and sends the bearer only to same-origin BFF',async()=>{const h=clientHarness();await assert.rejects(h.client.edgeRequest('media-assets',{action:'canonical_create'}),e=>e.status===401);assert.equal(h.calls.length,0);await h.ready();await h.client.mediaRequest({action:'canonical_download'},{write:false});const c=h.calls.at(-1);assert.equal(c.path,'/api/functions/v1/media-assets');assert.equal(c.options.headers.Authorization,'Bearer synthetic.'+actor);});
test('unsupported Edge function/action never reaches fetch',async()=>{const h=clientHarness();await h.ready();const before=h.calls.length;assert.throws(()=>h.client.mediaRequest({action:'delete'}));await assert.rejects(h.client.edgeRequest('other-function',{}));assert.equal(h.calls.length,before);});
test('download and upload use same-origin pinned paths, redirect:error and current bearer',async()=>{const h=clientHarness();await h.ready();await h.client.downloadHorseMedia({media_asset_id:asset});await h.client.uploadHorseMedia(descriptor(),new Blob(['b'],{type:'image/jpeg'}));const calls=h.calls.filter(c=>c.path.includes('/storage/'));assert.equal(calls.length,2);for(const c of calls){assert.ok(c.path.startsWith('/api/storage/'));assert.equal(c.options.redirect,'error');assert.equal(c.options.headers.Authorization,'Bearer synthetic.'+actor);}assert.equal(calls[1].options.method,'PUT');});
test('late Edge body after logout cannot succeed',async()=>{const h=clientHarness(),d=defer();await h.ready();h.override(async p=>p.endsWith('/functions/v1/media-assets')?{ok:true,status:200,json:()=>d.promise}:undefined);const pending=h.client.mediaRequest({action:'canonical_create'},{write:true});await tick();await h.client.logout();d.resolve({media_asset_id:asset});await assert.rejects(pending,e=>e.code==='STALE_CONTEXT');});
test('late image body after a different login cannot be reused by the new actor',async()=>{const h=clientHarness(),d=defer();await h.ready();h.override(async p=>p.includes('/storage/')?{ok:true,status:200,blob:()=>d.promise}:undefined);const pending=h.client.downloadHorseMedia({media_asset_id:asset});await tick();await h.client.login('second','synthetic');await h.client.load();d.resolve(new Blob(['old'],{type:'image/jpeg'}));await assert.rejects(pending,e=>e.code==='STALE_CONTEXT');});
test('upload timeout covers body consumption and has uncertain=true without retry',async()=>{const h=clientHarness({timeoutMs:15});await h.ready();h.override(async p=>p.includes('/storage/')?{ok:true,status:200,json:()=>new Promise(()=>{})}:undefined);await assert.rejects(h.client.uploadHorseMedia(descriptor(),new Blob(['b'],{type:'image/jpeg'})),e=>e.code==='TIMEOUT'&&e.uncertain);assert.equal(h.calls.filter(c=>c.path.includes('/storage/')).length,1);});
test('client rejects non-image upload even when descriptor repeats the invalid MIME',async()=>{const h=clientHarness();await h.ready();assert.throws(()=>h.client.uploadHorseMedia({...descriptor(),expected_mime_type:'image/svg+xml'},new Blob(['svg'],{type:'image/svg+xml'})));});
test('client thumbnail cap cannot be enlarged by a supplied descriptor',async()=>{const h=clientHarness();await h.ready();assert.throws(()=>h.client.uploadHorseMedia({...descriptor('thumbnail'),max_byte_size:10485760},new Blob([new Uint8Array(1048577)],{type:'image/jpeg'})));});
test('client rejects HTML or over-limit download body',async()=>{const h=clientHarness();await h.ready();h.override(async p=>p.includes('/storage/')?new Response(new Blob(['html'],{type:'text/html'}),{headers:{'Content-Type':'text/html'}}):undefined);await assert.rejects(h.client.downloadHorseMedia({media_asset_id:asset}));});

test('BFF refuses absent bearer, wrong host/origin/cross-site and unknown route without upstream traffic',async()=>{const h=await bff();for(const input of [{headers:{}},{headers:{authorization:'Bearer synthetic',origin:'https://evil.invalid'}},{headers:{authorization:'Bearer synthetic',host:'localhost:56860'}},{headers:{authorization:'Bearer synthetic','sec-fetch-site':'cross-site'}}]){const r=await h.request('/functions/v1/media-assets',input);assert.ok([401,403].includes(r.status));}assert.equal((await h.request('/functions/v1/unknown',{headers:{authorization:'Bearer synthetic'}})).status,404);assert.equal(h.calls.length,0);});
test('BFF preserves upstream bearer refusal and forwards current bearer without client-provided apikey',async()=>{const h=await bff();h.reply(async()=>json({code:'INVALID_SESSION'},401));const r=await h.request('/functions/v1/media-assets',{headers:{authorization:'Bearer invalid-session',apikey:'untrusted-key'},body:JSON.stringify({action:'canonical_download'})});assert.equal(r.status,401);assert.equal(h.calls[0].options.headers.Authorization,'Bearer invalid-session');assert.equal(h.calls[0].options.headers.apikey,'synthetic-public-key');assert.equal(h.calls[0].options.redirect,'error');assert.ok(h.calls[0].options.signal);});
test('BFF rejects unsupported media actions and SVG upload before upstream',async()=>{const h=await bff();assert.equal((await h.request('/functions/v1/media-assets',{headers:{authorization:'Bearer synthetic'},body:'{"action":"delete"}'})).status,400);assert.equal((await h.request(signed('upload'),{method:'PUT',headers:{authorization:'Bearer synthetic','content-type':'image/svg+xml'},body:'svg'})).status,415);assert.equal(h.calls.length,0);});
test('BFF enforces original10MiB and thumbnail1MiB request limits',async()=>{const h=await bff();for(const[variant,size]of[['original',10485761],['thumbnail',1048577]]){const r=await h.request(signed('upload',variant),{method:'PUT',headers:{authorization:'Bearer synthetic','content-type':'image/jpeg'},body:Buffer.alloc(size)});assert.equal(r.status,413,variant);}assert.equal(h.calls.length,0);});
test('BFF sends binary bytes only to pinned upstream and preserves image MIME/private cache headers',async()=>{const h=await bff();h.reply(async()=>new Response(Buffer.from([1,2,3]),{headers:{'Content-Type':'image/jpeg'}}));const r=await h.request(signed(),{method:'GET',headers:{authorization:'Bearer synthetic'},body:null});assert.equal(r.status,200);assert.equal(r.headers['content-type'],'image/jpeg');assert.equal(r.headers['cache-control'],'no-store');assert.equal(r.headers['referrer-policy'],'no-referrer');assert.equal(h.calls[0].url,'http://127.0.0.1:56801'+signed());assert.deepEqual([...r.body],[1,2,3]);});
test('BFF redirect rejection is bounded and no redirect bytes are returned',async()=>{const h=await bff();h.reply(async(_u,o)=>{assert.equal(o.redirect,'error');throw new TypeError('redirect rejected');});const r=await h.request(signed(),{method:'GET',headers:{authorization:'Bearer synthetic'},body:null});assert.equal(r.status,503);assert.equal(h.calls.length,1);});
