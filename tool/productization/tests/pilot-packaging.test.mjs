import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,readFile,writeFile,copyFile,readdir,rm,symlink,stat} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {packagePilotSite,assertNoEmbeddedCredentials} from '../../../apps/avaryn/scripts/package-pilot-site.mjs';

const APP=fileURLToPath(new URL('../../../apps/avaryn/',import.meta.url));
const PROJECT='appgprj_6aa45546e34481918b42c6609c243630';
const INPUTS=['capacitor.config.json','config/release.json','config/rpc-routes.json','server/worker.js','src/media-path.js'];
const sha=value=>createHash('sha256').update(value).digest('hex');
async function fixture(t){
 const base=await mkdtemp(join(tmpdir(),'avaryn-pilot-package-'));t.after(()=>rm(base,{recursive:true,force:true}));
 const appRoot=join(base,'app'),output=join(base,'stage');
 for(const path of INPUTS){await mkdir(dirname(join(appRoot,path)),{recursive:true});await copyFile(join(APP,path),join(appRoot,path));}
 const release=JSON.parse(await readFile(join(appRoot,'config/release.json'),'utf8'));
 const files=new Map([
  ['index.html','<!doctype html><script type="module" src="app-ABCDEFGH.js"></script>'],
  ['app-ABCDEFGH.js','document.title="AVARYN";'],
  ['styles.css','body{color:#333}'],
  ['assets/fonts/inter-OFL.txt','Synthetic license fixture; actual release retains its original license.'],
  ['version.json',JSON.stringify({...release,apiBase:'/api',demo:false})],
 ]);
 const manifest={candidate:release.candidate,apiBase:'/api',demo:false,fixtureIsolation:{status:'PASS',mode:'release',providers:['empty-state.js','empty-personas.js','empty-facilities.js'],demoInputs:[]},files:[]};
 async function save(){
  manifest.files=[];
  for(const [path,value]of files){const bytes=Buffer.from(value);await mkdir(dirname(join(appRoot,'dist',path)),{recursive:true});await writeFile(join(appRoot,'dist',path),bytes);manifest.files.push({path,bytes:bytes.length,sha256:sha(bytes)});}
  await saveManifest();
 }
 async function saveManifest(){await writeFile(join(appRoot,'dist/build-manifest.json'),JSON.stringify(manifest));}
 await save();
 return {base,appRoot,output,release,files,manifest,save,saveManifest,run:()=>packagePilotSite({appRoot,output,projectId:PROJECT})};
}
async function absent(path){await assert.rejects(stat(path),{code:'ENOENT'});}

test('stages exact client bytes + bundled production Worker + exact project metadata; native/client source stays untouched',async t=>{
 const f=await fixture(t),before=await readFile(join(f.appRoot,'dist/build-manifest.json'));
 await mkdir(join(f.appRoot,'ios'));await writeFile(join(f.appRoot,'ios/native-sentinel'),'native build stays');
 const receipt=await f.run();
 assert.equal(receipt.status,'PASS');assert.equal(receipt.projectId,PROJECT);assert.equal(receipt.clientFiles,5);assert.equal(receipt.files.length,7);
 assert.deepEqual(JSON.parse(await readFile(join(f.output,'dist/.openai/hosting.json'))),{project_id:PROJECT});
 for(const [path,bytes]of f.files)assert.equal((await readFile(join(f.output,'dist/client',path))).toString(),bytes);
 assert.deepEqual(await readFile(join(f.appRoot,'dist/build-manifest.json')),before);
 assert.equal(await readFile(join(f.appRoot,'ios/native-sentinel'),'utf8'),'native build stays');
 await absent(join(f.output,'dist/client/build-manifest.json'));await absent(join(f.output,'dist/client/server'));
 assert.equal((await stat(join(f.output,'packaging-receipt.json'))).mode&0o777,0o600);
 const bundle=await readFile(join(f.output,'dist/server/index.js'));
 assert.equal(receipt.files.find(file=>file.path==='dist/server/index.js').sha256,sha(bundle));
 const worker=(await import('data:text/javascript;base64,'+bundle.toString('base64'))).default;
 let assetPath;
 const env={APP_ORIGIN:'https://pilot.example.com',SUPABASE_PUBLISHABLE_KEY:'sb_publishable_synthetic_packaging_fixture_only',ASSETS:{fetch:async request=>{assetPath=new URL(request.url).pathname;return new Response(f.files.get(assetPath==='/'?'index.html':assetPath.slice(1)),{headers:{'content-type':'text/html'}});}}};
 const shell=await worker.fetch(new Request(env.APP_ORIGIN+'/auth/callback?token_hash=synthetic'),env);
 assert.equal(shell.status,200);assert.equal(assetPath,'/');assert.equal(await shell.text(),f.files.get('index.html'));
 assert.equal(shell.headers.get('cache-control'),'no-store');
 const runtime=await (await worker.fetch(new Request(env.APP_ORIGIN+'/runtime.json'),env)).json();
 assert.deepEqual(runtime,{candidate:f.release.candidate,backendProject:'rvymglpkttlfwhqpmupp',localOnly:false});
 assert.equal((await worker.fetch(new Request(env.APP_ORIGIN+'/server/index.js'),env)).status,404);
});

test('requires explicit valid project ID and never guesses or reuses a different Site',async t=>{
 const f=await fixture(t);
 for(const projectId of [undefined,'','other',PROJECT+'/../other'])await assert.rejects(packagePilotSite({appRoot:f.appRoot,output:f.output,projectId}),/EXACT_PROJECT_ID_REQUIRED/);
 await absent(f.output);
});
test('refuses existing output, preserving all previous Site metadata and files',async t=>{
 const f=await fixture(t);await mkdir(f.output);await writeFile(join(f.output,'sentinel'),'existing');
 await assert.rejects(f.run(),/OUTPUT_ALREADY_EXISTS/);assert.equal(await readFile(join(f.output,'sentinel'),'utf8'),'existing');
});
test('refuses source/output overlap including symlinked parent',async t=>{
 const f=await fixture(t);await symlink(f.appRoot,join(f.base,'alias'));
 for(const output of [join(f.appRoot,'new-site'),join(f.base,'alias/new-site'),f.base])await assert.rejects(packagePilotSite({appRoot:f.appRoot,output,projectId:PROJECT}),/OUTPUT_OVERLAPS_APP/);
 await absent(join(f.appRoot,'new-site'));
});
test('rejects corrupted listed client bytes before creating output',async t=>{
 const f=await fixture(t);await writeFile(join(f.appRoot,'dist/app-ABCDEFGH.js'),'modified');
 await assert.rejects(f.run(),/CLIENT_HASH_MISMATCH/);await absent(f.output);
});
test('rejects demo builds and remote/native API builds without editing their dist',async t=>{
 for(const alteration of [{demo:true},{apiBase:'https://pilot.example.com/api'}]){
  const f=await fixture(t);Object.assign(f.manifest,alteration);await f.saveManifest();
  await assert.rejects(f.run(),/WEB_RELEASE_REQUIRED/);await absent(f.output);
 }
});
test('rejects missing fixture-isolation evidence and mismatched version/candidate',async t=>{
 for(const kind of ['isolation','candidate','version']){
  const f=await fixture(t);
  if(kind==='isolation')f.manifest.fixtureIsolation.demoInputs=['demo-personas.js'];
  if(kind==='candidate')f.manifest.candidate='C010-WRONG';
  if(kind==='version')f.files.set('version.json',JSON.stringify({...f.release,apiBase:'/api',demo:true}));
  await f.save();await assert.rejects(f.run(),new RegExp(kind==='isolation'?'FIXTURE_ISOLATION_REQUIRED':kind==='candidate'?'CANDIDATE_MISMATCH':'CLIENT_VERSION_MISMATCH'));await absent(f.output);
 }
});
test('rejects unlisted private file instead of quietly adding or ignoring it',async t=>{
 const f=await fixture(t);await writeFile(join(f.appRoot,'dist/.env'),'SYNTHETIC_ONLY');
 await assert.rejects(f.run(),/UNLISTED_CLIENT_FILE/);await absent(f.output);
});
test('rejects unsafe manifest paths and forbidden public subdirectories',async t=>{
 for(const path of ['../private.txt','/absolute.txt','assets/../private.txt','assets/private/key.txt','assets/test/fixture.txt','app.js','app.js.map']){
  const f=await fixture(t);f.manifest.files.push({path,bytes:0,sha256:sha('')});await f.saveManifest();
  await assert.rejects(f.run(),/UNSAFE_PUBLIC_PATH/);await absent(f.output);
 }
});
test('rejects symlinked client files even when destination bytes match manifest',async t=>{
 const f=await fixture(t),path=join(f.appRoot,'dist/styles.css');await rm(path);await writeFile(join(f.base,'outside.css'),f.files.get('styles.css'));await symlink(join(f.base,'outside.css'),path);
 await assert.rejects(f.run(),/NON_REGULAR_FILE/);await absent(f.output);
});
test('rejects extra Worker imports before creating a deliverable',async t=>{
 const f=await fixture(t);await writeFile(join(f.appRoot,'server/extra.js'),'export const marker=42;');
 const path=join(f.appRoot,'server/worker.js');await writeFile(path,`import {marker} from './extra.js';\nconsole.log(marker);\n`+await readFile(path,'utf8'));
 await assert.rejects(f.run(),/UNEXPECTED_WORKER_INPUT/);await absent(f.output);
});
test('credential patterns reject real-shaped synthetic keys/tokens but allow environment variable names and guard regexes',async t=>{
 for(const value of ['sb_secret_'+'a'.repeat(24),'sb_publishable_'+'b'.repeat(24),'-----BEGIN PRIVATE KEY-----',`eyJhbGciOiJIUzI1NiJ9.${Buffer.from(JSON.stringify({role:'service_role'})).toString('base64url')}.signature`])assert.throws(()=>assertNoEmbeddedCredentials(Buffer.from(value)),/EMBEDDED_/);
 assert.doesNotThrow(()=>assertNoEmbeddedCredentials(Buffer.from('SUPABASE_PUBLISHABLE_KEY; /^sb_publishable_[A-Za-z0-9_-]{16,1024}$/;')));
 const f=await fixture(t);f.files.set('app-ABCDEFGH.js','const key="sb_secret_'+'a'.repeat(24)+'";');await f.save();
 await assert.rejects(f.run(),/EMBEDDED_CREDENTIAL/);await absent(f.output);
});
test('CLI rejects missing/duplicate/unknown arguments without creating output',()=>{
 const path=join(APP,'scripts/package-pilot-site.mjs');
 for(const args of [[],['--project-id',PROJECT,'--project-id',PROJECT],['--project-id',PROJECT,'--replace','yes']]){
  const result=spawnSync(process.execPath,[path,...args],{encoding:'utf8'});assert.equal(result.status,1);assert.match(result.stderr,/USAGE:/);
 }
});
test('current official release stages in a temporary directory; every saved client asset is served by the exact bundled Worker',async t=>{
 const base=await mkdtemp(join(tmpdir(),'avaryn-official-release-stage-'));t.after(()=>rm(base,{recursive:true,force:true}));
 const output=join(base,'stage'),receipt=await packagePilotSite({projectId:PROJECT,output});
 const bytes=await readFile(join(output,'dist/server/index.js')),worker=(await import('data:text/javascript;base64,'+bytes.toString('base64'))).default;
 const env={APP_ORIGIN:'https://pilot.example.com',SUPABASE_PUBLISHABLE_KEY:'sb_publishable_synthetic_packaging_fixture_only',ASSETS:{fetch:async request=>{const p=new URL(request.url).pathname;return new Response(await readFile(join(output,'dist/client',p==='/'?'index.html':p.slice(1))));}}};
 for(const file of receipt.files.filter(file=>file.path.startsWith('dist/client/'))){
  const path=file.path.slice('dist/client/'.length),response=await worker.fetch(new Request(env.APP_ORIGIN+'/'+path),env);
  assert.equal(response.status,200,path);
  if(path==='version.json')assert.equal((await response.json()).candidate,receipt.candidate);
  else assert.equal(sha(Buffer.from(await response.arrayBuffer())),file.sha256,path);
 }
 assert.ok(receipt.files.some(file=>file.path.endsWith('inter-OFL.txt')));assert.ok(receipt.files.some(file=>file.path.endsWith('instrumentsans-OFL.txt')));
 assert.deepEqual((await readdir(join(output,'dist'))).sort(),['.openai','client','server']);
});
