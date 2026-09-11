import rpcNames from '../config/rpc-routes.json' with {type:'json'};
import release from '../config/release.json' with {type:'json'};
import capacitor from '../capacitor.config.json' with {type:'json'};
import {horseMediaPath} from '../src/media-path.js';

// This is a product BFF, not a configurable general proxy. Supabase Auth and
// the canonical RPC/Edge/RLS contracts remain the authorization authority.
export const PILOT_PROJECT='rvymglpkttlfwhqpmupp';
export const PILOT_UPSTREAM=`https://${PILOT_PROJECT}.supabase.co`;
export const NATIVE_ORIGINS=Object.freeze([
 `${capacitor.server.iosScheme}://${capacitor.server.hostname||'localhost'}`,
 `${capacitor.server.androidScheme}://${capacitor.server.hostname||'localhost'}`,
]);
const RPC=new Set(rpcNames);
const MiB=1024*1024;
const JSON_LIMIT=MiB,MEDIA_LIMIT=10*MiB;
const BEARER=/^Bearer [A-Za-z0-9_.-]{1,8192}$/;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CORS_HEADERS=new Set(['authorization','content-type','x-supabase-api-version']);
const SHELL_PATHS=new Set(['/','/index.html','/auth/callback','/auth/reset-password','/uitnodiging']);
const CSP="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'";
const fail=(code)=>Object.assign(new Error(code),{code});

function validOrigin(value){
 try{const u=new URL(value);return u.origin===value&&u.protocol==='https:'&&!u.username&&!u.password&&!u.search&&!u.hash&&u.pathname==='/'&&u.port===''&&u.hostname.includes('.')&&!/^(localhost|127\.)|\.(local|localhost|internal)$/.test(u.hostname);}catch{return false;}
}
// Avoid accidentally configuring a privileged secret. Legacy anon JWTs must
// explicitly belong to this pilot. These checks do not authenticate users.
export function isPublishableKey(value){
 if(typeof value!=='string'||value.length>4096)return false;
 if(/^sb_publishable_[A-Za-z0-9_-]{16,1024}$/.test(value))return true;
 const parts=value.split('.');if(parts.length!==3||!parts.every(p=>/^[A-Za-z0-9_-]+$/.test(p)))return false;
 try{const p=parts[1].replace(/-/g,'+').replace(/_/g,'/');const claims=JSON.parse(atob(p.padEnd(Math.ceil(p.length/4)*4,'=')));return claims.role==='anon'&&claims.ref===PILOT_PROJECT;}catch{return false;}
}
function headers(origin){
 const h=new Headers({'cache-control':'no-store','pragma':'no-cache','x-content-type-options':'nosniff','referrer-policy':'no-referrer','content-security-policy':CSP,'vary':'Origin'});
 if(origin){h.set('access-control-allow-origin',origin);h.set('access-control-expose-headers','Content-Type, X-Supabase-Api-Version');}
 return h;
}
function json(status,code,origin,extra){return new Response(JSON.stringify({code,...extra}),{status,headers:{...Object.fromEntries(headers(origin)),'content-type':'application/json; charset=utf-8'}});}
function blockedPath(url){
 // URL parsers already normalize literal dot segments. Any residual encoded
 // separators, nested encodings or noncanonical segments are refused; all
 // routes below are independently anchored to an explicit path allowlist.
 return /[\\\x00-\x20]|%|\/\//.test(url.pathname)||url.username||url.password||url.hash||url.pathname.length>2048;
}
function route(url,method){
 const p=url.pathname.slice(4),rpc=p.match(/^\/rest\/v1\/rpc\/([a-z0-9_]+)$/),noQuery=!url.search;
 if(rpc&&RPC.has(rpc[1])&&method==='POST'&&noQuery)return {kind:'rpc',path:p,authorized:true};
 if(p==='/auth/v1/token'&&method==='POST'&&['password','refresh_token'].includes(url.searchParams.get('grant_type'))&&[...url.searchParams.keys()].length===1)return {kind:'auth',path:p,authorized:false};
 if(p==='/auth/v1/user'&&['GET','PUT'].includes(method)&&noQuery)return {kind:'auth',path:p,authorized:true};
 if(p==='/auth/v1/logout'&&method==='POST'&&url.search==='?scope=local')return {kind:'auth',path:p,authorized:true};
 if(['/auth/v1/signup','/auth/v1/recover','/auth/v1/verify','/auth/v1/resend'].includes(p)&&method==='POST'&&noQuery)return {kind:'auth',path:p,authorized:false};
 if(['/functions/v1/media-assets','/functions/v1/delete-account'].includes(p)&&method==='POST'&&noQuery)return {kind:'edge',path:p,authorized:true};
 if(['GET','PUT'].includes(method)&&horseMediaPath(p+url.search,method==='PUT'?'upload':'download'))return {kind:'media',path:p,upload:method==='PUT',authorized:true};
 return null;
}
function staticPath(path){
 if(SHELL_PATHS.has(path))return '/';
 // Only derived public client chunks, styles, images/fonts and their licenses.
 // A server/config/test/credential file in ASSETS is never a public route.
 if(/^\/[A-Za-z][A-Za-z0-9_-]*-[A-Z0-9]{8}\.js$/.test(path)||/^\/[a-z][a-z0-9-]*\.css$/.test(path))return path;
 if(/^\/assets\/(?:[A-Za-z0-9_-]+\/)*[A-Za-z0-9][A-Za-z0-9_.-]*\.(png|jpe?g|webp|svg|ttf|woff2?|txt)$/i.test(path)&&!/(?:^|\/)(private|config|test|tests|server|secrets|node_modules)(?:\/|$)/i.test(path))return path;
 return null;
}
const cancel=body=>{try{const p=body?.cancel();p?.catch?.(()=>{});}catch{}};
function abortable(promise,signal){
 if(signal.aborted){Promise.resolve(promise).catch(()=>{});return Promise.reject(fail('TIMEOUT'));}
 return new Promise((resolve,reject)=>{
  const abort=()=>reject(fail('TIMEOUT'));signal.addEventListener('abort',abort,{once:true});
  Promise.resolve(promise).then(resolve,reject).finally(()=>signal.removeEventListener('abort',abort));
 });
}
export async function limitedBytes(stream,limit,signal){
 if(!stream)return new Uint8Array();
 const reader=stream.getReader(),parts=[];let size=0;
 try{
  while(true){const {value,done}=await abortable(reader.read(),signal);if(done)break;size+=value.byteLength;if(size>limit)throw fail('BODY_LIMIT');parts.push(value);}
 }catch(e){try{void reader.cancel().catch(()=>{});}catch{}throw e;}finally{reader.releaseLock();}
 const bytes=new Uint8Array(size);let offset=0;for(const p of parts){bytes.set(p,offset);offset+=p.byteLength;}return bytes;
}
function parseObject(bytes){
 try{const value=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));if(value&&typeof value==='object'&&!Array.isArray(value))return value;}catch{}
 throw fail('INVALID_REQUEST');
}

/** The injectable fetch/deadline are for deterministic tests; production uses
 * standard Workers Fetch/Streams and the fixed 20-second total proxy budget.
 * Required env: APP_ORIGIN, SUPABASE_PUBLISHABLE_KEY, ASSETS fetch binding.
 */
export function createPilotWorker({fetchImpl=globalThis.fetch,timeoutMs=20000}={}){
 async function proxy(request,env,url,selected,origin){
  const bearer=request.headers.get('authorization');
  if(selected.authorized&&!BEARER.test(bearer||'')||bearer&&!BEARER.test(bearer))return json(401,'AUTH_REQUIRED',origin);
  const type=request.headers.get('content-type')||'';
  if(selected.upload&&!['image/png','image/jpeg','image/webp'].includes(type))return json(415,'PHOTO_INPUT_INVALID',origin);
  if(!selected.upload&&request.method!=='GET'&&!/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(type))return json(415,'JSON_REQUIRED',origin);
  if(request.headers.get('content-encoding')&&!/^identity$/i.test(request.headers.get('content-encoding')))return json(415,'CONTENT_ENCODING_REFUSED',origin);
  const limit=selected.upload&&!selected.path.endsWith('/thumbnail')?MEDIA_LIMIT:JSON_LIMIT;
  const declared=request.headers.get('content-length');
  if(declared!==null&&(!/^\d+$/.test(declared)||!Number.isSafeInteger(Number(declared))))return json(400,'INVALID_CONTENT_LENGTH',origin);
  if(declared!==null&&Number(declared)>limit){cancel(request.body);return json(413,'REQUEST_TOO_LARGE',origin);}
  let stage='request';const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),timeoutMs);
  try{
   const bytes=await limitedBytes(request.body,limit,controller.signal);
   if(request.method==='GET'&&bytes.length)return json(400,'UNEXPECTED_BODY',origin);
   if(request.method!=='GET'&&!selected.upload){
    const body=parseObject(bytes);
    if(selected.kind==='edge'&&selected.path.endsWith('/media-assets')&&!['canonical_create','canonical_finalize','canonical_download'].includes(body.action))return json(400,'UNKNOWN_ACTION',origin);
    if(selected.kind==='edge'&&selected.path.endsWith('/delete-account')&&(body.action!=='delete'||!UUID.test(body.request_id||'')||Object.keys(body).some(k=>!['action','request_id'].includes(k))))return json(400,'DELETION_CONFIRMATION_REQUIRED',origin);
   }
   const outgoing=new Headers({'content-type':selected.upload?type:'application/json','apikey':env.SUPABASE_PUBLISHABLE_KEY,'x-supabase-api-version':'2024-01-01'});
   if(bearer)outgoing.set('authorization',bearer);
   // Never forward browser cookies, caller apikey, forwarding/identity headers,
   // Origin, Referer or a legacy preview secret to the managed pilot.
   stage='upstream';
   const response=await abortable(fetchImpl(PILOT_UPSTREAM+selected.path+url.search,{method:request.method,headers:outgoing,body:request.method==='GET'?undefined:bytes,signal:controller.signal,redirect:'manual',credentials:'omit'}),controller.signal);
   if(response.status>=300&&response.status<400||response.headers.has('location')){cancel(response.body);return json(502,'UPSTREAM_REDIRECT_REFUSED',origin);}
   stage='response';const result=await limitedBytes(response.body,MEDIA_LIMIT,controller.signal);
   const h=headers(origin);h.set('content-type',selected.kind==='media'&&request.method==='GET'&&response.ok?response.headers.get('content-type')||'application/octet-stream':'application/json; charset=utf-8');
   if(selected.kind==='media'&&request.method==='GET'&&response.ok&&!['image/png','image/jpeg','image/webp'].includes(h.get('content-type').split(';')[0].trim()))return json(502,'INVALID_MEDIA_RESPONSE',origin);
   if(response.headers.has('x-supabase-api-version'))h.set('x-supabase-api-version',response.headers.get('x-supabase-api-version'));
   return new Response([204,205,304].includes(response.status)?null:result,{status:response.status,headers:h});
  }catch(error){
   if(error.code==='TIMEOUT'||controller.signal.aborted)return json(stage==='request'?408:504,stage==='request'?'REQUEST_TIMEOUT':'UPSTREAM_TIMEOUT',origin);
   if(error.code==='BODY_LIMIT')return json(stage==='request'?413:502,stage==='request'?'REQUEST_TOO_LARGE':'RESPONSE_TOO_LARGE',origin);
   if(error.code==='INVALID_REQUEST')return json(400,'INVALID_REQUEST',origin);
   // Exceptions may contain credentials, signed URLs or upstream internals.
   return json(503,'BACKEND_UNAVAILABLE',origin);
  }finally{clearTimeout(timer);}
 }
 return {async fetch(request,env){
  let url;try{url=new URL(request.url);}catch{return json(400,'INVALID_PATH');}
  if(!validOrigin(env?.APP_ORIGIN)||!isPublishableKey(env?.SUPABASE_PUBLISHABLE_KEY))return json(503,'PILOT_CONFIGURATION_REQUIRED');
  if(url.origin!==env.APP_ORIGIN||request.headers.has('host')&&request.headers.get('host')!==url.host)return json(403,'HOST_REFUSED');
  if(blockedPath(url))return json(400,'INVALID_PATH');
  const incoming=request.headers.get('origin'),native=NATIVE_ORIGINS.includes(incoming);
  if(incoming&&incoming!==env.APP_ORIGIN&&!native)return json(403,'ORIGIN_REFUSED');
  if(request.headers.get('sec-fetch-site')==='cross-site'&&!native)return json(403,'ORIGIN_REFUSED');
  const cors=incoming&&(native||incoming===env.APP_ORIGIN)?incoming:undefined;
  if(url.pathname.startsWith('/api/')){
   if(request.method==='OPTIONS'){
    const method=request.headers.get('access-control-request-method'),asked=(request.headers.get('access-control-request-headers')||'').split(',').map(s=>s.trim().toLowerCase()).filter(Boolean);
    if(!cors||!route(url,method)||asked.some(h=>!CORS_HEADERS.has(h)))return json(403,'PREFLIGHT_REFUSED');
    const h=headers(cors);h.set('access-control-allow-methods',method);h.set('access-control-allow-headers',[...CORS_HEADERS].join(', '));return new Response(null,{status:204,headers:h});
   }
   const selected=route(url,request.method);if(!selected)return json(404,'NOT_FOUND',cors);
   if(request.method!=='GET'&&!cors)return json(403,'ORIGIN_REQUIRED');
   return proxy(request,env,url,selected,cors);
  }
  if(!['GET','HEAD'].includes(request.method))return json(405,'METHOD_REFUSED',cors);
  if(url.pathname==='/runtime.json'){
   if(url.search)return json(400,'INVALID_QUERY',cors);
   const h=headers(cors);h.set('content-type','application/json; charset=utf-8');
   return new Response(request.method==='HEAD'?null:JSON.stringify({candidate:release.candidate,backendProject:PILOT_PROJECT,localOnly:false}),{headers:h});
  }
  if(url.pathname==='/version.json'){
   const h=headers(cors);h.set('content-type','application/json; charset=utf-8');return new Response(request.method==='HEAD'?null:JSON.stringify({...release,apiBase:'/api',demo:false}),{headers:h});
  }
  const path=staticPath(url.pathname);if(!path)return json(404,'NOT_FOUND',cors);
  if(!env.ASSETS?.fetch)return json(503,'ASSETS_UNAVAILABLE',cors);
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),timeoutMs);
  try{
   // Query tokens and user headers do not reach the static asset service.
   const asset=await abortable(env.ASSETS.fetch(new Request(env.APP_ORIGIN+path,{method:request.method})),controller.signal);
   if(asset.status>=300&&asset.status<400||asset.headers.has('location')){cancel(asset.body);return json(502,'ASSET_REDIRECT_REFUSED',cors);}
   if(!asset.ok){cancel(asset.body);return json(asset.status===404?404:503,asset.status===404?'NOT_FOUND':'ASSETS_UNAVAILABLE',cors);}
   if(request.method==='HEAD')cancel(asset.body);
   const bytes=request.method==='HEAD'?null:await limitedBytes(asset.body,16*MiB,controller.signal);
   const h=headers(cors);h.set('content-type',asset.headers.get('content-type')||'application/octet-stream');
   return new Response(bytes,{status:asset.status,headers:h});
  }catch{return json(503,'ASSETS_UNAVAILABLE',cors);}finally{clearTimeout(timer);}
 }};
}

export default createPilotWorker();
