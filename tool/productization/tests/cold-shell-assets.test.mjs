import test,{before,after} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,cp,copyFile,readFile,symlink,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {createPilotWorker} from '../../../apps/avaryn/server/worker.js';
import capacitor from '../../../apps/avaryn/capacitor.config.json' with {type:'json'};

const APP=fileURLToPath(new URL('../../../apps/avaryn/',import.meta.url));
const ORIGIN='https://pilot.avaryn.example';
let scratch,html,manifest,nativeHtml,nativeVersion;
before(async()=>{
 scratch=await mkdtemp(join(tmpdir(),'avaryn-cold-shell-'));
 await cp(join(APP,'src'),join(scratch,'src'),{recursive:true});
 await mkdir(join(scratch,'scripts'));await mkdir(join(scratch,'config'));
 await copyFile(join(APP,'scripts/build.mjs'),join(scratch,'scripts/build.mjs'));
 await copyFile(join(APP,'config/release.json'),join(scratch,'config/release.json'));
 await symlink(join(APP,'node_modules'),join(scratch,'node_modules'));
 const build=api=>execFileSync(process.execPath,['scripts/build.mjs'],{cwd:scratch,env:{...process.env,AVARYN_PUBLIC_API_BASE:api},stdio:'pipe'});
 build('/api');html=await readFile(join(scratch,'dist/index.html'),'utf8');manifest=JSON.parse(await readFile(join(scratch,'dist/build-manifest.json'),'utf8'));
 await cp(join(scratch,'dist'),join(scratch,'web-dist'),{recursive:true});
 build(ORIGIN+'/api');nativeHtml=await readFile(join(scratch,'dist/index.html'),'utf8');nativeVersion=JSON.parse(await readFile(join(scratch,'dist/version.json'),'utf8'));
});
after(async()=>{if(scratch)await rm(scratch,{recursive:true,force:true});});
function baseFor(documentUrl,source=html){const bases=[...source.matchAll(/<base\s+href="([^"]+)"\s*>/g)];assert.equal(bases.length,1);return new URL(bases[0][1],documentUrl);}
function resources(source=html){return [...source.matchAll(/<(?:link|script)\b[^>]*\b(?:href|src)="([^"]+)"/g)].map(m=>m[1]);}
function urls(documentUrl,source=html){return resources(source).map(path=>new URL(path,baseFor(documentUrl,source)));}

test('real web and native builders retain one root base before all assets and keep the hashed entry',()=>{
 assert.equal(baseFor(ORIGIN+'/auth/callback').href,ORIGIN+'/');assert.ok(html.indexOf('<base ')<html.indexOf('<link '));
 assert.match(html,/<script type="module" src="app-[A-Z0-9]{8}\.js"><\/script>/);assert.doesNotMatch(html,/src="app\.js"/);
 assert.equal(resources().length,12);assert.ok(resources().every(p=>manifest.files.some(f=>f.path===p)));
 assert.equal(baseFor('capacitor://localhost/auth/callback',nativeHtml).href,'capacitor://localhost/');
 assert.equal(nativeHtml.replace(/app-[A-Z0-9]{8}\.js/g,'app-HASH.js'),html.replace(/app-[A-Z0-9]{8}\.js/g,'app-HASH.js'));
 assert.equal(nativeVersion.apiBase,ORIGIN+'/api');assert.equal(nativeVersion.demo,false);
});
for(const path of ['/','/index.html','/auth/callback?token_hash=synthetic-only&type=email','/auth/reset-password?token_hash=synthetic-only&type=recovery','/uitnodiging?invitation=synthetic-only'])test('cold document and every resolved asset are served at the same root: '+path.split('?')[0],async()=>{
 let upstream=0;const assets=[];
 const worker=createPilotWorker({fetchImpl:()=>{upstream++;throw Error('No upstream expected');}});
 const env={APP_ORIGIN:ORIGIN,SUPABASE_PUBLISHABLE_KEY:'sb_publishable_synthetic_cold_shell_only',ASSETS:{fetch:async request=>{
  assets.push(request);const p=new URL(request.url).pathname;return new Response(await readFile(join(scratch,'web-dist',p==='/'?'index.html':p.slice(1))));
 }}};
 const response=await worker.fetch(new Request(ORIGIN+path,{headers:{'sec-fetch-site':'cross-site','sec-fetch-mode':'navigate','sec-fetch-dest':'document'}}),env);
 assert.equal(response.status,200);assert.equal(await response.text(),html);assert.equal(assets[0].url,ORIGIN+'/');assert.deepEqual([...assets[0].headers],[]);
 for(const url of urls(ORIGIN+path)){
  assert.equal(url.origin,ORIGIN);assert.equal(url.search,'');assert.equal(url.hash,'');assert.ok(!url.pathname.startsWith('/auth/'));
  const asset=await worker.fetch(new Request(url,{headers:{'sec-fetch-site':'same-origin'}}),env);assert.equal(asset.status,200,url.pathname);
  assert.deepEqual(Buffer.from(await asset.arrayBuffer()),await readFile(join(scratch,'web-dist',url.pathname.slice(1))));
 }
 assert.equal(upstream,0);assert.ok(assets.every(r=>new URL(r.url).search===''&&[...r.headers].length===0));
});
for(const [platform,scheme] of [['iOS',capacitor.server.iosScheme],['Android',capacitor.server.androidScheme]])test(platform+' native root and cold nested paths resolve to the installed local bundle',async()=>{
 const host=capacitor.server.hostname||'localhost',root=scheme+'://'+host;
 for(const path of ['/','/index.html','/auth/reset-password?token_hash=synthetic-only&type=recovery'])for(const url of urls(root+path,nativeHtml)){
  assert.equal(url.protocol,scheme+':');assert.equal(url.host,host);assert.equal(url.search,'');assert.ok(!url.pathname.startsWith('/auth/'));
  assert.ok((await readFile(join(scratch,'dist',url.pathname.slice(1)))).length>0);
 }
});
test('CSS font and image URLs continue resolving from root stylesheets without callback tokens',async()=>{
 let checked=0;
 for(const url of urls(ORIGIN+'/auth/reset-password?token_hash=synthetic-only&type=recovery').filter(u=>u.pathname.endsWith('.css'))){
  const css=await readFile(join(scratch,'web-dist',url.pathname.slice(1)),'utf8');
  for(const [,value] of css.matchAll(/url\(\s*['"]?([^'"\)]+)['"]?\s*\)/g)){
   if(value.startsWith('data:'))continue;const asset=new URL(value.trim(),url);assert.equal(asset.origin,ORIGIN);assert.equal(asset.search,'');assert.ok((await readFile(join(scratch,'web-dist',asset.pathname.slice(1)))).length>0);checked++;
  }
 }
 assert.ok(checked>=2,'actual font URLs must be covered');
});
