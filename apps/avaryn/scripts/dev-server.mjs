import {createServer} from 'node:http';
import {readFile,stat} from 'node:fs/promises';
import {resolve,dirname,extname,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {horseMediaPath} from '../src/media-path.js';
import {loadDevelopmentConfig} from './local-backend-config.mjs';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../dist');
const port=Number(process.env.AVARYN_DEV_PORT||56610),origin=`http://127.0.0.1:${port}`;
if(!Number.isSafeInteger(port)||port<1024||port>65535)throw Error('Invalid local port');
const release=JSON.parse(await readFile(resolve(root,'version.json'),'utf8'));
const routes=new Set(JSON.parse(await readFile(new URL('../config/rpc-routes.json',import.meta.url),'utf8')));
let backend=null;
if(process.env.AVARYN_DEV_CONFIG){
 backend=await loadDevelopmentConfig(process.env.AVARYN_DEV_CONFIG,{origin,release});
}
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.webp':'image/webp','.ttf':'font/ttf','.woff':'font/woff','.woff2':'font/woff2','.json':'application/json','.txt':'text/plain; charset=utf-8'};
const send=(res,status,body)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(body));};
async function proxy(req,res,url){
 if(!backend)return send(res,503,{message:'Backend is nog niet ingesteld.'});
 if(req.headers.origin&&req.headers.origin!==origin||req.headers['sec-fetch-site']==='cross-site'||req.method!=='GET'&&req.headers.origin!==origin)return send(res,403,{message:'Onbekende aanvraagherkomst.'});
 const path=url.pathname.slice(4),rpc=path.match(/^\/rest\/v1\/rpc\/([a-z0-9_]+)$/);
 const token=path==='/auth/v1/token'&&req.method==='POST'&&['password','refresh_token'].includes(url.searchParams.get('grant_type'))&&[...url.searchParams.keys()].length===1;
 const auth=token||path==='/auth/v1/user'&&(req.method==='GET'||backend.allowAuthRegistration&&req.method==='PUT')&&!url.search||path==='/auth/v1/logout'&&req.method==='POST'&&url.search==='?scope=local';
 const registration=backend.allowAuthRegistration===true&&['/auth/v1/signup','/auth/v1/recover','/auth/v1/verify','/auth/v1/resend'].includes(path)&&req.method==='POST'&&!url.search;
 const edge=['/functions/v1/media-assets','/functions/v1/delete-account'].includes(path)&&req.method==='POST'&&!url.search;
 const storage=['GET','PUT'].includes(req.method)&&horseMediaPath(path+url.search,req.method==='PUT'?'upload':'download');
 if(!(auth||registration||edge||storage||rpc&&routes.has(rpc[1])&&req.method==='POST'&&!url.search))return send(res,404,{message:'Deze functie is niet beschikbaar.'});
 if((edge||storage)&&!/^Bearer [A-Za-z0-9_.-]+$/.test(req.headers.authorization||''))return send(res,401,{code:'AUTH_REQUIRED'});
 const upload=storage&&req.method==='PUT';
 if(upload&&!['image/jpeg','image/png','image/webp'].includes(req.headers['content-type']))return send(res,415,{code:'PHOTO_INPUT_INVALID'});
 const chunks=[];let size=0;
 for await(const chunk of req){size+=chunk.length;if(size>(upload&&!path.endsWith('/thumbnail')?10*1024*1024:1024*1024))return send(res,413,{message:'De aanvraag is te groot.'});chunks.push(chunk);}
 if(edge&&path.endsWith('/media-assets')){let body;try{body=JSON.parse(Buffer.concat(chunks));}catch{return send(res,400,{code:'INVALID_REQUEST'});}if(!['canonical_create','canonical_finalize','canonical_download'].includes(body.action))return send(res,400,{code:'UNKNOWN_ACTION'});}
 const headers={'Content-Type':upload?req.headers['content-type']:'application/json','apikey':backend.anonKey,'X-Supabase-Api-Version':'2024-01-01'};
 if(backend.gatewaySecret)headers['X-Avaryn-Preview-Secret']=backend.gatewaySecret;
 if(req.headers.authorization)headers.Authorization=req.headers.authorization;
 const response=await fetch(`${backend.upstream}${path}${url.search}`,{method:req.method,headers,body:req.method==='GET'?undefined:Buffer.concat(chunks),signal:AbortSignal.timeout(20000),redirect:'error'});
 const bytes=Buffer.from(await response.arrayBuffer());if(bytes.length>10*1024*1024)return send(res,502,{code:'RESPONSE_TOO_LARGE'});
 res.writeHead(response.status,{'Content-Type':storage&&req.method==='GET'&&response.ok?response.headers.get('content-type')||'application/octet-stream':'application/json'});res.end(bytes);
}
const server=createServer(async(req,res)=>{
 res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Referrer-Policy','no-referrer');
 res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'");
 if(req.headers.host!==`127.0.0.1:${port}`)return send(res,403,{message:'Onbekende host.'});
 try{
  if(/[\\\\]|%2e|%2f|%5c/i.test(req.url)||/(?:^|\/)\.{1,2}(?:\/|\?|$)/.test(req.url))return send(res,400,{code:'INVALID_PATH'});
  const url=new URL(req.url,origin);
  if(url.pathname.startsWith('/api/'))return await proxy(req,res,url);
  if(!['GET','HEAD'].includes(req.method))return send(res,405,{message:'Niet beschikbaar.'});
  if(url.pathname==='/runtime.json')return send(res,200,{candidate:release.candidate,backendProject:backend?.projectId||null,localOnly:true});
  const file=resolve(root,'.'+(['/','/auth/callback','/auth/reset-password','/uitnodiging'].includes(url.pathname)?'/index.html':decodeURIComponent(url.pathname)));
  if(!file.startsWith(root+sep)||!mime[extname(file)])return send(res,404,{message:'Niet gevonden.'});
  const info=await stat(file);if(!info.isFile())return send(res,404,{message:'Niet gevonden.'});
  res.writeHead(200,{'Content-Type':mime[extname(file)],'Content-Length':info.size});res.end(req.method==='HEAD'?undefined:await readFile(file));
 }catch{return send(res,503,{message:'De verbinding is tijdelijk niet beschikbaar.'});}
});
server.listen(port,'127.0.0.1',()=>console.log(`AVARYN ${release.candidate}: ${origin}`));
process.on('SIGINT',()=>server.close(()=>process.exit(0)));
